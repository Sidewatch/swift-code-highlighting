//
//  ABAPRules.swift
//  CodeHighlighting
//
//  The regex rule table for ABAP.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// ABAP: `*` comment lines and `"` trailing comments, `'…'` strings and `|…|` templates, the
/// case-insensitive statement words, `ls_`/`lt_` variables, `-` structure components.
/// Written 25 Sep 2026 (the sweep found it flat).
extension RuleTables {
    static let abap: [(String, TokenKind)] = [
        ("^\\*.*$", .comment),
        ("\".*$", .comment),
        ("'(?:[^']|'')*'", .string),
        ("\\|[^|]*\\|", .string),
        ("(?i)\\b(REPORT|PROGRAM|DATA|TYPES|CONSTANTS|PARAMETERS|SELECT-OPTIONS|FIELD-SYMBOLS|BEGIN|END|OF|TYPE|LIKE|VALUE|LENGTH|DECIMALS|STANDARD|SORTED|HASHED|TABLE|WITH|KEY|UNIQUE|NON-UNIQUE|START-OF-SELECTION|END-OF-SELECTION|INITIALIZATION|AT|SELECTION-SCREEN|SELECT|SINGLE|FROM|INTO|CORRESPONDING|FIELDS|WHERE|GROUP|BY|ORDER|UP|TO|ROWS|ENDSELECT|LOOP|ENDLOOP|ASSIGNING|READ|APPEND|INSERT|MODIFY|DELETE|UPDATE|CLEAR|REFRESH|FREE|SORT|COLLECT|IF|ELSEIF|ELSE|ENDIF|CASE|WHEN|OTHERS|ENDCASE|DO|ENDDO|WHILE|ENDWHILE|CHECK|EXIT|CONTINUE|RETURN|WRITE|MESSAGE|SKIP|ULINE|NEW-LINE|CALL|FUNCTION|METHOD|METHODS|CLASS-METHODS|CLASS|ENDCLASS|DEFINITION|IMPLEMENTATION|PUBLIC|PROTECTED|PRIVATE|SECTION|INHERITING|FINAL|ABSTRACT|CREATE|OBJECT|NEW|RAISE|EXCEPTION|EXCEPTIONS|TRY|CATCH|ENDTRY|CLEANUP|ENDMETHOD|FORM|ENDFORM|PERFORM|USING|CHANGING|IMPORTING|EXPORTING|RETURNING|RAISING|OPTIONAL|DEFAULT|MOVE|MOVE-CORRESPONDING|CONCATENATE|SPLIT|CONDENSE|TRANSLATE|REPLACE|FIND|SHIFT|DESCRIBE|ASSIGN|UNASSIGN|IS|INITIAL|BOUND|ASSIGNED|NOT|AND|OR|EQ|NE|LT|GT|LE|GE|CO|CN|CA|NA|CS|NS|CP|NP|IN|BETWEEN|INTERFACE|ENDINTERFACE|EVENTS|COMMIT|ROLLBACK|WORK|AUTHORITY-CHECK|INCLUDE|TABLES|INFOTYPES|NODES|RANGES|STATICS|CONV|REF|COND|SWITCH|REDUCE|FILTER|EXACT|CAST|LINES|STRLEN|XSTRLEN|BOOLC|XSDBOOL)\\b", .keyword),
        ("(?i)(?<=\\bTYPE\\s{1,4})[a-z_]\\w*", .type),
        ("(?i)\\b(lv|lt|ls|lo|lr|lc|gv|gt|gs|go|gr|gc|iv|it|is|io|ev|et|es|eo|cv|ct|cs|co|rv|rt|rs|ro|wa)_\\w+", .variable),
        ("<[a-z_]\\w*>", .variable),
        ("\\b[a-z_]\\w*-[a-z_]\\w*\\b", .property),
        ("\\b\\d+(\\.\\d+)?\\b", .number),
        ("\\b[a-z_]\\w*(?=\\()", .function),
    ]
}
