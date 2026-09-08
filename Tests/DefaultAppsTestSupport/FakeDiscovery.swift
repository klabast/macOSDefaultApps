import DefaultAppsCore

public struct FakeDiscovery: TypeDiscovery {
    public var extensions: Set<String>
    public var schemes: Set<String>

    public init(extensions: Set<String> = [], schemes: Set<String> = []) {
        self.extensions = extensions
        self.schemes = schemes
    }

    public func discover() -> DiscoveredTypes {
        DiscoveredTypes(extensions: extensions, schemes: schemes)
    }
}
