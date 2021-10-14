import FigmaAPI
import FigmaExportCore
import Logging

public struct ColorResult {
    var colors: [Color]
    var gradients: [Gradient]
}

/// Loads colors and gradients from Figma
final class ColorsLoader {
    private let logger = Logger(label: "com.redmadrobot.figma-export.colors-loader")

    private let client: Client
    private let figmaParams: Params.Figma
    private let colorParams: Params.Common.Colors?

    init(client: Client, figmaParams: Params.Figma, colorParams: Params.Common.Colors?) {
        self.client = client
        self.figmaParams = figmaParams
        self.colorParams = colorParams
    }
    
    func load() throws -> (light: ColorResult, dark: ColorResult?) {
        if let useSingleFile = colorParams?.useSingleFile, useSingleFile {
            return try loadColorsFromSingleFile()
        } else {
            return try loadColorsFromLightAndDarkFile()
        }
    }

    private func loadColorsFromLightAndDarkFile() throws -> (light: ColorResult, dark: ColorResult?) {
        let lightColors = try loadColors(fileId: figmaParams.lightFileId)
        let darkColors = try figmaParams.darkFileId.map { try loadColors(fileId: $0) }
        return (lightColors, darkColors)
    }

    private func loadColorsFromSingleFile() throws -> (light: ColorResult, dark: ColorResult?) {
        let res = try loadColors(fileId: figmaParams.lightFileId)
        let darkSuffix = colorParams?.darkModeSuffix ?? "_dark"
        let colors = res.colors
        let lightColors = colors
            .filter { !$0.name.hasSuffix(darkSuffix) }
        let lightGradients = res.gradients
            .filter { !$0.name.hasSuffix(darkSuffix) }

        let darkColors = colors
            .filter { $0.name.hasSuffix(darkSuffix) }
            .map { color -> Color in
                var newColor = color
                newColor.name = String(color.name.dropLast(darkSuffix.count))
                return newColor
            }
        let darkGradients = res.gradients
            .filter { $0.name.hasSuffix(darkSuffix) }
            .map { gradient -> Gradient in 
                var newGradient = gradient
                newGradient.name = String(gradient.name.dropLast(darkSuffix.count))
                return newGradient
            }


        let lightRes = ColorResult(colors: lightColors, gradients: lightGradients)
        let darkRes = ColorResult(colors: darkColors, gradients: darkGradients)
        return (lightRes, darkRes)
    }
    
    private func loadColors(fileId: String) throws -> ColorResult {
        let styles = try loadStyles(fileId: fileId)
        
        guard !styles.isEmpty else {
            throw FigmaExportError.stylesNotFound
        }
        
        let nodes = try loadNodes(fileId: fileId, nodeIds: styles.map { $0.nodeId } )
        return nodesAndStylesToColors(nodes: nodes, styles: styles)
    }


    private func solidToColor(style: Style, solid: SolidPaint) -> [Color] {
        let alpha: Double = solid.opacity ?? solid.color.a
        let platform = Platform(rawValue: style.description)        
        return [Color(name: style.name, 
                        platform: platform,
                        red: solid.color.r, 
                        green: solid.color.g, 
                        blue: solid.color.b, alpha: alpha)]
    }

    private func gradientToColor(style: Style, gradient: GradientPaint) -> [Color] {
        return gradient.gradientStops.enumerated().map { (index, stop) in
            let platform = Platform(rawValue: style.description)
            let c = Color(name: "\(style.name)_\(index)",
                          platform: platform,
                          red: stop.color.r,
                          green: stop.color.g,
                          blue: stop.color.b,
                          alpha: stop.color.a)

            return c
        }
    }

    /// Соотносит массив Style и Node чтобы получит массив Color
    private func nodesAndStylesToColors(nodes: [NodeId: Node], styles: [Style]) -> ColorResult {

        var gradients = [Gradient]()

        let colors = styles.flatMap { style -> [Color] in
            guard let node = nodes[style.nodeId] else { return [] }
            guard let fill = node.document.fills.first else { return [] }
            let platform = Platform(rawValue: style.description)
            switch fill.type {
                case .solid:
                    guard let solid = fill.asSolid else { return [] }
                    return solidToColor(style: style, solid: solid)
                case .gradientLinear,
                 .gradientRadial:
                    guard let gradient = fill.asGradient else { return []}
                    let stops = gradient.gradientStops.enumerated().map { index, stop in 
                        return ("\(style.name)_\(index)", stop.position)
                    }
                    gradients.append(Gradient(
                        name: style.name,
                        platform: platform,
                        stops: stops))
                    return gradientToColor(style: style, gradient: gradient)
                default:
                    logger.info("color type: \(fill.type), style: \(style)")
                    return []
            }    
        }


        return ColorResult(
            colors: colors,
            gradients: gradients
        )
    }
    
    private func loadStyles(fileId: String) throws -> [Style] {
        let endpoint = StylesEndpoint(fileId: fileId)
        let styles = try client.request(endpoint)
        return styles.filter {
            $0.styleType == .fill && useStyle($0)
        }
    }
    
    private func useStyle(_ style: Style) -> Bool {
        guard !style.description.isEmpty else {
            return true // Цвет общий
        }
        return !style.description.contains("none")
    }
    
    private func loadNodes(fileId: String, nodeIds: [String]) throws -> [NodeId: Node] {
        let endpoint = NodesEndpoint(fileId: fileId, nodeIds: nodeIds)
        return try client.request(endpoint)
    }
}
