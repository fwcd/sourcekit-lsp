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

import SourceKitD
import LanguageServerProtocol
import LSPLogging

/// A ranged token in the document used for semantic syntax highlighting.
public struct SemanticToken: Hashable {
  public var name: String?
  public var start: Position
  public var length: Int
  public var kind: Kind

  public var end: Position {
    Position(line: start.line, utf16index: start.utf16index + length)
  }
  public var range: Range<Position> {
    start..<end
  }

  public init(
    name: String? = nil,
    start: Position,
    length: Int,
    kind: Kind
  ) {
    self.name = name
    self.start = start
    self.length = length
    self.kind = kind
  }

  // TODO: Modifiers

  /// The token type. Represented using an int to make the conversion to
  /// LSP tokens efficient.
  public enum Kind: Int, CaseIterable, Hashable {
    case comment = 0
    case keyword
    case modifier
    case regexp
    case `operator`
    case namespace
    case type
    case `struct`
    case `class`
    case interface
    case `enum`
    case typeParameter
    case function
    case member
    case macro
    case variable
    case parameter
    case property
    case label
    case number
    case string

    var lspTokenType: String {
      switch self {
      case .comment:
        return "comment"
      case .keyword:
        return "keyword"
      case .modifier: 
        return "modifier"
      case .regexp:
        return "regexp"
      case .operator:
        return "operator"
      case .namespace:
        return "namespace"
      case .type:
        return "type"
      case .struct:
        return "struct"
      case .class:
        return "class"
      case .interface:
        return "interface"
      case .enum:
        return "enum"
      case .typeParameter:
        return "typeParameter"
      case .function:
        return "function"
      case .member:
        return "member"
      case .macro:
        return "macro"
      case .variable:
        return "variable"
      case .parameter:
        return "parameter"
      case .property:
        return "property"
      case .label:
        return "label"
      case .number:
        return "number"
      case .string:
        return "string"
      }
    }
  }
}

struct SemanticTokenParser {
  private let sourcekitd: SourceKitD
  private let snapshot: DocumentSnapshot

  init(sourcekitd: SourceKitD, snapshot: DocumentSnapshot) {
    self.sourcekitd = sourcekitd
    self.snapshot = snapshot
  }

  func parseTokens(_ response: SKDResponseDictionary) -> [SemanticToken] {
    let keys = sourcekitd.keys

    guard let offset: Int = response[keys.offset],
          let start: Position = snapshot.positionOf(utf8Offset: offset),
          let length: Int = response[keys.length],
          let skKind: sourcekitd_uid_t = response[keys.kind],
          let kind = parseKind(skKind) else {
      return []
    }

    let name: String? = response[keys.name]
    let validName = validTokenName(name: name, kind: kind)
    let token = SemanticToken(
      name: name,
      start: start,
      length: validName?.count ?? length,
      kind: kind
    )

    let children: [SemanticToken]
    if let substructure: SKDResponseArray = response[keys.substructure] {
      children = parseTokens(substructure)
    } else {
      children = []
    }

    return [token] + children
  }

  func parseTokens(_ response: SKDResponseArray) -> [SemanticToken] {
    var result: [SemanticToken] = []
    response.forEach { (_, value) in
      result += parseTokens(value)
      return true
    }
    return result
  }

  private func parseKind(_ uid: sourcekitd_uid_t) -> SemanticToken.Kind? {
    let values = sourcekitd.values
    switch uid {
    case values.kind_keyword,
         values.syntaxtype_keyword:
      return .keyword
    case values.syntaxtype_attribute_builtin:
      return .modifier
    case values.decl_module:
      return .namespace
    case values.decl_class,
         values.ref_class:
      return .class
    case values.decl_struct,
         values.ref_struct:
      return .struct
    case values.decl_enum,
         values.ref_enum:
      return .enum
    case values.decl_protocol,
         values.ref_protocol:
      return .interface
    case values.decl_associatedtype,
         values.decl_typealias,
         values.decl_generic_type_param,
         values.ref_associatedtype,
         values.ref_typealias,
         values.ref_generic_type_param:
      return .typeParameter
    case values.decl_function_constructor,
         values.decl_function_subscript,
         values.decl_function_method_static,
         values.decl_function_method_instance,
         values.decl_function_method_class,
         values.ref_function_constructor,
         values.ref_function_subscript,
         values.ref_function_method_static,
         values.ref_function_method_instance,
         values.ref_function_method_class:
      return .function
    case values.decl_function_operator_prefix,
         values.decl_function_operator_postfix,
         values.decl_function_operator_infix,
         values.ref_function_operator_prefix,
         values.ref_function_operator_postfix,
         values.ref_function_operator_infix:
      return .operator
    case values.decl_function_free:
      return .function
    case values.decl_var_static,
         values.decl_var_class,
         values.decl_var_instance,
         values.ref_var_static,
         values.ref_var_class,
         values.ref_var_instance:
      return .property
    case values.decl_var_local,
         values.decl_var_global,
         values.ref_var_local,
         values.ref_var_global:
      // We don't use values.syntaxtype_identifier here as it would cause
      // functions to get highlighted as variables too.
      return .variable
    case values.decl_var_parameter:
      return .parameter
    case values.syntaxtype_comment,
         values.syntaxtype_doccomment:
      return .comment
    case values.syntaxtype_type_identifier:
      return .type
    case values.syntaxtype_number:
      return .number
    case values.syntaxtype_string:
      return .string
    default:
      return nil
    }
  }

  private func validTokenName(name: String?, kind: SemanticToken.Kind?) -> String? {
    guard let name = name,
          let kind = kind else {
      return nil
    }
    switch kind {
    case .function:
      // functions/method names are returned as f.e. 'foo(a:b:)' since we care
      // about only function name, we have to adjust it a little bit
      return String(name.split(separator: "(").first ?? "")
    default:
      return name
    }
  }
}
