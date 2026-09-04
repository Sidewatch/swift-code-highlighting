import Foundation

/// The regex rule table for Gettext. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let gettext: [(String, TokenKind)] = [
        // Translation catalogs (.po/.pot): `#`-family comment lines (translator
        // notes, `#:` references, `#,` flags), the msgid/msgstr keyword spine —
        // plural forms included — and the quoted message strings themselves.
        hashComment,
        doubleQuoted,
        ("^(msgid_plural|msgid|msgstr(\\[\\d+\\])?|msgctxt)\\b", .keyword),
    ]
}
