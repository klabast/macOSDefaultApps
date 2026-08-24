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

    @Test("handlers carry bundle id, name, and an existing path")
    func appInfoShape() throws {
        let app = try #require(registry.defaultApplication(forScheme: "https"))
        #expect(!app.bundleID.isEmpty)
        #expect(!app.name.isEmpty)
        #expect(FileManager.default.fileExists(atPath: app.url.path))
    }
}
