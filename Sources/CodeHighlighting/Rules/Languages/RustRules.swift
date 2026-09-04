import Foundation

/// The regex rule table for Rust. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let rust: [(String, TokenKind)] = [
        lineComment,
        blockComment,
        doubleQuoted,
        keywords([
            "fn", "let", "mut", "const", "static", "struct", "enum", "impl", "trait", "type",
            "use", "mod", "pub", "crate", "super", "self", "Self", "where", "as", "in",
            "for", "while", "loop", "if", "else", "match", "return", "break", "continue", "move",
            "ref", "async", "await", "dyn", "unsafe", "extern",
        ]),
        constants(["true", "false"]),
        types([
            "i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16", "u32", "u64",
            "u128", "usize", "f32", "f64", "bool", "char", "str", "String", "Vec", "Option",
            "Result", "Box", "Rc", "Arc", "HashMap",
        ]),
        decimalOrHex,
        ("\\b([a-zA-Z_]\\w*)\\s*[!(]", .function),
        ("#\\[[^\\]]*\\]", .attribute),
        ("'[a-z_]\\w*\\b", .attribute),
    ]
}
