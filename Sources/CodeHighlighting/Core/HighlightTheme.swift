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
