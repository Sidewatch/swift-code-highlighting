; Types

(type_identifier) @type
(predefined_type) @type.builtin

((identifier) @type
 (#match? @type "^[A-Z]"))

(type_arguments
  "<" @punctuation.bracket
  ">" @punctuation.bracket)

; Variables

(required_parameter (identifier) @variable.parameter)
(optional_parameter (identifier) @variable.parameter)

; Keywords

[ "abstract"
  "declare"
  "enum"
  "export"
  "implements"
  "interface"
  "keyof"
  "namespace"
  "private"
  "protected"
  "public"
  "type"
  "readonly"
  "override"
  "satisfies"
] @keyword

; Sidewatch additions (4 Sep 2026): tokens the grammar defines but the upstream query left plain.
; Appended last on purpose — the highlighter lets the highest pattern index win.
[ "asserts" "is" "global" "module" "namespace" "declare" "readonly" "keyof" "infer" "satisfies" "override" "abstract" "implements" "enum" "type" "accessor" "in" "private" "protected" "public" "static" "get" "set" "any" "unknown" "never" "void" "object" "symbol" "boolean" "number" "string" ] @keyword
