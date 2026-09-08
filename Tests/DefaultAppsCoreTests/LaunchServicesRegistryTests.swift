import Foundation
import Testing
@testable import DefaultAppsCore

/// Read-only integration tests against the live LaunchServices database.
/// Assertions are limited to facts true on any Mac (system apps, public UTIs).
@Suite("LaunchServices adapter (live system, read-only)")
struct LaunchServicesRegistryTests {
    let registry = LaunchServicesRegistry()

    @Test("txt resolves to public.plain-text")
    func knownExtension() {
        #expect(registry.typeIdentifier(forExtension: "txt") == "public.plain-text")
    }

    @Test("unknown extension yields a dynamic UTI, not nil")
    func unknownExtensionIsDynamic() throws {
        let uti = try #require(registry.typeIdentifier(forExtension: "zz-mda-not-a-real-ext"))
        #expect(uti.hasPrefix("dyn."))
    }

    @Test("plain text has TextEdit among its handlers")
    func plainTextHandlers() {
        let ids = registry.applications(forType: "public.plain-text").map(\.bundleID)
        #expect(ids.contains("com.apple.TextEdit"))
    }

    @Test("https has a default handler (some browser)")
    func httpsHasDefault() {
        #expect(registry.defaultApplication(forScheme: "https") != nil)
    }

    /// Writes a throwaway .app with a localized display name, as Finder reads it.
    private func fixture(displayName: String?) throws -> URL {
        let root = URL(filePath: NSTemporaryDirectory()).appending(path: "mda-name-\(UUID().uuidString)")
        let app = root.appending(path: "FindMy.app")
        let resources = app.appending(path: "Contents/Resources/en.lproj")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let info: [String: Any] = [
            "CFBundleIdentifier": "dev.klabast.fixture", "CFBundleName": "FindMy",
            "CFBundlePackageType": "APPL", "CFBundleDevelopmentRegion": "en",
        ]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: app.appending(path: "Contents/Info.plist"))
        if let displayName {
            try "CFBundleDisplayName = \"\(displayName)\";\n"
                .write(to: resources.appending(path: "InfoPlist.strings"), atomically: true, encoding: .utf8)
        }
        return app
    }

    @Test("an app is named the way finder names it, not after its file")
    func localizedName() throws {
        let localized = try fixture(displayName: "Find My")
        defer { try? FileManager.default.removeItem(at: localized.deletingLastPathComponent()) }
        let plain = try fixture(displayName: nil)
        defer { try? FileManager.default.removeItem(at: plain.deletingLastPathComponent()) }

        #expect(registry.appInfo(at: localized)?.name == "Find My")
        #expect(registry.appInfo(at: plain)?.name == "FindMy")
    }

    @Test("handlers carry bundle id, name, and an existing path")
    func appInfoShape() throws {
        let app = try #require(registry.defaultApplication(forScheme: "https"))
        #expect(!app.bundleID.isEmpty)
        #expect(!app.name.isEmpty)
        #expect(FileManager.default.fileExists(atPath: app.url.path))
    }
}
