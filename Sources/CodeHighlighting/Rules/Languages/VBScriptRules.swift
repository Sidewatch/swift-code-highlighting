//
//  VBScriptRules.swift
//  CodeHighlighting
//
//  The regex rule table for VBScript.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// VBScript (case-insensitive): `'` and `Rem` comments, the statement words, `vb…` constants,
/// the built-in functions, calls. Written 25 Sep 2026 (the sweep found it flat).
extension RuleTables {
    static let vbscript: [(String, TokenKind)] = [
        ("'.*$", .comment),
        ("(?i)^\\s*Rem\\b.*$", .comment),
        doubleQuotedPlain,
        ("(?i)\\b(Option|Explicit|Dim|Set|Const|If|Then|Else|ElseIf|End|Function|Sub|Do|Loop|Until|While|Wend|For|Each|Next|In|To|Step|Exit|Call|Select|Case|With|New|Not|And|Or|Xor|Is|Mod|True|False|Nothing|Null|Empty|On|Error|Resume|Goto|ReDim|Preserve|Private|Public|Default|Class|Property|Get|Let|ByVal|ByRef|Randomize|Erase|Execute|Eval|Stop|WScript)\\b", .keyword),
        ("(?i)\\bvb[A-Za-z]+\\b", .type),
        ("(?i)\\b(CreateObject|GetObject|MsgBox|InputBox|Len|Left|Right|Mid|Trim|LTrim|RTrim|Split|Join|Replace|InStr|InStrRev|UCase|LCase|CDbl|CInt|CLng|CStr|CBool|CDate|IsNumeric|IsNull|IsEmpty|IsObject|IsArray|Array|UBound|LBound|FormatNumber|FormatCurrency|FormatDateTime|Now|Date|Time|DateAdd|DateDiff|Abs|Int|Fix|Round|Sqr|Rnd|Chr|Asc|Hex|Oct|TypeName|VarType)\\b", .function),
        ("\\b\\d+(\\.\\d+)?\\b|&H[0-9A-Fa-f]+", .number),
        ("\\b[A-Za-z_]\\w*(?=\\s*\\()", .function),
    ]
}
