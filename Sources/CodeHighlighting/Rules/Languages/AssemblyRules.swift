//
//  AssemblyRules.swift
//  CodeHighlighting
//
//  The regex rule table for assembly (NASM / GAS).
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// Assembly, NASM and GAS: `;` and `#` comments, labels, directives, the x86 and ARM register
/// names, an indented mnemonic, memory operands, hex / binary literals. Written 25 Sep 2026 (the
/// sweep found it flat).
extension RuleTables {
    static let assembly: [(String, TokenKind)] = [
        (";.*$", .comment),
        ("^\\s*#.*$", .comment),
        ("//.*$", .comment),
        doubleQuotedPlain,
        singleQuotedPlain,
        ("^\\s*[A-Za-z_.$][\\w.$]*:", .function),
        ("^\\s*\\.[a-z_]+\\b", .keyword),
        ("(?i)\\b(section|segment|global|globl|extern|equ|db|dw|dd|dq|dt|resb|resw|resd|resq|times|org|bits|default|align|use32|use64|struc|endstruc|macro|endmacro|include|incbin|byte|word|dword|qword|ptr|offset|rel)\\b", .keyword),
        ("(?i)\\b(r[abcd]x|e[abcd]x|[abcd][lhx]|r[sd]i|e[sd]i|[sd]il?|r[sb]p|e[sb]p|[sb]pl?|r(8|9|1[0-5])[dwb]?|[xyz]mm\\d{1,2}|st\\(?\\d\\)?|[cdefgs]s|rip|eip|eflags|x\\d{1,2}|w\\d{1,2}|sp|lr|pc|fp|xzr|wzr|v\\d{1,2})\\b", .variable),
        ("%[a-z]+[0-9a-z]*", .variable),
        ("^\\s+[a-zA-Z][a-zA-Z0-9.]*\\b", .keyword),
        ("\\[[^\\]]*\\]", .property),
        ("\\b(0x[0-9a-fA-F]+|[0-9][0-9a-fA-F]*[hH]|[01]+[bB]|\\d+)\\b|\\$[0-9a-fA-Fx]+", .number),
    ]
}
