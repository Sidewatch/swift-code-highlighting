//
//  OutlineNode.swift
//  CodeHighlighting
//
//  A node in the outline tree: a symbol plus its nested children.
//
//  Created by David Sherlock on 9/5/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// A node in the outline tree: a symbol plus its nested children.
public final class OutlineNode {
    /// The definition or heading this node shows.
    public let symbol: Symbol
    /// The symbols nested inside this one's scope, in document order.
    public var children: [OutlineNode] = []
    /// A childless node for `symbol`.
    public init(_ symbol: Symbol) { self.symbol = symbol }
}
