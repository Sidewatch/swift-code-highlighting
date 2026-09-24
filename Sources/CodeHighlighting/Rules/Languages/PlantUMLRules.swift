//
//  PlantUMLRules.swift
//  CodeHighlighting
//
//  The regex rule table for PlantUML.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// PlantUML: `'` comments, `@startuml` … `@enduml`, the diagram words, arrows, `: message`
/// text, capitalised names. Written 25 Sep 2026 (the sweep found it flat).
extension RuleTables {
    static let plantuml: [(String, TokenKind)] = [
        ("^\\s*'.*$", .comment),
        ("/'[\\s\\S]*?'/", .comment),
        doubleQuotedPlain,
        ("@(start|end)[a-z]+", .keyword),
        keywords(["title", "skinparam", "actor", "participant", "database", "queue", "boundary", "control", "entity", "collections", "activate", "deactivate", "destroy", "create", "alt", "else", "end", "loop", "opt", "par", "break", "critical", "group", "ref", "over", "note", "left", "right", "of", "as", "class", "interface", "enum", "abstract", "annotation", "package", "namespace", "state", "object", "usecase", "component", "node", "cloud", "rectangle", "frame", "folder", "storage", "artifact", "card", "return", "autonumber", "hide", "show", "newpage", "header", "footer", "legend", "caption", "top", "bottom", "center", "endlegend", "endnote", "endheader", "endfooter", "start", "stop", "if", "then", "elseif", "endif", "while", "endwhile", "repeat", "fork", "again", "partition", "split", "detach", "kill", "extends", "implements", "together", "sprite", "scale", "rotate", "box", "endbox", "mainframe"]),
        ("<?[-.]{1,4}>?|<-->|<\\|--|--\\|>|\\*--|--\\*|o--|--o|\\.\\.>|<\\.\\.|\\|>|<\\|", .type),
        (":.*$", .string),
        ("\\b[A-Z][\\w]*\\b", .variable),
        ("#[0-9A-Fa-f]{6}\\b|#[A-Za-z]+\\b", .number),
        ("\\b\\d+\\b", .number),
    ]
}
