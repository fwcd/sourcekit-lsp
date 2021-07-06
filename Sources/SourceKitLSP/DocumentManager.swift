//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Dispatch
import LanguageServerProtocol
import LSPLogging
import SKSupport

public struct DocumentSnapshot {
  public var document: Document
  public var version: Int
  public var lineTable: LineTable
  public var syntacticTokens: [SemanticToken]
  public var semanticTokens: [SemanticToken]

  public var text: String { lineTable.content }

  public var allTokens: [SemanticToken] { mergeSemanticTokens(syntacticTokens, semanticTokens) }
  public var sortedTokens: [SemanticToken] { allTokens.sorted { $0.start < $1.start } }

  public init(
    document: Document,
    version: Int,
    lineTable: LineTable,
    syntacticTokens: [SemanticToken],
    semanticTokens: [SemanticToken]
  ) {
    self.document = document
    self.version = version
    self.lineTable = lineTable
    self.syntacticTokens = syntacticTokens
    self.semanticTokens = semanticTokens
  }

  func index(of pos: Position) -> String.Index? {
    return lineTable.stringIndexOf(line: pos.line, utf16Column: pos.utf16index)
  }
}

public final class Document {
  public let uri: DocumentURI
  public let language: Language
  var latestVersion: Int
  var latestLineTable: LineTable
  var latestSyntacticTokens: [SemanticToken]
  var latestSemanticTokens: [SemanticToken]

  init(uri: DocumentURI, language: Language, version: Int, text: String) {
    self.uri = uri
    self.language = language
    self.latestVersion = version
    self.latestLineTable = LineTable(text)
    self.latestSyntacticTokens = []
    self.latestSemanticTokens = []
  }

  /// **Not thread safe!** Use `DocumentManager.latestSnapshot` instead.
  fileprivate var latestSnapshot: DocumentSnapshot {
    DocumentSnapshot(
      document: self,
      version: latestVersion,
      lineTable: latestLineTable,
      syntacticTokens: latestSyntacticTokens,
      semanticTokens: latestSemanticTokens
    )
  }
}

public final class DocumentManager {

  public enum Error: Swift.Error {
    case alreadyOpen(DocumentURI)
    case missingDocument(DocumentURI)
  }

  let queue: DispatchQueue = DispatchQueue(label: "document-manager-queue")

  var documents: [DocumentURI: Document] = [:]

  /// All currently opened documents.
  public var openDocuments: Set<DocumentURI> {
    return queue.sync {
      return Set(documents.keys)
    }
  }

  /// Opens a new document with the given content and metadata.
  ///
  /// - returns: The initial contents of the file.
  /// - throws: Error.alreadyOpen if the document is already open.
  @discardableResult
  public func open(_ uri: DocumentURI, language: Language, version: Int, text: String) throws -> DocumentSnapshot {
    return try queue.sync {
      let document = Document(uri: uri, language: language, version: version, text: text)
      if nil != documents.updateValue(document, forKey: uri) {
        throw Error.alreadyOpen(uri)
      }
      return document.latestSnapshot
    }
  }

  /// Closes the given document.
  ///
  /// - returns: The initial contents of the file.
  /// - throws: Error.missingDocument if the document is not open.
  public func close(_ uri: DocumentURI) throws {
    try queue.sync {
      if nil == documents.removeValue(forKey: uri) {
        throw Error.missingDocument(uri)
      }
    }
  }

  /// Applies the given edits to the document.
  ///
  /// - parameter editCallback: Optional closure to call for each edit.
  /// - parameter before: The document contents *before* the edit is applied.
  /// - returns: The contents of the file after all the edits are applied.
  /// - throws: Error.missingDocument if the document is not open.
  @discardableResult
  public func edit(_ uri: DocumentURI, newVersion: Int, edits: [TextDocumentContentChangeEvent], editCallback: ((_ before: DocumentSnapshot, TextDocumentContentChangeEvent) -> Void)? = nil) throws -> DocumentSnapshot {
    return try queue.sync {
      guard let document = documents[uri] else {
        throw Error.missingDocument(uri)
      }

      for edit in edits {
        if let f = editCallback {
          f(document.latestSnapshot, edit)
        }

        if let range = edit.range  {
          document.latestLineTable.replace(
            fromLine: range.lowerBound.line,
            utf16Offset: range.lowerBound.utf16index,
            toLine: range.upperBound.line,
            utf16Offset: range.upperBound.utf16index,
            with: edit.text)
          
          // Remove all tokens in the updated range and shift later ones.

          let previousLineCount = 1 + range.upperBound.line - range.lowerBound.line
          let newLines = edit.text.split(separator: "\n", omittingEmptySubsequences: false)
          let lastLineReplaceLength = (
            range.lowerBound.line == range.upperBound.line ? range.upperBound.utf16index : 0
          ) - range.lowerBound.utf16index
          let lastLineLengthDelta = newLines.last!.count - lastLineReplaceLength
          let lineDelta = newLines.count - previousLineCount

          func isTokenBounding(character: Character) -> Bool {
            character.isWhitespace || character.isPunctuation || character.isSymbol
          }

          func update(tokens: inout [SemanticToken]) {
            tokens = Array(tokens.lazy
              .filter {
                // Only keep tokens that don't overlap with or are directly
                // adjacent to the edit range and also are adjacent to a
                // token-bounding character.
                $0.start > range.upperBound || range.lowerBound > $0.end
                || ($0.start == range.upperBound && (edit.text.first.map(isTokenBounding(character:)) ?? true))
                || ($0.end == range.lowerBound && (edit.text.last.map(isTokenBounding(character:)) ?? true))
              }
              .map {
                // Shift tokens after the edit range
                var token = $0
                if token.start.line == range.upperBound.line
                  && token.start.utf16index >= range.upperBound.utf16index {
                  token.start.utf16index += lastLineLengthDelta
                  token.start.line += lineDelta
                } else if token.start.line > range.upperBound.line {
                  token.start.line += lineDelta
                }
                return token
              })
          }

          update(tokens: &document.latestSyntacticTokens)
          update(tokens: &document.latestSemanticTokens)
        } else {
          // Full text replacement.
          document.latestLineTable = LineTable(edit.text)
          document.latestSyntacticTokens = []
        }

      }

      document.latestVersion = newVersion
      return document.latestSnapshot
    }
  }

  /// Replaces the semantic tokens for a document.
  ///
  /// - parameter uri: The URI of the document to be updated
  /// - parameter tokens: The tokens to be used
  @discardableResult
  public func replaceSemanticTokens(
    _ uri: DocumentURI,
    tokens: [SemanticToken]
  ) throws -> DocumentSnapshot {
    return try queue.sync {
      guard let document = documents[uri] else {
        throw Error.missingDocument(uri)
      }

      document.latestSemanticTokens = tokens
      return document.latestSnapshot
    }
  }

  /// Adds the given the syntactic tokens to a document.
  ///
  /// - parameter uri: The URI of the document to be updated
  /// - parameter tokens: The tokens to be added
  @discardableResult
  public func addSyntacticTokens(
    _ uri: DocumentURI,
    tokens: [SemanticToken]
  ) throws -> DocumentSnapshot {
    return try queue.sync {
      guard let document = documents[uri] else {
        throw Error.missingDocument(uri)
      }

      if !tokens.isEmpty {
        // Remove all tokens that overlap with previous tokens

        func removeAllOverlapping(tokens existingTokens: inout [SemanticToken]) {
          existingTokens.removeAll { existing in
            tokens.contains { existing.range.overlaps($0.range) }
          }
        }

        removeAllOverlapping(tokens: &document.latestSyntacticTokens)
        removeAllOverlapping(tokens: &document.latestSemanticTokens)

        document.latestSyntacticTokens += tokens
      }

      return document.latestSnapshot
    }
  }

  public func latestSnapshot(_ uri: DocumentURI) -> DocumentSnapshot? {
    return queue.sync {
      guard let document = documents[uri] else {
        return nil
      }
      return document.latestSnapshot
    }
  }
}

extension DocumentManager {

  // MARK: - LSP notification handling

  /// Convenience wrapper for `open(_:language:version:text:)` that logs on failure.
  @discardableResult
  func open(_ note: DidOpenTextDocumentNotification) -> DocumentSnapshot? {
    let doc = note.textDocument
    return orLog("failed to open document", level: .error) {
      try open(doc.uri, language: doc.language, version: doc.version, text: doc.text)
    }
  }

  /// Convenience wrapper for `close(_:)` that logs on failure.
  func close(_ note: DidCloseTextDocumentNotification) {
    orLog("failed to close document", level: .error) {
      try close(note.textDocument.uri)
    }
  }

  /// Convenience wrapper for `edit(_:newVersion:edits:editCallback:)` that logs on failure.
  @discardableResult
  func edit(_ note: DidChangeTextDocumentNotification, editCallback: ((_ before: DocumentSnapshot, TextDocumentContentChangeEvent) -> Void)? = nil) -> DocumentSnapshot? {
    return orLog("failed to edit document", level: .error) {
      try edit(note.textDocument.uri, newVersion: note.textDocument.version ?? -1, edits: note.contentChanges, editCallback: editCallback)
    }
  }
}
