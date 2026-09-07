import Foundation
import Testing
@testable import DefaultAppsCore

@Suite("installed app scanner")
struct InstalledAppScannerTests {
    /// Writes a throwaway .app bundle carrying just an Info.plist.
    private func fixture(_ info: [String: Any], named name: String = "Fixture") throws -> URL {
        let root = URL(filePath: NSTemporaryDirectory())
            .appending(path: "mda-scan-\(UUID().uuidString)")
        let contents = root.appending(path: "\(name).app/Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: contents.appending(path: "Info.plist"))
        return root
    }

    @Test("reads document types, exported declarations and url schemes")
    func readsDeclarations() throws {
        // Given an app declaring types three different ways
        let root = try fixture([
            "CFBundleDocumentTypes": [["CFBundleTypeExtensions": ["Ipynb", ".TEX"]]],
            "UTExportedTypeDeclarations": [[
                "UTTypeIdentifier": "com.example.thing",
                "UTTypeTagSpecification": ["public.filename-extension": ["thing"]],
            ]],
            "CFBundleURLTypes": [["CFBundleURLSchemes": ["OtpAuth", "smb"]]],
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        // When
        let found = InstalledAppScanner(searchPaths: [root]).discover()

        // Then everything is lower-cased and dot-stripped
        #expect(found.extensions == ["ipynb", "tex", "thing"])
        #expect(found.schemes == ["otpauth", "smb"])
    }

    @Test("the wildcard extension is not a type")
    func ignoresWildcard() throws {
        // Given an app claiming it opens everything
        let root = try fixture(["CFBundleDocumentTypes": [["CFBundleTypeExtensions": ["*", "md"]]]])
        defer { try? FileManager.default.removeItem(at: root) }

        // When / Then
        #expect(InstalledAppScanner(searchPaths: [root]).discover().extensions == ["md"])
    }

    @Test("a path with no apps yields nothing rather than throwing")
    func emptyPath() {
        let missing = URL(filePath: "/nonexistent-mda-\(UUID().uuidString)")
        #expect(InstalledAppScanner(searchPaths: [missing]).discover() == DiscoveredTypes())
    }
}

/// Read-only integration test against the real /Applications on this machine.
@Suite("installed app scanner (live system, read-only)")
struct InstalledAppScannerLiveTests {
    @Test("finds far more than the curated catalog covers")
    func widerThanCatalog() throws {
        let catalog = try Catalog.bundled()
        let curated = Set(catalog.families.flatMap(\.extensions))

        let found = InstalledAppScanner().discover()

        #expect(found.extensions.count > curated.count * 5)
        #expect(found.schemes.contains("http"))
        #expect(found.schemes.contains("mailto"))
    }

    @Test("extending the bundled catalog adds families without losing the curated ones")
    func extendsCatalog() throws {
        let catalog = try Catalog.bundled()
        let extended = catalog.extended(with: InstalledAppScanner().discover())

        #expect(extended.families.count == catalog.families.count + 2)
        #expect(extended.families.prefix(catalog.families.count).map(\.name)
            == catalog.families.map(\.name))
    }
}
