//
//  SymbolQueries.swift
//  CodeHighlighting
//

import Foundation
import CodeLanguage

/// Hand-written definition queries per language (tree-sitter grammars we vendor
/// don't ship `tags.scm`). A query that fails to compile for a grammar just
/// yields no symbols for that language — graceful. Capture names map to
/// `SymbolKind` via `SymbolKind(capture:)`.
public enum SymbolQueries {
    /// The query source per supported language. A language absent here yields
    /// no symbols (and `ProjectSymbolIndex` skips its files entirely).
    public static let sources: [Language: String] = [
        .javascript: js,
        .typescript: ts,
        // .tsx AND .jsx parse with the TSX grammar (grammars[.jsx] aliases it),
        // which uses TypeScript's node types — so both take the ts query (the js
        // query's `(class_declaration name: (identifier))` shape would compile
        // but never match under it).
        .tsx: ts,
        .jsx: ts,
        .python: py,
        .php: php,
        .go: go,
        .rust: rust,
        .java: java,
        .ruby: ruby,
        .c: c,
        .cpp: cpp,
        .csharp: csharp,
        .lua: lua,
        .swift: swift,
        // Grammars that were vendored for highlighting but had no symbol query, so
        // their files had no outline, hover, go-to-definition or completion tier.
        .bash: bash,
        .kotlin: kotlin,
        .dart: dart,
        .scala: scala,
        .sql: sql,
    ]

    private static let bash = """
    (function_definition name: (word) @function)
    """

    // tree-sitter-kotlin names nothing by field: the declaration's own
    // `type_identifier` / `simple_identifier` child IS the name (the receiver,
    // parameters and return type are all wrapped in their own nodes). `class`
    // and `interface` share `class_declaration`, told apart by the keyword.
    private static let kotlin = """
    (class_declaration "interface" (type_identifier) @interface)
    (class_declaration "class" (type_identifier) @class)
    (object_declaration (type_identifier) @class)
    (function_declaration (simple_identifier) @function)
    (class_body (property_declaration (variable_declaration (simple_identifier) @property)))
    (source_file (property_declaration (variable_declaration (simple_identifier) @property)))
    (type_alias (type_identifier) @type)
    """

    // A Dart method is a `function_signature` inside a `method_signature`; one
    // pattern covers both so no node is captured twice (methods read as
    // "function", the way Swift's query reads them).
    private static let dart = """
    (class_definition name: (identifier) @class)
    (mixin_declaration (identifier) @class)
    (enum_declaration name: (identifier) @enum)
    (extension_declaration name: (identifier) @type)
    (function_signature name: (identifier) @function)
    (getter_signature name: (identifier) @property)
    (setter_signature name: (identifier) @property)
    """

    private static let scala = """
    (class_definition name: (identifier) @class)
    (object_definition name: (identifier) @class)
    (trait_definition name: (identifier) @interface)
    (enum_definition name: (identifier) @enum)
    (function_definition name: (identifier) @function)
    (function_declaration name: (identifier) @function)
    (val_definition pattern: (identifier) @constant)
    (var_definition pattern: (identifier) @variable)
    """

    // DDL only — a query file's structure is what it creates. `create_function`
    // also matches a custom RETURNS type spelled as an object_reference (rare:
    // builtin return types are keyword nodes), which then shows as a second entry.
    private static let sql = """
    (create_table (object_reference name: (identifier) @type))
    (create_view (object_reference name: (identifier) @type))
    (create_function (object_reference name: (identifier) @function))
    (create_type (object_reference name: (identifier) @type))
    (create_schema (identifier) @module)
    (create_database name: (identifier) @module)
    """

    private static let js = """
    (function_declaration name: (identifier) @function)
    (generator_function_declaration name: (identifier) @function)
    (class_declaration name: (identifier) @class)
    (method_definition name: (property_identifier) @method)
    (variable_declarator name: (identifier) @function value: (arrow_function))
    (variable_declarator name: (identifier) @function value: (function_expression))
    """

    private static let ts = """
    (function_declaration name: (identifier) @function)
    (class_declaration name: (type_identifier) @class)
    (method_definition name: (property_identifier) @method)
    (interface_declaration name: (type_identifier) @interface)
    (type_alias_declaration name: (type_identifier) @type)
    (enum_declaration name: (identifier) @enum)
    (variable_declarator name: (identifier) @function value: (arrow_function))
    (abstract_method_signature name: (property_identifier) @method)
    (public_field_definition name: (property_identifier) @property)
    """

    private static let py = """
    (function_definition name: (identifier) @function)
    (class_definition name: (identifier) @class)
    """

    /// PHP. Properties index by their BARE name (`private $cache` defines `cache`)
    /// because access sites spell them bare too (`$this->cache`); the `$`-prefixed
    /// lookup fallback lives in the caller.
    private static let php = """
    (function_definition name: (name) @function)
    (method_declaration name: (name) @method)
    (class_declaration name: (name) @class)
    (interface_declaration name: (name) @interface)
    (trait_declaration name: (name) @class)
    (enum_declaration name: (name) @enum)
    (property_declaration (property_element name: (variable_name (name) @property)))
    (const_declaration (const_element (name) @constant))
    """

    private static let go = """
    (function_declaration name: (identifier) @function)
    (method_declaration name: (field_identifier) @method)
    (type_declaration (type_spec name: (type_identifier) @type))
    """

    private static let rust = """
    (function_item name: (identifier) @function)
    (struct_item name: (type_identifier) @struct)
    (enum_item name: (type_identifier) @enum)
    (trait_item name: (type_identifier) @interface)
    (mod_item name: (identifier) @module)
    (const_item name: (identifier) @constant)
    (impl_item type: (type_identifier) @class)
    """

    private static let java = """
    (class_declaration name: (identifier) @class)
    (interface_declaration name: (identifier) @interface)
    (method_declaration name: (identifier) @method)
    (constructor_declaration name: (identifier) @method)
    (enum_declaration name: (identifier) @enum)
    """

    private static let ruby = """
    (method name: (identifier) @method)
    (singleton_method name: (identifier) @method)
    (class name: (constant) @class)
    (module name: (constant) @module)
    """

    private static let c = """
    (function_definition declarator: (function_declarator declarator: (identifier) @function))
    (struct_specifier name: (type_identifier) @struct)
    (enum_specifier name: (type_identifier) @enum)
    """

    private static let cpp = """
    (function_definition declarator: (function_declarator declarator: (identifier) @function))
    (function_definition declarator: (function_declarator declarator: (field_identifier) @method))
    (class_specifier name: (type_identifier) @class)
    (struct_specifier name: (type_identifier) @struct)
    (enum_specifier name: (type_identifier) @enum)
    (namespace_definition name: (namespace_identifier) @module)
    """

    private static let csharp = """
    (class_declaration name: (identifier) @class)
    (interface_declaration name: (identifier) @interface)
    (struct_declaration name: (identifier) @struct)
    (method_declaration name: (identifier) @method)
    (constructor_declaration name: (identifier) @method)
    (enum_declaration name: (identifier) @enum)
    (property_declaration name: (identifier) @property)
    """

    private static let lua = """
    (function_declaration name: (identifier) @function)
    """

    /// Swift. `class_declaration` is the grammar's node for class/struct/enum/
    /// extension alike (they differ only by their `declaration_kind` child), so
    /// one pattern captures all four and they read as `@class` → `.type`.
    ///
    /// Patterns must NOT overlap: `symbols(...)` appends every capture of every
    /// match, so two patterns matching one node would emit the symbol twice. A
    /// method therefore captures as `@function` from the single
    /// `function_declaration` pattern (methods and free functions share that
    /// node) — the same trade every other language here makes. `init`/`deinit`
    /// and protocol requirements are distinct node types, so they can safely
    /// carry the finer `@method` kind.
    private static let swift = """
    (class_declaration name: (type_identifier) @class)
    (protocol_declaration name: (type_identifier) @interface)
    (typealias_declaration name: (type_identifier) @type)
    (function_declaration name: (simple_identifier) @function)
    (protocol_function_declaration name: (simple_identifier) @method)
    (init_declaration "init" @method)
    (deinit_declaration "deinit" @method)
    """
}
