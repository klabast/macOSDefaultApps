import DefaultAppsCore
import Foundation
import Testing
@testable import MacOSDefaultAppsApp

/// Keys are English literals, so a missing translation never breaks — it just
/// shows English in a German UI. This scans the sources and the tables in the
/// source tree so that can't slip through unnoticed.
@Suite("localization")
struct LocalizationTests {
    static let appSources = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Sources/MacOSDefaultAppsApp")

    struct Table {
        let language: String
        let strings: [String: String]
    }

    func tables() throws -> [Table] {
        let resources = Self.appSources.appending(path: "Resources")
        return try FileManager.default.contentsOfDirectory(atPath: resources.path)
            .filter { $0.hasSuffix(".lproj") }
            .sorted()
            .map { lproj in
                let url = resources.appending(path: "\(lproj)/Localizable.strings")
                let strings = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(lproj)")
                return Table(language: String(lproj.dropLast(".lproj".count)), strings: strings)
            }
    }

    func keysUsedInSources() throws -> Set<String> {
        let pattern = try Regex(#"\bt\("([^"]+)"\)"#)
        var keys: Set<String> = []
        for file in try FileManager.default.contentsOfDirectory(atPath: Self.appSources.path)
        where file.hasSuffix(".swift") {
            let source = try String(contentsOf: Self.appSources.appending(path: file), encoding: .utf8)
            for match in source.matches(of: pattern) {
                keys.insert(String(match.output[1].substring ?? ""))
            }
        }
        return keys
    }

    @Test("every ui string has a translation in every language")
    func uiStrings() throws {
        let keys = try keysUsedInSources()
        #expect(keys.count > 20)

        for table in try tables() where table.language != "en" {
            let missing = keys.filter { table.strings[$0] == nil }.sorted()
            #expect(missing.isEmpty, "\(table.language) is missing \(missing)")
        }
    }

    @Test("every family name has a display name in every language, english included")
    func familyNames() throws {
        let families = try Catalog.bundled().families.map(\.name)
            + [Catalog.discoveredTypesFamily, Catalog.discoveredSchemesFamily]

        for table in try tables() {
            let missing = families.filter { table.strings[$0] == nil }
            #expect(missing.isEmpty, "\(table.language) is missing \(missing)")
        }
    }

    @Test("all nine languages ship")
    func languages() throws {
        #expect(try tables().map(\.language) == ["de", "en", "es", "fr", "it", "nl", "pl", "pt", "zh-Hans"])
    }
}
