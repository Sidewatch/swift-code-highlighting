//
//  CustomPattern.swift
//  CodeHighlighting
//

import Foundation

/// One raw-regex rule inside a ``CustomLanguageDefinition`` — the escape hatch
/// for anything the structured fields can't express (section markers, header
/// directives, register names, exotic literals, …).
public struct CustomPattern: Codable, Equatable, Sendable {

    /// The ICU regular expression (as `NSRegularExpression` compiles it).
    /// `^`/`$` anchor per line. An invalid regex is skipped when the
    /// highlighter is built — it never fails the definition.
    public var pattern: String

    /// The token role the pattern paints, as a string:
    /// one of ``CustomPattern/validKinds``. An unknown kind fails
    /// ``CustomLanguageDefinition/decode(from:)`` with a clear error.
    public var kind: String

    /// Every accepted ``kind`` string, in documentation order.
    /// `"constant"` paints with the number-literal role, matching how the
    /// built-in tables color `true`/`false`/`nil`.
    public static let validKinds: [String] = [
        "comment", "string", "keyword", "type", "number",
        "function", "attribute", "property", "variable", "constant",
    ]

    /// Memberwise initializer for building patterns in code.
    public init(pattern: String, kind: String) {
        self.pattern = pattern
        self.kind = kind
    }

    /// The ``TokenKind`` this pattern's ``kind`` string names, or `nil` for an
    /// unknown string (which ``CustomLanguageDefinition/decode(from:)``
    /// rejects up front).
    var tokenKind: TokenKind? {
        switch kind {
        case "comment":   return .comment
        case "string":    return .string
        case "keyword":   return .keyword
        case "type":      return .type
        case "number":    return .number
        case "function":  return .function
        case "attribute": return .attribute
        case "property":  return .property
        case "variable":  return .variable
        case "constant":  return .number   // constants share the literal color, like the built-in tables
        default:          return nil
        }
    }
}
