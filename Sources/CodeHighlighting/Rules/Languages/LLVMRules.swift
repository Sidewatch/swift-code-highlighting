//
//  LLVMRules.swift
//  CodeHighlighting
//
//  The regex rule table for LLVM IR.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// LLVM IR: `;` comments, `%locals`, `@globals`, `!metadata`, the integer and float types,
/// the instruction and linkage words, `c"…"` constants. Written 25 Sep 2026 (the sweep found it flat).
extension RuleTables {
    static let llvm: [(String, TokenKind)] = [
        (";.*$", .comment),
        ("c?\"(?:[^\"\\\\]|\\\\.)*\"", .string),
        ("%[\\w.]+", .variable),
        ("@[\\w.]+", .function),
        ("![\\w.]+", .property),
        ("\\b(i\\d+|void|half|bfloat|float|double|fp128|x86_fp80|ppc_fp128|ptr|label|token|metadata|x86_mmx|opaque)\\b", .type),
        ("\\[\\s*\\d+\\s+x\\b", .type),
        keywords(["define", "declare", "ret", "br", "switch", "indirectbr", "invoke", "resume", "unreachable", "call", "tail", "musttail", "icmp", "fcmp", "phi", "select", "add", "fadd", "sub", "fsub", "mul", "fmul", "udiv", "sdiv", "fdiv", "urem", "srem", "frem", "shl", "lshr", "ashr", "and", "or", "xor", "load", "store", "alloca", "getelementptr", "fence", "cmpxchg", "atomicrmw", "trunc", "zext", "sext", "fptrunc", "fpext", "fptoui", "fptosi", "uitofp", "sitofp", "ptrtoint", "inttoptr", "bitcast", "addrspacecast", "extractelement", "insertelement", "shufflevector", "extractvalue", "insertvalue", "landingpad", "global", "constant", "private", "internal", "external", "linkonce", "weak", "common", "appending", "unnamed_addr", "local_unnamed_addr", "align", "nsw", "nuw", "exact", "inbounds", "volatile", "target", "datalayout", "triple", "attributes", "source_filename", "eq", "ne", "ugt", "uge", "ult", "ule", "sgt", "sge", "slt", "sle", "oeq", "ogt", "oge", "olt", "ole", "one", "ord", "uno", "true", "false", "null", "undef", "poison", "zeroinitializer", "nocapture", "noalias", "readonly", "nounwind", "noinline", "alwaysinline", "dso_local", "type", "to"]),
        ("\\b-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b|\\b0x[0-9a-fA-F]+\\b", .number),
    ]
}
