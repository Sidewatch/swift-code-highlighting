//
//  FortranRules.swift
//  CodeHighlighting
//
//  The regex rule table for Fortran.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// Fortran (free form, with fixed-form `C` comment lines tolerated): `!` comments, the
/// case-insensitive statement words, intrinsic types, `%` components, `1.0d0` literals.
/// Written 25 Sep 2026 (the sweep found it flat).
extension RuleTables {
    static let fortran: [(String, TokenKind)] = [
        ("!.*$", .comment),
        ("^[cC*].*$", .comment),
        doubleQuotedPlain,
        singleQuotedPlain,
        ("(?i)\\b(program|module|contains|subroutine|function|result|end|implicit|none|intent|in|out|inout|do|concurrent|enddo|if|then|else|elseif|endif|call|print|write|read|allocate|deallocate|use|type|pure|elemental|recursive|parameter|dimension|allocatable|select|case|while|return|stop|only|private|public|interface|procedure|abstract|extends|class|where|elsewhere|forall|cycle|exit|goto|continue|format|open|close|inquire|namelist|data|save|target|pointer|optional|value|volatile|import|block|associate|enum|enumerator|sequence|bind|kind|len)\\b", .keyword),
        ("(?i)\\b(integer|real|double\\s+precision|complex|character|logical)\\b", .type),
        ("\\b\\d+(\\.\\d*)?([dDeE][+-]?\\d+)?(_\\w+)?\\b", .number),
        ("(?i)\\b(sum|size|abs|sqrt|exp|log|sin|cos|tan|min|max|mod|nint|int|real|dble|trim|len|allocated|present|associated|huge|tiny|epsilon|matmul|dot_product|transpose|reshape|maxval|minval|count|any|all)\\b(?=\\s*\\()", .function),
        ("%\\w+", .property),
        ("\\b[a-zA-Z_]\\w*(?=\\s*\\()", .function),
    ]
}
