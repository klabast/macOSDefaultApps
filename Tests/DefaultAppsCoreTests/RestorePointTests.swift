import Foundation
import Testing
import DefaultAppsTestSupport
@testable import DefaultAppsCore

@Suite("restore point")
struct RestorePointTests {
    let safari = app("com.apple.Safari", "Safari")

    var registry: FakeRegistry {
        var registry = FakeRegistry()
        registry.typesByExtension["html"] = "public.html"
        registry.defaultByType["public.html"] = safari
        registry.appsByType["public.html"] = [safari]
        return registry
    }

    let catalog = Catalog(families: [
        TypeFamily(name: "web", extensions: ["html"])
    ])

    struct Dirs {
        let presets: PresetStore
        let restore: RestorePoint
    }

    func makeDirs(registry: any HandlerRegistry) -> Dirs {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "mda-tests-\(UUID().uuidString)")
        return Dirs(
            presets: PresetStore(directory: root.appending(path: "presets")),
            restore: RestorePoint(
                directory: root.appending(path: "state"), registry: registry))
    }

    @Test("captures the current defaults")
    func capture() throws {
        let dirs = makeDirs(registry: registry)

        #expect(try dirs.restore.captureIfMissing { catalog } == true)

        let expected = SnapshotService(registry: registry).build(from: catalog).settingsFileText()
        #expect(try dirs.restore.text() == expected)
    }

    @Test("never lands in the presets directory, where a dotfiles checkout would carry it away")
    func staysOutOfPresets() throws {
        let dirs = makeDirs(registry: registry)

        try dirs.restore.captureIfMissing { catalog }

        #expect(dirs.presets.list().isEmpty)
        #expect(dirs.restore.url.path.hasPrefix(dirs.presets.directory.path) == false)
    }

    @Test("never rewritten once it exists")
    func doesNotOverwrite() throws {
        let dirs = makeDirs(registry: registry)
        try dirs.restore.captureIfMissing { catalog }

        var mutated = registry
        mutated.defaultByType["public.html"] = app("org.mozilla.firefox", "Firefox")
        let second = RestorePoint(directory: dirs.restore.directory, registry: mutated)

        #expect(try second.captureIfMissing { catalog } == false)
        #expect(try second.text().contains("com.apple.Safari"))
    }

    @Test("enumerating types is skipped when the restore point already exists")
    func lazyCatalog() throws {
        let dirs = makeDirs(registry: registry)
        try dirs.restore.captureIfMissing { catalog }

        var built = 0
        try dirs.restore.captureIfMissing {
            built += 1
            return catalog
        }

        #expect(built == 0)
    }

    @Test("capturing from a snapshot the caller already built")
    func captureFromSnapshot() throws {
        let dirs = makeDirs(registry: registry)
        let snapshot = SnapshotService(registry: registry).build(from: catalog)

        #expect(try dirs.restore.captureIfMissing(from: snapshot) == true)
        #expect(try dirs.restore.text() == snapshot.settingsFileText())
        #expect(try dirs.restore.captureIfMissing(from: snapshot) == false)
    }

    @Test("reading before anything was captured says so")
    func notCaptured() {
        let dirs = makeDirs(registry: registry)

        #expect(dirs.restore.exists == false)
        #expect(throws: RestorePointError.notCaptured) {
            try dirs.restore.text()
        }
    }
}
