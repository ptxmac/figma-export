import Foundation
import FigmaExportCore
import Logging

final public class XcodeGradientExporter {

    private let logger = Logger(label: "com.redmadrobot.figma-export.xcode-gradient-exporter")

    private let output: XcodeGradientsOutput

    public init(output: XcodeGradientsOutput) {
        self.output = output
    }

    public func export(gradientPairs: [AssetPair<Gradient>], colorPairs: [AssetPair<Color>]) -> [FileContents] {
        var files: [FileContents] = []
        // SwiftUI Gradient extension
        if let gradientSwiftURL = output.swiftuiGradientSwiftURL {

            // create map
            
            var mapping = [String: String]()
            for p in colorPairs {
                let c = p.light
                mapping[c.originalName] = c.name
            }

            let contents = prepareSwiftUIGradientDotSwiftContents(gradientPairs, mapping: mapping, groupUsingNamespace: output.groupUsingNamespace)
            let contentsData = contents.data(using: .utf8)!

            let fileURL = URL(string: gradientSwiftURL.lastPathComponent)!
            let directoryURL = gradientSwiftURL.deletingLastPathComponent()

            files.append(
                FileContents(
                    destination: Destination(directory: directoryURL, file: fileURL),
                    data: contentsData
                )
            )
        }

        return files
    }

    private func prepareSwiftUIGradientDotSwiftContents(_ gradientPairs: [AssetPair<Gradient>], mapping: [String:String], groupUsingNamespace: Bool) -> String {
        let strings = gradientPairs.map {gradientPair -> String in 
            //let bundle = output.assetsInMainBundle ? "" : ", bundle: BundleProvider.bundle"
            let stops = gradientPair.light.stops.map {stop -> String in
                let name = mapping[stop.0]!
                return ".init(color: .\(name), location: \(stop.1))"
             }
            return """
            static var \(gradientPair.light.name) = Gradient(stops: [\(stops.joined(separator: ", "))])
            """
        }
        return """
        \(header)

        import SwiftUI
        \(output.assetsInMainBundle ? "" : (output.assetsInSwiftPackage ? bundleProviderSwiftPackage : bundleProvider))
        public extension Gradient {
        \(strings.joined(separator: "\n"))
        }

        """
    }

}