//
//  Node.swift
//  FigmaColorExporter
//
//  Created by Daniil Subbotin on 28.03.2020.
//  Copyright © 2020 Daniil Subbotin. All rights reserved.
//

public typealias NodeId = String

public struct NodesResponse: Decodable {
    public let nodes: [NodeId: Node]
}

public struct Node: Decodable {
    public let document: Document
}

public enum LineHeightUnit: String, Decodable {
    case pixels = "PIXELS"
    case fontSize = "FONT_SIZE_%"
    case intrinsic = "INTRINSIC_%"
}

public struct TypeStyle: Decodable {
    public var fontPostScriptName: String
    public var fontWeight: Double
    public var fontSize: Double
    public var lineHeightPx: Double
    public var letterSpacing: Double
    public var lineHeightUnit: LineHeightUnit
    public var textCase: TextCase?
}

public enum TextCase: String, Decodable {
    case original = "ORIGINAL"
    case upper = "UPPER"
    case lower = "LOWER"
    case title = "TITLE"
    case smallCaps = "SMALL_CAPS"
    case smallCapsForced = "SMALL_CAPS_FORCED"
}

public struct Document: Decodable {
    public let id: String
    public let name: String
    public let fills: [Paint]
    public let style: TypeStyle?
}

// https://www.figma.com/plugin-docs/api/Paint/
public struct Paint: Decodable {
    public let type: PaintType
    public let opacity: Double?
    public let color: PaintColor?
    public let gradientStops: [ColorStop]?

    public var asSolid: SolidPaint? {
        return SolidPaint(self)
    }

    public var asGradient: GradientPaint? {
        return GradientPaint(self)
    }
}

public enum PaintType: String, Decodable {
    case solid = "SOLID"
    case image = "IMAGE"
    case rectangle = "RECTANGLE"
    case gradientLinear = "GRADIENT_LINEAR"
    case gradientRadial = "GRADIENT_RADIAL"
    case gradientAngular = "GRADIENT_ANGULAR"
    case gradientDiamond = "GRADIENT_DIAMOND"
}

public struct SolidPaint: Decodable {
    public let opacity: Double?
    public let color: PaintColor

    public init?(_ paint: Paint) {
        guard paint.type == .solid else { return nil }
        guard let color = paint.color else { return nil }
        self.opacity = paint.opacity
        self.color = color
    }
}

public struct GradientPaint: Decodable {
    public let gradientStops: [ColorStop]

    public init?(_ paint: Paint) {
        switch paint.type {
            case .gradientLinear:
                guard let stops = paint.gradientStops else {  return nil }
                self.gradientStops = stops
            default:
                return nil
        }
    }
}

public struct PaintColor: Decodable {
    /// Channel value, between 0 and 1
    public let r, g, b, a: Double
}

public struct ColorStop: Decodable {
    public let position: Double
    public let color: PaintColor
}