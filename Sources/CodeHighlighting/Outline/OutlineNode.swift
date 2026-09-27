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
    public let symbol: Symbol
    public var children: [OutlineNode] = []
    public init(_ symbol: Symbol) { self.symbol = symbol }
}
