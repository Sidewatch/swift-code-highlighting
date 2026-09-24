//
//  NixRules.swift
//  CodeHighlighting
//
//  The regex rule table for Nix.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// Nix: `#` and block comments, `"…"` and `''…''` strings, the expression words, attribute
/// names before `=`, function arguments before `:`, paths and `<search-paths>`, the standard
/// library names. Written 25 Sep 2026 (the ML family gave it two roles).
extension RuleTables {
    static let nix: [(String, TokenKind)] = [
        hashComment,
        blockComment,
        ("''[\\s\\S]*?''(?!\\$)", .string),
        doubleQuoted,
        keywords(["let", "in", "with", "rec", "inherit", "if", "then", "else", "assert", "or", "import", "throw", "abort"]),
        ("\\b(true|false|null)\\b", .number),
        ("<[\\w./-]+>", .string),
        ("(\\.\\.?|~)?/[\\w./+-]+", .string),
        ("\\b(builtins|lib|pkgs|stdenv|self|super|config|options|system|inputs|outputs|nixpkgs|flake-utils)\\b", .type),
        ("\\b(mkDerivation|mkShell|fetchurl|fetchFromGitHub|fetchgit|map|filter|toString|concatStringsSep|attrValues|attrNames|mapAttrs|genAttrs|optional|optionals|optionalString|callPackage|writeText|writeShellScriptBin|eachDefaultSystem|eachSystem|listToAttrs|hasAttr|getAttr|readFile|fromJSON|toJSON|elem|length|head|tail|foldl|foldr|substring|stringLength|replaceStrings|splitString|removeSuffix|removePrefix)\\b", .function),
        ("\\b[a-zA-Z_][\\w'-]*(?=\\s*=[^=])", .property),
        ("\\b[a-zA-Z_][\\w'-]*(?=\\s*:(?!:))", .variable),
        ("\\$\\{|\\}", .keyword),
        ("\\b\\d+(\\.\\d+)?\\b", .number),
    ]
}
