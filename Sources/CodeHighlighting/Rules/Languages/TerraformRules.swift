//
//  TerraformRules.swift
//  CodeHighlighting
//
//  The regex rule table for Terraform / Hcl.
//
//  Created by David Sherlock on 9/5/26.
//

import Foundation

/// The regex rule table for Terraform / Hcl. Order matters: earlier rules win overlaps.
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
