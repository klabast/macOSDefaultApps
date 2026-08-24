import Testing
@testable import DefaultAppsCore

/// Guards the shipped catalog.json: it must decode, stay duplicate-free,
/// and its classic extensions must map to the well-known system UTIs
/// (stable on every Mac — catches typos like "jepg").
@Suite("bundled catalog")
struct BundledCatalogTests {
    @Test("decodes and is non-trivial")
    func loads() throws {
        let catalog = try Catalog.bundled()
        #expect(catalog.families.count >= 5)
        #expect(catalog.families.allSatisfy { !$0.targets.isEmpty })
    }

    @Test("no target appears twice across families")
    func noDuplicates() throws {
        let targets = try Catalog.bundled().families.flatMap(\.targets)
        var seen: Set<String> = []
        for target in targets {
            #expect(seen.insert(target.displayString).inserted, "duplicate: \(target.displayString)")
        }
    }

    @Test("classic extensions resolve to their well-known system UTIs")
    func classicUTIs() {
        let registry = LaunchServicesRegistry()
        let expected: [String: String] = [
            "txt": "public.plain-text",
            "html": "public.html",
            "png": "public.png",
            "jpeg": "public.jpeg",
            "mp3": "public.mp3",
            "zip": "public.zip-archive",
            "pdf": "com.adobe.pdf",
        ]
        for (ext, uti) in expected {
            #expect(registry.typeIdentifier(forExtension: ext) == uti)
        }
    }
}
