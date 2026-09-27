//
//  CommentKeywords.swift
//  CodeHighlighting
//
//  TODO-family markers surfaced inside comments (both highlight tiers tint them with the
//  keyword color — the agent's leftovers pop while scrolling).
//
//  Created by David Sherlock on 9/5/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import AppKit

/// TODO-family markers surfaced inside comments (both highlight tiers tint
/// them with the keyword colour, so leftovers stand out while scrolling).
/// Case-sensitive for the shouting forms; `@todo` is docblock-lowercase.
public enum CommentKeywords {
    /// Matches `TODO`, `FIXME`, `HACK`, `XXX` and `@todo` (any case) as whole words.
    public static let regex = try! NSRegularExpression(
        pattern: "\\b(?:TODO|FIXME|HACK|XXX)\\b|(?i:@todo)\\b")
}
