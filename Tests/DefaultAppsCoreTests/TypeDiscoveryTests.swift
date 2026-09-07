import Foundation
import Testing
@testable import DefaultAppsCore

struct FakeDiscovery: TypeDiscovery {
    var extensions: Set<String> = []
    var schemes: Set<String> = []
    func discover() -> DiscoveredTypes {
        DiscoveredTypes(extensions: extensions, schemes: schemes)
    }
}

@Suite("catalog extended by discovery")
struct TypeDiscoveryTests {
    let curated = Catalog(families: [
        TypeFamily(name: "plain text", extensions: ["txt", "md"]),
        TypeFamily(name: "url schemes", schemes: ["mailto"]),
    ])

    @Test("discovered entries the catalog already covers are not repeated")
    func noDuplicates() {
        // Given a scan that finds one new extension and two already curated
        let found = DiscoveredTypes(extensions: ["txt", "md", "ipynb"], schemes: ["mailto"])

        // When
        let extended = curated.extended(with: found)

        // Then only the genuinely new extension shows up, and no scheme family is added
        #expect(extended.families.map(\.name)
            == ["plain text", "url schemes", Catalog.discoveredTypesFamily])
        #expect(extended.families.last?.extensions == ["ipynb"])
    }

    @Test("new extensions and schemes each get their own family, sorted")
    func bothKinds() {
        // Given
        let found = DiscoveredTypes(extensions: ["tex", "ipynb"], schemes: ["smb", "otpauth"])

        // When
        let extended = curated.extended(with: found)

        // Then
        let extra = extended.families.suffix(2)
        #expect(extra.map(\.name)
            == [Catalog.discoveredTypesFamily, Catalog.discoveredSchemesFamily])
        #expect(extra.first?.extensions == ["ipynb", "tex"])
        #expect(extra.last?.schemes == ["otpauth", "smb"])
    }

    @Test("a scan that finds nothing new leaves the catalog untouched")
    func nothingNew() {
        // Given
        let found = DiscoveredTypes(extensions: ["txt"], schemes: ["mailto"])

        // When / Then
        #expect(curated.extended(with: found) == curated)
    }
}
