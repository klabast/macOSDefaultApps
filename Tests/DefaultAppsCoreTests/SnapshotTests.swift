import Testing
import DefaultAppsTestSupport
@testable import DefaultAppsCore

@Suite("snapshot")
struct SnapshotTests {
    let xcode = app("com.apple.dt.Xcode", "Xcode")
    let mail = app("com.apple.mail", "Mail")

    var registry: FakeRegistry {
        var registry = FakeRegistry()
        registry.typesByExtension["md"] = "net.daringfireball.markdown"
        registry.defaultByType["net.daringfireball.markdown"] = xcode
        registry.appsByType["net.daringfireball.markdown"] = [xcode]
        registry.defaultByScheme["mailto"] = mail
        registry.appsByScheme["mailto"] = [mail]
        return registry
    }

    let catalog = Catalog(families: [
        TypeFamily(name: "plain text", extensions: ["md"], utis: [], schemes: []),
        TypeFamily(name: "url schemes", extensions: [], utis: [], schemes: ["mailto"]),
    ])

    @Test("one entry per catalog target, in catalog order, with resolved handlers")
    func build() {
        let snapshot = SnapshotService(registry: registry).build(from: catalog)

        #expect(snapshot.entries == [
            SnapshotEntry(
                family: "plain text", target: .fileExtension("md"),
                result: QueryResult(defaultApp: xcode, candidates: [xcode])),
            SnapshotEntry(
                family: "url schemes", target: .scheme("mailto"),
                result: QueryResult(defaultApp: mail, candidates: [mail])),
        ])
    }

    var snapshot: Snapshot {
        SnapshotService(registry: registry).build(from: catalog)
    }

    @Test("filter matches family, target, and handler names case-insensitively")
    func filter() {
        #expect(snapshot.filtered("XCO").entries.map(\.target) == [.fileExtension("md")])
        #expect(snapshot.filtered(".md").entries.map(\.target) == [.fileExtension("md")])
        #expect(snapshot.filtered("schemes").entries.map(\.target) == [.scheme("mailto")])
        #expect(snapshot.filtered("com.apple.mail").entries.map(\.target) == [.scheme("mailto")])
        #expect(snapshot.filtered("nothing-matches").entries.isEmpty)
        #expect(snapshot.filtered("  ") == snapshot)
    }

    @Test("apps are unique across entries and sorted by name")
    func apps() {
        #expect(snapshot.apps() == [mail, xcode])
    }

    @Test("by-app view lists entries the app can handle")
    func byApp() {
        #expect(snapshot.entries(handledBy: "com.apple.mail").map(\.target) == [.scheme("mailto")])
        #expect(snapshot.entries(handledBy: "com.not.there").isEmpty)
    }

    @Test("grouping by family keeps first-appearance order within and across groups")
    func groupedByFamily() {
        let entries = [
            SnapshotEntry(family: "b", target: .fileExtension("1"), result: QueryResult(defaultApp: nil, candidates: [])),
            SnapshotEntry(family: "a", target: .fileExtension("2"), result: QueryResult(defaultApp: nil, candidates: [])),
            SnapshotEntry(family: "b", target: .fileExtension("3"), result: QueryResult(defaultApp: nil, candidates: [])),
        ]

        let groups = entries.groupedByFamily()

        #expect(groups.map(\.name) == ["b", "a"])
        #expect(groups.map { $0.entries.map(\.target) } == [[.fileExtension("1"), .fileExtension("3")], [.fileExtension("2")]])
        #expect([SnapshotEntry]().groupedByFamily().isEmpty)
    }

    @Test("restricting to a catalog drops the families it does not declare")
    func restricted() {
        let extended = SnapshotService(registry: registry).build(
            from: catalog.extended(with: DiscoveredTypes(extensions: ["ipynb"], schemes: ["smb"])))

        let curated = extended.restricted(to: catalog)

        #expect(curated == snapshot)
        #expect(extended.entries.count == snapshot.entries.count + 2)
    }

    @Test("unresolvable extension yields an empty entry, not a missing row")
    func unresolvable() {
        let catalog = Catalog(families: [
            TypeFamily(name: "exotic", extensions: ["nope"], utis: [], schemes: [])
        ])

        let snapshot = SnapshotService(registry: FakeRegistry()).build(from: catalog)

        #expect(snapshot.entries == [
            SnapshotEntry(
                family: "exotic", target: .fileExtension("nope"),
                result: QueryResult(defaultApp: nil, candidates: []))
        ])
    }
}
