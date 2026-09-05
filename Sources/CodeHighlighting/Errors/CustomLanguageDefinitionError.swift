//
//  CustomLanguageDefinitionError.swift
//  CodeHighlighting
//
//  What went wrong decoding or validating a hand-authored ``CustomLanguageDefinition``.
//
//  Created by David Sherlock on 9/5/26.
//

import Foundation

/// What went wrong decoding or validating a hand-authored
/// ``CustomLanguageDefinition``. Every case has a human-readable
/// `errorDescription` suitable for showing directly to the file's author.
public enum CustomLanguageDefinitionError: Error, Equatable, LocalizedError {

    /// The data isn't valid JSON at all (syntax error, wrong encoding, …).
    case invalidJSON(detail: String)

    /// A required field (`name` or `extensions`) is missing.
    case missingField(String)

    /// A field is present but has the wrong JSON type.
    case wrongType(field: String, expected: String)

    /// `name` is present but empty (or whitespace-only).
    case emptyName

    /// `extensions` is present but empty, or contains only empty strings.
    case emptyExtensions

    /// `patterns[index].kind` isn't one of ``CustomPattern/validKinds``.
    case unknownPatternKind(kind: String, index: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON(let detail):
            return "The file is not valid JSON: \(detail)"
        case .missingField(let field):
            return "Missing required field \"\(field)\"."
        case .wrongType(let field, let expected):
            return "Field \"\(field)\" has the wrong type — expected \(expected)."
        case .emptyName:
            return "\"name\" must not be empty."
        case .emptyExtensions:
            return "\"extensions\" must list at least one file extension (without the dot), e.g. [\"jsfx\"]."
        case .unknownPatternKind(let kind, let index):
            return "patterns[\(index)] has unknown kind \"\(kind)\". Valid kinds: "
                + CustomPattern.validKinds.joined(separator: ", ") + "."
        }
    }
}
