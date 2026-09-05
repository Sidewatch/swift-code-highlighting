//
//  PrismaRules.swift
//  CodeHighlighting
//
//  The regex rule table for Prisma.
//
//  Created by David Sherlock on 9/5/26.
//

import Foundation

/// The regex rule table for Prisma. Order matters: earlier rules win overlaps.
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
