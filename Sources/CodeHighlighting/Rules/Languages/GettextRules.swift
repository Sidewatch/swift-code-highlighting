//
//  GettextRules.swift
//  CodeHighlighting
//
//  The regex rule table for Gettext.
//
//  Created by David Sherlock on 9/5/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The regex rule table for Gettext.
/// Later rules repaint earlier ones; strings and comments paint last.
extension RuleTables {
    static let gettext: [(String, TokenKind)] = [
        // Translation catalogues (.po/.pot): `#`-family comment lines (translator
        // notes, `#:` references, `#,` flags), the msgid/msgstr keyword spine —
        // plural forms included — and the quoted message strings themselves.
        hashComment,
        doubleQuoted,
        ("^(msgid_plural|msgid|msgstr(\\[\\d+\\])?|msgctxt)\\b", .keyword),
    ]
}
