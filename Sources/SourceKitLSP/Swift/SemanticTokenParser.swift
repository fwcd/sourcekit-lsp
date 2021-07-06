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
  public var start: Position
  public var length: Int
  public var kind: Kind
  public var modifiers: Modifiers

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
    kind: Kind,
    modifiers: Modifiers = []
  ) {
    self.start = start
    self.length = length
    self.kind = kind
    self.modifiers = modifiers
  }

  /// The token type. Represented using an int to make the conversion to
  /// LSP tokens efficient.
  public enum Kind: UInt32, CaseIterable, Hashable {
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
    case macro
    case variable
    case parameter
    case property
    case label
    case number
    case string

    /// The name of the token type used by LSP.
    var lspName: String {
      switch self {
      case .comment: return "comment"
      case .keyword: return "keyword"
      case .modifier: return "modifier"
      case .regexp: return "regexp"
      case .operator: return "operator"
      case .namespace: return "namespace"
      case .type: return "type"
      case .struct: return "struct"
      case .class: return "class"
      case .interface: return "interface"
      case .enum: return "enum"
      case .typeParameter: return "typeParameter"
      case .function: return "function"
      case .macro: return "macro"
      case .variable: return "variable"
      case .parameter: return "parameter"
      case .property: return "property"
      case .label: return "label"
      case .number: return "number"
      case .string: return "string"
      }
    }
  }

  /// Additional metadata about a token.
  public struct Modifiers: OptionSet, CaseIterable, Hashable {
    public static let declaration = Self(rawValue: 1 << 0)
    public static let definition = Self(rawValue: 1 << 1)
    public static let readonly = Self(rawValue: 1 << 2)
    public static let `static` = Self(rawValue: 1 << 3)
    public static let deprecated = Self(rawValue: 1 << 4)
    public static let abstract = Self(rawValue: 1 << 5)
    public static let async = Self(rawValue: 1 << 6)
    public static let modification = Self(rawValue: 1 << 7)
    public static let documentation = Self(rawValue: 1 << 8)
    public static let defaultLibrary = Self(rawValue: 1 << 9)

    /// All available modifiers, in order
    public static let allCases: [Self] = [
      .declaration,
      .definition,
      .readonly,
      .static,
      .deprecated,
      .abstract,
      .async,
      .modification,
      .documentation,
      .defaultLibrary,
    ]

    public let rawValue: UInt32

    /// The name of the modifier used by LSP.
    public var lspName: String? {
      switch self {
      case .declaration: return "declaration"
      case .definition: return "definition"
      case .static: return "static"
      case .deprecated: return "deprecated"
      case .abstract: return "abstract"
      case .async: return "async"
      case .modification: return "modification"
      case .documentation: return "documentation"
      case .defaultLibrary: return "defaultLibrary"
      default: return nil
      }
    }

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }
  }
}

/// Encodes to the LSP representation of semantic tokens.
public func encodeToIntArray(semanticTokens tokens: [SemanticToken]) -> [UInt32] {
  var current = Position(line: 0, utf16index: 0)
  var rawTokens: [UInt32] = []
  rawTokens.reserveCapacity(tokens.count * 5)

  for token in tokens {
    let previous = Position(
      line: current.line,
      utf16index: current.line == token.start.line ? current.utf16index : 0
    )
    current = token.start
    rawTokens += [
      UInt32(token.start.line - previous.line),
      UInt32(token.start.utf16index - previous.utf16index),
      UInt32(token.length),
      token.kind.rawValue,
      token.modifiers.rawValue
    ]
  }

  return rawTokens
}

/// Decodes the LSP representation of semantic tokens
public func decodeFromIntArray(rawSemanticTokens rawTokens: [UInt32]) -> [SemanticToken] {
  var current = Position(line: 0, utf16index: 0)
  var tokens: [SemanticToken] = []
  tokens.reserveCapacity(rawTokens.count / 5)

  for i in stride(from: 0, to: rawTokens.count, by: 5) {
    let lineDelta = Int(rawTokens[i])
    let charDelta = Int(rawTokens[i + 1])
    let length = Int(rawTokens[i + 2])
    let rawKind = rawTokens[i + 3]
    let rawModifiers = rawTokens[i + 4]

    guard let kind = SemanticToken.Kind(rawValue: rawKind) else { continue }
    let modifiers = SemanticToken.Modifiers(rawValue: rawModifiers)

    current.line += lineDelta

    if lineDelta == 0 {
      current.utf16index += charDelta
    } else {
      current.utf16index = charDelta
    }

    tokens.append(SemanticToken(
      start: current,
      length: length,
      kind: kind,
      modifiers: modifiers
    ))
  }

  return tokens
}

/// Parses semantic tokens from sourcekitd response dictionaries.
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

    let token = SemanticToken(
      start: start,
      length: length,
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
         values.decl_function_free,
         values.decl_function_method_static,
         values.decl_function_method_instance,
         values.decl_function_method_class,
         values.ref_function_constructor,
         values.ref_function_destructor,
         values.ref_function_free,
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
}
