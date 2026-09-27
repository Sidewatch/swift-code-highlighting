//
//  PrismaRules.swift
//  CodeHighlighting
//
//  The regex rule table for Prisma.
//
//  Created by David Sherlock on 9/5/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The regex rule table for Prisma.
/// Later rules repaint earlier ones; strings and comments paint last.
extension RuleTables {
    static let prisma: [(String, TokenKind)] = [
        lineComment,
        doubleQuoted,
        keywords(["model", "enum", "datasource", "generator", "type"]),
        ("@@?\\w+", .attribute),   // @id, @@map, @default…
        ("\\b[A-Z]\\w*\\b", .type),   // field types / models
        decimal,
    ]
}
