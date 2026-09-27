//
//  TerraformRules.swift
//  CodeHighlighting
//
//  The regex rule table for Terraform / HCL.
//
//  Created by David Sherlock on 9/5/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The regex rule table for Terraform / HCL.
/// Later rules repaint earlier ones; strings and comments paint last.
extension RuleTables {
    static let terraform: [(String, TokenKind)] = [
        hashComment,
        lineComment,
        blockComment,
        doubleQuoted,
        ("\\$\\{[^}]*\\}", .property),   // ${interpolation}
        keywords([
            "resource", "variable", "provider", "module", "data", "output", "locals", "terraform", "for", "in",
            "if", "dynamic", "count", "depends_on", "true", "false", "null",
        ]),
        ("^\\s*[a-zA-Z_][\\w-]*(?=\\s*=)", .function),   // attribute keys
        decimal,
    ]
}
