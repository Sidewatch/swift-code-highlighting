//
//  ReceiverInference.swift
//  SwiftCodeHighlighting
//
//  Language-server-free receiver typing for go-to-definition: pure text reads
//  that answer "which class does `$obj` in `$obj->method()` hold?" often enough
//  to be useful, and answer nothing at all otherwise. Every function here is a
//  pure function of its inputs so the whole tier is unit-testable — the caller
//  treats a nil as "no idea, keep the full candidate list", which is what makes
//  the feature safe to ship partially: inference can only ever narrow, never
//  redirect.
//
//  Created by David Sherlock on 8/26/26.
//

import Foundation

/// Receiver-type inference for member-access go-to-definition.
public enum ReceiverInference {

    /// The receiver token immediately left of a member access whose member starts
    /// at `wordStart` — `"$obj"` for `$obj->m()`, `"this"` for `this.m()`,
    /// `"Limits"` for `Limits::M`. Nil when the word isn't a member access.
    public static func receiver(before wordStart: Int, in text: NSString) -> String? {
        var i = wordStart - 1
        // Step over the access operator.
        if i >= 1 {
            let two = text.substring(with: NSRange(location: i - 1, length: 2))
            if two == "->" || two == "::" { i -= 2 } else if text.character(at: i) == dot { i -= 1 } else { return nil }
        } else if i >= 0, text.character(at: i) == dot {
            i -= 1
        } else {
            return nil
        }
        // Read the identifier backwards ($ and _ included).
        let end = i
        while i >= 0, isWordChar(text.character(at: i)) { i -= 1 }
        guard end > i else { return nil }
        return text.substring(with: NSRange(location: i + 1, length: end - i))
    }

    /// The self-reference spellings across the supported languages. None of these
    /// is a plausible class name, so the check is safe without knowing the language.
    public static func isSelfReference(_ token: String) -> Bool {
        ["$this", "this", "self", "cls", "static"].contains(token)
    }

    /// A class name bound to `variable`, read straight off the text. Covers the
    /// shapes that carry a type in PHP and JS/TS (which Java/C#/Swift happen to
    /// share): `$v = new X`, `v = new X(`, `X $v` (typed param/property/@var),
    /// `v: X` (annotation). The nearest binding BEFORE `position` wins — that's
    /// the one in scope — falling back to the first one after (a property typed
    /// below its first use). The class must start uppercase (or `\`), which is
    /// what rejects `return $v` and `v: string`. Returns the bare final segment
    /// (`\Foo\Bar\Signer` → `Signer`), matching how the symbol index stores names.
    public static func inferredType(of variable: String, near position: Int, in text: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: variable)
        // Each pattern captures the class name in group 1.
        let patterns = [
            "\(escaped)\\s*=\\s*new\\s+(\\\\?[A-Z][A-Za-z0-9_\\\\.]*)",   // $v = new X / v = new X
            "\(escaped)\\s*:\\s*(\\\\?[A-Z][A-Za-z0-9_\\\\.]*)",          // v: X
            "(\\\\?[A-Z][A-Za-z0-9_\\\\.]*)\\s+\(escaped)\\b",            // X $v  (typed param / property / @var)
        ]
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        var best: (location: Int, name: String)?
        for p in patterns {
            guard let re = try? NSRegularExpression(pattern: p) else { continue }
            re.enumerateMatches(in: text, range: full) { m, _, _ in
                guard let m, m.numberOfRanges > 1 else { return }
                let name = ns.substring(with: m.range(at: 1))
                let loc = m.range.location
                if isBetter(loc, than: best?.location, position: position) {
                    best = (loc, name)
                }
            }
        }
        guard let best else { return nil }
        return bareName(best.name)
    }

    /// Nearest-before-`position` beats anything after; among two on the same side,
    /// closer to `position` wins.
    private static func isBetter(_ loc: Int, than current: Int?, position: Int) -> Bool {
        guard let current else { return true }
        let locBefore = loc <= position, curBefore = current <= position
        if locBefore != curBefore { return locBefore }
        return locBefore ? loc > current : loc < current
    }

    /// `\Foo\Bar\Signer` / `pkg.Signer` → `Signer`, matching the index's bare names.
    public static func bareName(_ qualified: String) -> String {
        qualified.split(whereSeparator: { $0 == "\\" || $0 == "." }).last.map(String.init) ?? qualified
    }

    /// A capitalized bare identifier — the shape of a static/class receiver
    /// (`Limits::MAX_BATCH`, `Signer.shared`), as opposed to a variable.
    public static func looksLikeTypeName(_ token: String) -> Bool {
        guard let first = token.unicodeScalars.first else { return false }
        return first.properties.isUppercase && !token.contains("$")
    }

    private static let dot = UInt16(UnicodeScalar(".").value)

    private static func isWordChar(_ u: unichar) -> Bool {
        guard let s = Unicode.Scalar(u) else { return false }
        return CharacterSet.alphanumerics.contains(s) || s == "_" || s == "$"
    }
}
