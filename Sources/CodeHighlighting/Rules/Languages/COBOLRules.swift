//
//  COBOLRules.swift
//  CodeHighlighting
//
//  The regex rule table for COBOL.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// COBOL: a `*` in column 7 is a comment line, `*>` a floating comment; the divisions and verbs
/// (case-insensitive), `PIC` clauses as types, level numbers, paragraph names. Written
/// 25 Sep 2026 (the sweep found it flat).
extension RuleTables {
    static let cobol: [(String, TokenKind)] = [
        ("^.{6}\\*.*$", .comment),
        ("\\*>.*$", .comment),
        doubleQuotedPlain,
        singleQuotedPlain,
        ("(?i)\\bPIC(TURE)?\\s+(IS\\s+)?[XxAa9SsVvZz0-9()+,.$*-]+", .type),
        ("(?i)\\b(IDENTIFICATION|ENVIRONMENT|DATA|PROCEDURE|DIVISION|PROGRAM-ID|AUTHOR|INPUT-OUTPUT|FILE-CONTROL|FILE|SECTION|WORKING-STORAGE|LINKAGE|FD|SD|SELECT|ASSIGN|TO|ORGANIZATION|ACCESS|MODE|IS|LINE|SEQUENTIAL|INDEXED|RELATIVE|RECORD|KEY|OPEN|INPUT|OUTPUT|I-O|EXTEND|CLOSE|READ|WRITE|REWRITE|DELETE|START|PERFORM|UNTIL|VARYING|FROM|BY|THRU|THROUGH|TIMES|END-PERFORM|END-READ|END-WRITE|END-IF|END-EVALUATE|END-CALL|END-STRING|END-UNSTRING|END-COMPUTE|MOVE|ADD|SUBTRACT|MULTIPLY|DIVIDE|COMPUTE|GIVING|ROUNDED|DISPLAY|ACCEPT|STOP|RUN|IF|ELSE|EVALUATE|WHEN|OTHER|AT|END|NOT|INVALID|VALUE|VALUES|ZERO|ZEROS|ZEROES|SPACE|SPACES|HIGH-VALUES|LOW-VALUES|INTO|INITIALIZE|STRING|UNSTRING|DELIMITED|SIZE|CALL|USING|RETURNING|EXIT|GO|BACK|GOBACK|CONTINUE|COPY|REDEFINES|OCCURS|DEPENDING|ON|SET|UP|DOWN|SEARCH|ALL|INSPECT|TALLYING|REPLACING|AND|OR|EQUAL|GREATER|LESS|THAN|SORT|MERGE|RELEASE|RETURN|COMP|COMP-3|BINARY|PACKED-DECIMAL|USAGE|SIGN|LEADING|TRAILING|SEPARATE|JUSTIFIED|BLANK|FILLER)\\b", .keyword),
        ("^\\s*\\d{2}\\b", .number),
        ("^\\s*[A-Za-z0-9][A-Za-z0-9-]*\\.$", .function),
        ("\\b\\d+(\\.\\d+)?\\b", .number),
        ("\\b[A-Za-z][A-Za-z0-9]*-[A-Za-z0-9-]+\\b", .variable),
    ]
}
