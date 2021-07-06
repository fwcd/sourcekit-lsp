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

  private func performSemanticTokensRequest(text: String, range: Range<Position>? = nil) -> [SemanticToken] {
    let url = URL(fileURLWithPath: "/\(#function)/a.swift")

    // We wait for the first refresh request to make sure that the semantic tokens are ready

    let expectation = XCTestExpectation(description: "performSemanticTokensRequest - refresh received")
    sk.handleNextRequest { (req: Request<WorkspaceSemanticTokensRefreshRequest>) in
      expectation.fulfill()
      req.reply(VoidResponse())
    }

    sk.send(DidOpenTextDocumentNotification(textDocument: TextDocumentItem(
      uri: DocumentURI(url),
      language: .swift,
      version: 17,
      text: text
    )))

    let waitResult = XCTWaiter.wait(for: [expectation], timeout: 15)
    if waitResult != .completed {
      fatalError("error \(waitResult) while waiting for semantic token refresh")
    }

    let textDocument = TextDocumentIdentifier(url)
    let response: DocumentSemanticTokensResponse!

    if let range = range {
      response = try! sk.sendSync(DocumentSemanticTokensRangeRequest(textDocument: textDocument, range: range))
    } else {
      response = try! sk.sendSync(DocumentSemanticTokensRequest(textDocument: textDocument))
    }

    return decodeFromIntArray(rawSemanticTokens: response.data)
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
      SemanticToken(start: Position(line: 1, utf16index: 0), length: 3, kind: .keyword),
      SemanticToken(start: Position(line: 1, utf16index: 8), length: 1, kind: .number),
      SemanticToken(start: Position(line: 2, utf16index: 0), length: 3, kind: .keyword),
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
      SemanticToken(start: Position(line: 0, utf16index: 0), length: 3, kind: .keyword),
      SemanticToken(start: Position(line: 0, utf16index: 8), length: 1, kind: .number),
      // var y = "test"
      SemanticToken(start: Position(line: 1, utf16index: 0), length: 3, kind: .keyword),
      SemanticToken(start: Position(line: 1, utf16index: 8), length: 6, kind: .string),
      // /* abc */ // 123
      SemanticToken(start: Position(line: 2, utf16index: 0), length: 9, kind: .comment),
      SemanticToken(start: Position(line: 2, utf16index: 10), length: 6, kind: .comment),
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
      SemanticToken(start: Position(line: 0, utf16index: 0), length: 6, kind: .keyword),
      // let x = X()
      SemanticToken(start: Position(line: 2, utf16index: 0), length: 3, kind: .keyword),
      SemanticToken(start: Position(line: 2, utf16index: 8), length: 1, kind: .struct),
      // let y = x + x
      SemanticToken(start: Position(line: 3, utf16index: 0), length: 3, kind: .keyword),
      SemanticToken(start: Position(line: 3, utf16index: 8), length: 1, kind: .variable),
      SemanticToken(start: Position(line: 3, utf16index: 12), length: 1, kind: .variable),
      // func a() {}
      SemanticToken(start: Position(line: 5, utf16index: 0), length: 4, kind: .keyword),
      // let b = {}
      SemanticToken(start: Position(line: 6, utf16index: 0), length: 3, kind: .keyword),
      // a()
      SemanticToken(start: Position(line: 8, utf16index: 0), length: 1, kind: .function),
      // b()
      SemanticToken(start: Position(line: 9, utf16index: 0), length: 1, kind: .variable),
    ])
  }
}
