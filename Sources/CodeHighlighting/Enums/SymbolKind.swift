//
//  SymbolKind.swift
//  CodeHighlighting
//

import Foundation
import CodeLanguage

/// The kind of definition a ``Symbol`` represents. `class` maps to ``type``.
public enum SymbolKind: String, Sendable {
    case function, method, type, structure, enumeration, interface, module, property, constant, variable
    /// A Markdown (or other prose) section heading — not a code definition; used by
    /// the document-heading outline path.
    case heading
    /// A stylesheet rule — `.btn:hover`, ` (max-width: 782px)` — listed by the
    /// stylesheet outline; a selector is a location, not a definition, so it never
    /// enters the project symbol index.
    case selector

    /// Maps a tree-sitter capture name (from the symbol queries below) to a kind.
    public init?(capture: String) {
        switch capture {
        case "function":  self = .function
        case "method":    self = .method
        case "class":     self = .type
        case "struct":    self = .structure
        case "enum":      self = .enumeration
        case "interface": self = .interface
        case "module":    self = .module
        case "property":  self = .property
        case "constant":  self = .constant
        case "type":      self = .type
        case "variable":  self = .variable
        default:          return nil
        }
    }

    /// SF Symbol shown beside the entry in the outline / picker.
    public var iconName: String {
        switch self {
        case .function, .method:   return "function"
        case .type:                return "cube"
        case .structure:           return "cube.fill"
        case .enumeration:         return "list.number"
        case .interface:           return "square.on.square"
        case .module:              return "shippingbox"
        case .property, .variable: return "diamond"
        case .constant:            return "c.circle"
        case .heading:             return "number"
        case .selector:            return "paintbrush"
        }
    }

    /// Short label shown after the symbol name.
    public var label: String {
        switch self {
        case .type:        return "class"
        case .structure:   return "struct"
        case .enumeration: return "enum"
        case .heading:     return ""      // the name is the heading; no kind suffix
        case .selector:    return ""      // the name IS the selector
        default:           return rawValue
        }
    }
}
