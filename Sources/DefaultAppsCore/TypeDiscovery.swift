/// Port over "what types and schemes do the apps on this Mac claim to handle".
/// Faked in tests; the real adapter is `InstalledAppScanner`.
public protocol TypeDiscovery: Sendable {
    func discover() -> DiscoveredTypes
}

public struct DiscoveredTypes: Equatable, Sendable {
    public let extensions: Set<String>
    public let schemes: Set<String>

    public init(extensions: Set<String> = [], schemes: Set<String> = []) {
        self.extensions = extensions
        self.schemes = schemes
    }
}

extension Catalog {
    public static let discoveredTypesFamily = "other types"
    public static let discoveredSchemesFamily = "other schemes"

    /// Curated families first, then whatever the scan found that they don't cover.
    public func extended(with discovered: DiscoveredTypes) -> Catalog {
        let curatedExtensions = Set(families.flatMap(\.extensions))
        let curatedSchemes = Set(families.flatMap(\.schemes))
        let newExtensions = discovered.extensions.subtracting(curatedExtensions).sorted()
        let newSchemes = discovered.schemes.subtracting(curatedSchemes).sorted()

        var extended = families
        if !newExtensions.isEmpty {
            extended.append(TypeFamily(name: Self.discoveredTypesFamily, extensions: newExtensions))
        }
        if !newSchemes.isEmpty {
            extended.append(TypeFamily(name: Self.discoveredSchemesFamily, schemes: newSchemes))
        }
        return Catalog(families: extended)
    }
}
