//
//  HighlightTheme.swift
//  SwiftCodeHighlighting
//
//  A process-wide color provider for highlighters whose color access happens in
//  static context (e.g. the tree-sitter engine's capture→color mapping and its
//  `attributedSnippet`). Set it once at startup; the provider is read live, so a
//  theme change just needs a re-highlight.
//
//  Created by David Sherlock on 7/9/26.
//

import AppKit

/// The shared color provider used by highlighters that color in static context.
///
/// Assign your theme's provider once at launch:
/// ```swift
/// HighlightTheme.colors = MyThemeColors()
/// ```
public enum HighlightTheme {
    /// The active color provider. Defaults to a neutral system-color set.
    ///
    /// `nonisolated(unsafe)` matches the contract stated above: installed once at launch,
    /// before any highlighting runs, and only read thereafter. It is not a lock, and a theme
    /// swapped mid-highlight would still be a race — assign it at start-up, as documented.
    public nonisolated(unsafe) static var colors: TokenColorProviding = DefaultTokenColors()
}

/// TODO-family markers surfaced inside comments (both highlight tiers tint
/// them with the keyword color — the agent's leftovers pop while scrolling).
/// Case-sensitive for the shouting forms; `@todo` is docblock-lowercase.
public enum CommentKeywords {
    public static let regex = try! NSRegularExpression(
        pattern: "\\b(?:TODO|FIXME|HACK|XXX)\\b|(?i:@todo)\\b")
}

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
