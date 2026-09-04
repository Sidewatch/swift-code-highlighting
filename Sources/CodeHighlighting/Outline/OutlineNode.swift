//
//  OutlineNode.swift
//  CodeHighlighting
//

import Foundation

/// A node in the outline tree: a symbol plus its nested children.
public final class OutlineNode {
    public let symbol: Symbol
    public var children: [OutlineNode] = []
    public init(_ symbol: Symbol) { self.symbol = symbol }
}
