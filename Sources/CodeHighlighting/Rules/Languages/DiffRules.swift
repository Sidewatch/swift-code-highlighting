import Foundation

/// The regex rule table for Diff. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let diff: [(String, TokenKind)] = [
        // Unified diffs / git patches (`git show`, .patch files). Added/removed
        // use their dedicated roles so themes paint real diff tints. The +++/---
        // file headers require a path-ish operand: the default a/ b/ prefixes,
        // git's `diff.mnemonicPrefix` i/ w/ c/ o/, /dev/null, a quoted path, or
        // POSIX `diff -u`'s `file<TAB>timestamp` form — so a removed `-- foo`
        // line ("--- foo") stays a removal while both git and plain POSIX
        // headers render as headers. (`diff.noprefix` headers are inherently
        // ambiguous with that per-line rule; DiffTab's hunk-aware colorizer
        // handles those.)
        ("^(?:diff|index|new file|deleted file|old mode|new mode|rename|similarity|dissimilarity|copy|Binary files|commit|Merge:|Author:|AuthorDate:|Commit:|CommitDate:|Date:|\\\\ No newline).*$", .comment),
        ("^(?:\\+\\+\\+|---) (?:[abiwco]/|/dev/null|\"|[^\\t\\n]*\\t).*$", .comment),
        ("^@@[^\\n]*", .function),
        ("^\\+(?!\\+\\+ (?:[abiwco]/|/dev/null|\"|[^\\t\\n]*\\t)).*$", .added),
        ("^-(?!-- (?:[abiwco]/|/dev/null|\"|[^\\t\\n]*\\t)).*$", .removed),
    ]
}
