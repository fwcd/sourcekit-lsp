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
      capabilities: ClientCapabilities(
        workspace: .init(
          semanticTokens: .init(
            refreshSupport: true
          )
        ),
        textDocument: nil
      ),
      trace: .off,
      workspaceFolders: nil
    ))
  }

  private func performSemanticTokensRequest(text: String, range: Range<Position>? = nil) -> [SyntaxHighlightingToken] {
    let url = URL(fileURLWithPath: "/\(#function)/a.swift")

    // We wait for the first refresh request to make sure that the semantic tokens are ready

    let refreshExpectation = expectation(description: "performSemanticTokensRequest - refresh received")
    sk.handleNextRequest { (req: Request<WorkspaceSemanticTokensRefreshRequest>) in
      refreshExpectation.fulfill()
      req.reply(VoidResponse())
    }

    sk.send(DidOpenTextDocumentNotification(textDocument: TextDocumentItem(
      uri: DocumentURI(url),
      language: .swift,
      version: 17,
      text: text
    )))

    wait(for: [refreshExpectation], timeout: 15)

    let textDocument = TextDocumentIdentifier(url)
    let response: DocumentSemanticTokensResponse!

    if let range = range {
      response = try! sk.sendSync(DocumentSemanticTokensRangeRequest(textDocument: textDocument, range: range))
    } else {
      response = try! sk.sendSync(DocumentSemanticTokensRequest(textDocument: textDocument))
    }

    return [SyntaxHighlightingToken](lspEncodedTokens: response.data)
  }

  func testIntArrayCoding() {
    let tokens = [
      SyntaxHighlightingToken(
        start: Position(line: 2, utf16index: 3),
        length: 5,
        kind: .string
      ),
      SyntaxHighlightingToken(
        start: Position(line: 4, utf16index: 2),
        length: 1,
        kind: .interface,
        modifiers: [.deprecated, .definition]
      ),
    ]

    let encoded = tokens.lspEncoded
    XCTAssertEqual(encoded, [
      2, // line delta
      3, // char delta
      5, // length
      SyntaxHighlightingToken.Kind.string.rawValue, // kind
      0, // modifiers

      2, // line delta
      2, // char delta
      1, // length
      SyntaxHighlightingToken.Kind.interface.rawValue, // kind
      SyntaxHighlightingToken.Modifiers.deprecated.rawValue | SyntaxHighlightingToken.Modifiers.definition.rawValue, // modifiers
    ])

    let decoded = [SyntaxHighlightingToken](lspEncodedTokens: encoded)
    XCTAssertEqual(decoded, tokens)
  }

  func testEmpty() {
    let text = ""
    let tokens = performSemanticTokensRequest(text: text)
    XCTAssertEqual(tokens, [])
  }

  func testRanged() {
    let text = """
    let x = 1
    let test = 20
    let abc = 333
    let y = 4
    """
    let start = Position(line: 1, utf16index: 0)
    let end = Position(line: 2, utf16index: 5)
    let tokens = performSemanticTokensRequest(text: text, range: start..<end)
    XCTAssertEqual(tokens, [
      SyntaxHighlightingToken(start: Position(line: 1, utf16index: 0), length: 3, kind: .keyword),
      SyntaxHighlightingToken(start: Position(line: 1, utf16index: 4), length: 4, kind: .variable, modifiers: .declaration),
      SyntaxHighlightingToken(start: Position(line: 1, utf16index: 11), length: 2, kind: .number),
      SyntaxHighlightingToken(start: Position(line: 2, utf16index: 0), length: 3, kind: .keyword),
      SyntaxHighlightingToken(start: Position(line: 2, utf16index: 4), length: 3, kind: .variable, modifiers: .declaration),
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
      // let x = 3
      SyntaxHighlightingToken(start: Position(line: 0, utf16index: 0), length: 3, kind: .keyword),
      SyntaxHighlightingToken(start: Position(line: 0, utf16index: 4), length: 1, kind: .variable, modifiers: .declaration),
      SyntaxHighlightingToken(start: Position(line: 0, utf16index: 8), length: 1, kind: .number),
      // var y = "test"
      SyntaxHighlightingToken(start: Position(line: 1, utf16index: 0), length: 3, kind: .keyword),
      SyntaxHighlightingToken(start: Position(line: 1, utf16index: 4), length: 1, kind: .variable, modifiers: .declaration),
      SyntaxHighlightingToken(start: Position(line: 1, utf16index: 8), length: 6, kind: .string),
      // /* abc */ // 123
      SyntaxHighlightingToken(start: Position(line: 2, utf16index: 0), length: 9, kind: .comment),
      SyntaxHighlightingToken(start: Position(line: 2, utf16index: 10), length: 6, kind: .comment),
    ])
  }

  func testSyntacticTokensForMultiLineComments() {
    let text = """
    let x = 3 /*
    let x = 12
    */
    """
    let tokens = performSemanticTokensRequest(text: text)
    XCTAssertEqual(tokens, [
      SyntaxHighlightingToken(start: Position(line: 0, utf16index: 0), length: 3, kind: .keyword),
      SyntaxHighlightingToken(start: Position(line: 0, utf16index: 4), length: 1, kind: .variable, modifiers: .declaration),
      SyntaxHighlightingToken(start: Position(line: 0, utf16index: 8), length: 1, kind: .number),
      // Multi-line comments are split into single-line tokens
      SyntaxHighlightingToken(start: Position(line: 0, utf16index: 10), length: 2, kind: .comment),
      SyntaxHighlightingToken(start: Position(line: 1, utf16index: 0), length: 10, kind: .comment),
      SyntaxHighlightingToken(start: Position(line: 2, utf16index: 0), length: 2, kind: .comment),
    ])
  }

  func testSyntacticTokensForDocComments() {
    let text = """
    /** abc */
      /// def
    """
    let tokens = performSemanticTokensRequest(text: text)
    XCTAssertEqual(tokens, [
      SyntaxHighlightingToken(start: Position(line: 0, utf16index: 0), length: 10, kind: .comment),
      SyntaxHighlightingToken(start: Position(line: 1, utf16index: 2), length: 7, kind: .comment),
    ])
  }

  func testSemanticTokens() {
    let text = """
    struct X {}

    let x = X()
    let y = x + x

    func a() {}
    let b = {}

    a()
    b()
    """
    let tokens = performSemanticTokensRequest(text: text)
    XCTAssertEqual(tokens, [
      // struct X {}
      SyntaxHighlightingToken(start: Position(line: 0, utf16index: 0), length: 6, kind: .keyword),
      SyntaxHighlightingToken(start: Position(line: 0, utf16index: 7), length: 1, kind: .struct, modifiers: .declaration),
      // let x = X()
      SyntaxHighlightingToken(start: Position(line: 2, utf16index: 0), length: 3, kind: .keyword),
      SyntaxHighlightingToken(start: Position(line: 2, utf16index: 4), length: 1, kind: .variable, modifiers: .declaration),
      SyntaxHighlightingToken(start: Position(line: 2, utf16index: 8), length: 1, kind: .struct),
      // let y = x + x
      SyntaxHighlightingToken(start: Position(line: 3, utf16index: 0), length: 3, kind: .keyword),
      SyntaxHighlightingToken(start: Position(line: 3, utf16index: 4), length: 1, kind: .variable, modifiers: .declaration),
      SyntaxHighlightingToken(start: Position(line: 3, utf16index: 8), length: 1, kind: .variable),
      SyntaxHighlightingToken(start: Position(line: 3, utf16index: 12), length: 1, kind: .variable),
      // func a() {}
      SyntaxHighlightingToken(start: Position(line: 5, utf16index: 0), length: 4, kind: .keyword),
      SyntaxHighlightingToken(start: Position(line: 5, utf16index: 5), length: 1, kind: .function, modifiers: .declaration),
      // let b = {}
      SyntaxHighlightingToken(start: Position(line: 6, utf16index: 0), length: 3, kind: .keyword),
      SyntaxHighlightingToken(start: Position(line: 6, utf16index: 4), length: 1, kind: .variable, modifiers: .declaration),
      // a()
      SyntaxHighlightingToken(start: Position(line: 8, utf16index: 0), length: 1, kind: .function),
      // b()
      SyntaxHighlightingToken(start: Position(line: 9, utf16index: 0), length: 1, kind: .variable),
    ])
  }

  func testSemanticTokensForProtocols() {
    let text = """
    protocol X {}
    class Y: X {}

    let y: Y = X()

    func f<T: X>() {}
    """
    let tokens = performSemanticTokensRequest(text: text)
    XCTAssertEqual(tokens, [
      // protocol X {}
      SyntaxHighlightingToken(start: Position(line: 0, utf16index: 0), length: 8, kind: .keyword),
      SyntaxHighlightingToken(start: Position(line: 0, utf16index: 9), length: 1, kind: .interface, modifiers: .declaration),
      // class Y: X {}
      SyntaxHighlightingToken(start: Position(line: 1, utf16index: 0), length: 5, kind: .keyword),
      SyntaxHighlightingToken(start: Position(line: 1, utf16index: 6), length: 1, kind: .class, modifiers: .declaration),
      SyntaxHighlightingToken(start: Position(line: 1, utf16index: 9), length: 1, kind: .interface),
      // let y: Y = X()
      SyntaxHighlightingToken(start: Position(line: 3, utf16index: 0), length: 3, kind: .keyword),
      SyntaxHighlightingToken(start: Position(line: 3, utf16index: 4), length: 1, kind: .variable, modifiers: .declaration),
      SyntaxHighlightingToken(start: Position(line: 3, utf16index: 7), length: 1, kind: .class),
      SyntaxHighlightingToken(start: Position(line: 3, utf16index: 11), length: 1, kind: .interface),
      // func f<T: X>() {}
      SyntaxHighlightingToken(start: Position(line: 5, utf16index: 0), length: 4, kind: .keyword),
      SyntaxHighlightingToken(start: Position(line: 5, utf16index: 5), length: 1, kind: .function, modifiers: .declaration),
      SyntaxHighlightingToken(start: Position(line: 5, utf16index: 7), length: 1, kind: .typeParameter, modifiers: .declaration),
      SyntaxHighlightingToken(start: Position(line: 5, utf16index: 10), length: 1, kind: .interface),
    ])
  }

  func testSemanticTokensForFunctionSignatures() {
    let text = "func f(x: Int, _ y: String) {}"
    let tokens = performSemanticTokensRequest(text: text)
    XCTAssertEqual(tokens, [
      SyntaxHighlightingToken(start: Position(line: 0, utf16index: 0), length: 4, kind: .keyword),
      SyntaxHighlightingToken(start: Position(line: 0, utf16index: 5), length: 1, kind: .function, modifiers: .declaration),
      // Parameter labels use .function as a kind, see parseKindAndModifiers for rationale
      SyntaxHighlightingToken(start: Position(line: 0, utf16index: 7), length: 1, kind: .function, modifiers: .declaration),
      SyntaxHighlightingToken(start: Position(line: 0, utf16index: 10), length: 3, kind: .struct),
      SyntaxHighlightingToken(start: Position(line: 0, utf16index: 15), length: 1, kind: .keyword),
      SyntaxHighlightingToken(start: Position(line: 0, utf16index: 20), length: 6, kind: .struct),
    ])
  }
}
