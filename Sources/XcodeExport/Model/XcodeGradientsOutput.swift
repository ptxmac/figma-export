import Foundation

public struct XcodeGradientsOutput {
    public let assetsInMainBundle: Bool
    public let assetsInSwiftPackage: Bool
    public let swiftuiGradientSwiftURL: URL?
    public let groupUsingNamespace: Bool

    public init(
        assetsInMainBundle: Bool,
        assetsInSwiftPackage: Bool? = false,
        swiftuiGradientSwiftURL: URL? = nil,
        groupUsingNamespace: Bool? = nil

    ) {
        self.assetsInMainBundle = assetsInMainBundle
        self.assetsInSwiftPackage = assetsInSwiftPackage ?? false
        self.swiftuiGradientSwiftURL = swiftuiGradientSwiftURL
        self.groupUsingNamespace = groupUsingNamespace ?? false
    }
}