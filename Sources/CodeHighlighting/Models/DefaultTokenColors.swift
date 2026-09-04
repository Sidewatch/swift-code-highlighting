//
//  DefaultTokenColors.swift
//  CodeHighlighting
//

import AppKit

/// A neutral fallback color provider, so highlighting is sensible before a theme
/// is installed.
public struct DefaultTokenColors: TokenColorProviding {
    /// Creates the neutral system-color provider.
    public init() {}

    /// A fixed system color per token role.
    public func color(for kind: TokenKind) -> NSColor {
        switch kind {
        case .comment:  return .systemGray
        case .string:   return .systemRed
        case .keyword:  return .systemPurple
        case .type:     return .systemTeal
        case .number:   return .systemOrange
        case .function: return .systemBlue
        case .attribute:return .systemTeal
        case .variable: return .labelColor
        case .property: return .systemIndigo
        case .added:    return .systemGreen
        case .removed:  return .systemRed
        }
    }
    /// The default text color (`labelColor`, so it tracks light/dark mode).
    public var foreground: NSColor { .labelColor }
}
