import DefaultAppsCore
import DefaultAppsTestSupport
import Foundation
import Testing
@testable import MacOSDefaultAppsApp

final class ThreadRecordingDiscovery: TypeDiscovery, @unchecked Sendable {
    private(set) var ranOnMainThread: Bool?

    func discover() -> DiscoveredTypes {
        ranOnMainThread = Thread.isMainThread
        return DiscoveredTypes()
    }
}

/// First scan blocks until released and reports "old"; later scans report "new" at once.
final class GatedDiscovery: TypeDiscovery, @unchecked Sendable {
    let releaseFirst = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var calls = 0

    var started: Int {
        lock.withLock { calls }
    }

    func discover() -> DiscoveredTypes {
        let call = lock.withLock {
            calls += 1
            return calls
        }
        guard call == 1 else { return DiscoveredTypes(extensions: ["new"]) }
        releaseFirst.wait()
        return DiscoveredTypes(extensions: ["old"])
    }
}

@Suite("app store")
@MainActor
struct AppStoreTests {
    let xcode = app("com.apple.dt.Xcode", "Xcode")
    let textEdit = app("com.apple.TextEdit", "TextEdit")
    let locations: Locations

    init() {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "mda-app-tests-\(UUID().uuidString)")
        locations = Locations(
            presets: root.appending(path: "presets"), state: root.appending(path: "state"))
    }

    /// md is in the bundled catalog, ipynb is not; both open in Xcode.
    var registry: FakeRegistry {
        var registry = FakeRegistry()
        registry.typesByExtension["md"] = "net.daringfireball.markdown"
        registry.typesByExtension["ipynb"] = "dyn.ipynb"
        registry.defaultByType["net.daringfireball.markdown"] = xcode
        registry.defaultByType["dyn.ipynb"] = xcode
        registry.appsByType["net.daringfireball.markdown"] = [xcode, textEdit]
        registry.appsByType["dyn.ipynb"] = [xcode]
        registry.appsByBundleID["com.apple.dt.Xcode"] = xcode
        registry.appsByBundleID["com.apple.TextEdit"] = textEdit
        return registry
    }

    func makeStore(
        registry: any HandlerRegistry, discovery: any TypeDiscovery = FakeDiscovery(extensions: ["ipynb"]),
        writer: FakeWriter = FakeWriter()
    ) -> AppStore {
        AppStore(registry: registry, discovery: discovery, writer: writer, locations: locations)
    }

    @Test("reload joins the bundled catalog with discovered types and records the restore point")
    func reload() async throws {
        let store = makeStore(registry: registry)

        await store.reload()

        let targets = store.snapshot.entries.map(\.target)
        #expect(targets.contains(.fileExtension("md")))
        #expect(targets.contains(.fileExtension("ipynb")))
        #expect(store.snapshot.entries.last?.family == Catalog.discoveredTypesFamily)
        #expect(store.hasRestorePoint)
        #expect(store.errorMessage == nil)
    }

    @Test("the scan and the snapshot are built off the main thread")
    func reloadOffMain() async {
        let discovery = ThreadRecordingDiscovery()
        let store = makeStore(registry: registry, discovery: discovery)

        await store.reload()

        #expect(discovery.ranOnMainThread == false)
        #expect(store.snapshot.entries.contains { $0.target == .fileExtension("md") })
    }

    @Test("a reload that finishes late does not overwrite a newer one")
    func staleReloadIsDiscarded() async {
        var registry = registry
        registry.typesByExtension["old"] = "dyn.old"
        registry.typesByExtension["new"] = "dyn.new"
        let discovery = GatedDiscovery()
        let store = makeStore(registry: registry, discovery: discovery)

        let first = Task { await store.reload() }
        while discovery.started < 1 { await Task.yield() }
        await store.reload()
        #expect(store.snapshot.entries.map(\.target).contains(.fileExtension("new")))

        discovery.releaseFirst.signal()
        await first.value

        let targets = store.snapshot.entries.map(\.target)
        #expect(targets.contains(.fileExtension("new")))
        #expect(targets.contains(.fileExtension("old")) == false)
        #expect(store.loading == false)
    }

    @Test("setting a handler writes through and refreshes the row")
    func setDefault() async throws {
        var registry = registry
        registry.defaultByType["net.daringfireball.markdown"] = textEdit
        let writer = FakeWriter()
        let store = makeStore(registry: registry, writer: writer)
        await store.reload()

        await store.setDefault("com.apple.TextEdit", for: .fileExtension("md"))

        #expect(writer.typeCalls.map(\.bundleID) == ["com.apple.TextEdit"])
        #expect(store.busy.isEmpty)
        #expect(store.errorMessage == nil)
    }

    @Test("switching to by-app selects the first app")
    func modeSwitch() async {
        let store = makeStore(registry: registry)
        await store.reload()

        store.mode = .byApp

        #expect(store.selection == .app("com.apple.TextEdit"))
        #expect(store.selectedApp == textEdit)
    }

    @Test("saving a preset writes the curated catalog only, like mda save")
    func savesCurated() async throws {
        let store = makeStore(registry: registry)
        await store.reload()
        store.presetName = "work"

        store.savePreset()

        let saved = try PresetStore(directory: locations.presets).read("work")
        #expect(try ApplySpec.parse(saved).lines.map(\.target) == [.fileExtension("md")])
        #expect(store.savePresetSheet == false)
        #expect(store.presetNames == ["work"])
    }

    @Test("a preset preview plans against the current defaults")
    func preview() async throws {
        let store = makeStore(registry: registry)
        await store.reload()
        try PresetStore(directory: locations.presets).save(
            "work", text: "com.apple.TextEdit  .md\ncom.not.installed  .md\n")
        await store.reload()

        store.beginPreview(preset: "work")

        #expect(store.presetNames == ["work"])
        #expect(store.preview?.plan.map(\.action) == [.change(from: xcode, to: textEdit), .missingApp])
    }
}
