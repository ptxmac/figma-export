
public struct Gradient: Asset {
    public var name: String

    public let stops: [(String, Double)]

    public let platform: Platform?

    public init(name: String, platform: Platform? = nil, stops: [(String, Double)]) {
        self.name = name
        self.platform = platform
        self.stops = stops
    }

    // MARK: Hashable
    
    public static func == (lhs: Gradient, rhs: Gradient) -> Bool {
        return lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
}
