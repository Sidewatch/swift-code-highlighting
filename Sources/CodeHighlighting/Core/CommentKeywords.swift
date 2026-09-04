//
//  CommentKeywords.swift
//  CodeHighlighting
//

import AppKit

/// TODO-family markers surfaced inside comments (both highlight tiers tint
/// them with the keyword color — the agent's leftovers pop while scrolling).
/// Case-sensitive for the shouting forms; `@todo` is docblock-lowercase.
public enum CommentKeywords {
    public static let regex = try! NSRegularExpression(
        pattern: "\\b(?:TODO|FIXME|HACK|XXX)\\b|(?i:@todo)\\b")
}
