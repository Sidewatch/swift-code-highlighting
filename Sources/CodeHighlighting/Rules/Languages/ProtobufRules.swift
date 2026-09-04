import Foundation

/// The regex rule table for Protobuf. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let protobuf: [(String, TokenKind)] = [
        lineComment,
        blockComment,
        doubleQuoted,
        keywords([
                "syntax", "package", "import", "public", "weak", "message", "enum", "service", "rpc", "returns",
                "option", "repeated", "optional", "required", "reserved", "oneof", "map", "extend", "group", "stream",
            ]),
        types([
                "double", "float", "int32", "int64", "uint32", "uint64", "sint32", "sint64", "fixed32", "fixed64",
                "sfixed32", "sfixed64", "bool", "string", "bytes",
            ]),
        decimal,
    ]
}
