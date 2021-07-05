//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import LanguageServerProtocol
import LSPTestSupport
import SKTestSupport
import SourceKitLSP
import XCTest

final class SemanticTokensTests: XCTestCase {
  /// Connection and lifetime management for the service.
  var connection: TestSourceKitServer! = nil

  /// The primary interface to make requests to the SourceKitServer.
  var sk: TestClient! = nil

  override func tearDown() {
    sk = nil
    connection = nil
  }

  override func setUp() {
    connection = TestSourceKitServer()
    sk = connection.client
    _ = try! sk.sendSync(InitializeRequest(
      processId: nil,
      rootPath: nil,
      rootURI: nil,
      initializationOptions: nil,
      capabilities: ClientCapabilities(workspace: nil, textDocument: nil),
      trace: .off,
      workspaceFolders: nil
    ))
  }

  /// Decodes the LSP representation of semantic tokens
  private func decodeFromIntArray(tokens encodedTokens: [UInt32]) -> [SemanticToken] {
    var current = Position(line: 0, utf16index: 0)
    var tokens: [SemanticToken] = []

    for i in stride(from: 0, to: encodedTokens.count, by: 5) {
      let lineDelta = Int(encodedTokens[i])
      let charDelta = Int(encodedTokens[i + 1])
      let length = Int(encodedTokens[i + 2])
      let rawKind = Int(encodedTokens[i + 3])
      let rawModifiers = Int(encodedTokens[i + 4])

      current.line += lineDelta

      if lineDelta == 0 {
        current.utf16index += charDelta
      } else {
        current.utf16index = charDelta
      }

      if let kind = SemanticToken.Kind(rawValue: rawKind) {
        tokens.append(SemanticToken(
          start: current,
          length: length,
          kind: kind
        ))
      }
    }

    return tokens
  }

  private func performSemanticTokensRequest(text: String, range: Range<Position>? = nil) -> [SemanticToken] {
    let url = URL(fileURLWithPath: "/\(#function)/a.swift")

    // We wait for the first refresh request to make sure that the syntactic tokens are ready
    // TODO: Await semantic tokens too

    let semaphore = DispatchSemaphore(value: 0)
    sk.appendOneShotRequestHandler { (req: Request<WorkspaceSemanticTokensRefreshRequest>) in
      req.reply(VoidResponse())
      semaphore.signal()
    }
    
    sk.send(DidOpenTextDocumentNotification(textDocument: TextDocumentItem(
      uri: DocumentURI(url),
      language: .swift,
      version: 17,
      text: text
    )))

    semaphore.wait()

    let textDocument = TextDocumentIdentifier(url)
    let response: DocumentSemanticTokensResponse!

    if let range = range {
      response = try! sk.sendSync(DocumentSemanticTokensRangeRequest(textDocument: textDocument, range: range))
    } else {
      response = try! sk.sendSync(DocumentSemanticTokensRequest(textDocument: textDocument))
    }

    return decodeFromIntArray(tokens: response.data)
  }

  func testEmpty() {
    let text = ""
    let tokens = performSemanticTokensRequest(text: text)
    XCTAssertEqual(tokens, [])
  }

  func testRanged() {
    let text = """
    let x = 1
    let y = 2
    let z = 3
    let w = 4
    """
    let start = Position(line: 1, utf16index: 0)
    let end = Position(line: 2, utf16index: 5)
    let tokens = performSemanticTokensRequest(text: text, range: start..<end)
    XCTAssertEqual(tokens, [
      SemanticToken(
        start: Position(line: 1, utf16index: 0),
        length: 3,
        kind: .keyword
      ),
      SemanticToken(
        start: Position(line: 2, utf16index: 0),
        length: 3,
        kind: .keyword
      ),
    ])
  }

  func testSyntacticTokens() {
    let text = """
    let x = 3
    var y = "test"
    /* abc */ // 123
    """
    let tokens = performSemanticTokensRequest(text: text)
    XCTAssertEqual(tokens, [
      SemanticToken(
        start: Position(line: 0, utf16index: 0),
        length: 3,
        kind: .keyword
      ),
      SemanticToken(
        start: Position(line: 1, utf16index: 0),
        length: 3,
        kind: .keyword
      ),
      SemanticToken(
        start: Position(line: 2, utf16index: 0),
        length: 9,
        kind: .comment
      ),
      SemanticToken(
        start: Position(line: 2, utf16index: 10),
        length: 6,
        kind: .comment
      ),
    ])
  }

  func testSemanticTokens() {
    // FIXME: Implement test for semantic tokens (may require awaiting
    // the corresponding refresh request emitted by updateSemanticTokens
    // called by handleDocumentUpdate)

    // let text = """
    // struct X {}

    // let x = X()
    // let y = x + x
    // """
    // let tokens = performSemanticTokensRequest(text: text)
    // XCTAssertEqual(tokens, [
    // ])
  }
}
