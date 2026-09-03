; Functions

(call_expression
  function: (qualified_identifier
    name: (identifier) @function))

(template_function
  name: (identifier) @function)

(template_method
  name: (field_identifier) @function)

(template_function
  name: (identifier) @function)

(function_declarator
  declarator: (qualified_identifier
    name: (identifier) @function))

(function_declarator
  declarator: (field_identifier) @function)

; Types

((namespace_identifier) @type
 (#match? @type "^[A-Z]"))

(auto) @type

; Constants

(this) @variable.builtin
(null "nullptr" @constant)

; Modules
(module_name
  (identifier) @module)

; Keywords

[
 "catch"
 "class"
 "co_await"
 "co_return"
 "co_yield"
 "constexpr"
 "constinit"
 "consteval"
 "delete"
 "explicit"
 "final"
 "friend"
 "mutable"
 "namespace"
 "noexcept"
 "new"
 "override"
 "private"
 "protected"
 "public"
 "template"
 "throw"
 "try"
 "typename"
 "using"
 "concept"
 "requires"
 "virtual"
 "import"
 "export"
 "module"
] @keyword

; Strings

(raw_string_literal) @string

; Sidewatch additions (4 Sep 2026): tokens the grammar defines but the upstream query left plain.
; Appended last on purpose — the highlighter lets the highest pattern index win.
[ "goto" "register" "extern" "static" "inline" "volatile" "const" "signed" "unsigned" "alignof" "alignas" "decltype" "operator" "noexcept" "constexpr" "consteval" "constinit" "explicit" "virtual" "override" "final" "mutable" "friend" "typename" "template" "namespace" "using" "concept" "requires" "co_return" "co_await" "co_yield" "static_assert" "sizeof" "nullptr" "delete" "new" "try" "catch" "throw" ] @keyword
[ (true) (false) ] @boolean
