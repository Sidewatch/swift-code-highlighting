import Foundation

/// The regex rule table for SCSS / Sass / Less. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let scss: [(String, TokenKind)] = [
        // CSS supersets whose variables (`$var` in SCSS/Sass, `@var` in Less)
        // the CSS tree-sitter grammar turns into ERROR nodes that swallow
        // neighboring declarations (indented Sass barely parses at all), so
        // these route here instead of reusing that grammar — see the note by
        // the grammar table in `TreeSitterHighlighter`. Later rules overwrite
        // earlier ones: property names paint before the variable rules so
        // `$primary:` / `@primary:` keep the variable color, and the known
        // at-keywords repaint over the generic Less `@var` rule.
        lineComment,
        blockComment,
        doubleQuoted,
        singleQuoted,
        ("\\b\\d+(\\.\\d+)?(px|em|rem|%|vh|vw|s|ms|fr|deg)?\\b", .number),
        ("[.#%][a-zA-Z_-][\\w-]*", .function),   // selectors (+ SCSS %placeholders)
        ("#[0-9a-fA-F]{3,8}\\b", .number),   // hex colors, after `#fff`-shaped selectors
        ("[a-z-]+(?=\\s*:)", .type),   // property names
        ("@[a-zA-Z_-][\\w-]*", .property),   // Less @variables
        ("@(media|import|charset|namespace|supports|keyframes|font-face|page|include|mixin|function|return|extend|use|forward|if|else|each|for|while|content|at-root|debug|warn|error|plugin)\\b", .keyword),
        ("\\$[a-zA-Z_-][\\w-]*", .property),   // SCSS/Sass $variables
    ]
}
