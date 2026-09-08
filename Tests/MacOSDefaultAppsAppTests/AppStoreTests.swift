import DefaultAppsCore
import DefaultAppsTestSupport
import Foundation
import Testing
@testable import MacOSDefaultAppsApp

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
    func reload() throws {
        let store = makeStore(registry: registry)

        store.reload()

        let targets = store.snapshot.entries.map(\.target)
        #expect(targets.contains(.fileExtension("md")))
        #expect(targets.contains(.fileExtension("ipynb")))
        #expect(store.snapshot.entries.last?.family == Catalog.discoveredTypesFamily)
        #expect(store.hasRestorePoint)
        #expect(store.errorMessage == nil)
    }

    @Test("setting a handler writes through and refreshes the row")
    func setDefault() async throws {
        var registry = registry
        registry.defaultByType["net.daringfireball.markdown"] = textEdit
        let writer = FakeWriter()
        let store = makeStore(registry: registry, writer: writer)
        store.reload()

        await store.setDefault("com.apple.TextEdit", for: .fileExtension("md"))

        #expect(writer.typeCalls.map(\.bundleID) == ["com.apple.TextEdit"])
        #expect(store.busy.isEmpty)
        #expect(store.errorMessage == nil)
    }

    @Test("switching to by-app selects the first app")
    func modeSwitch() {
        let store = makeStore(registry: registry)
        store.reload()

        store.mode = .byApp

        #expect(store.selection == .app("com.apple.TextEdit"))
        #expect(store.selectedApp == textEdit)
    }

    @Test("a preset preview plans against the current defaults")
    func preview() throws {
        let store = makeStore(registry: registry)
        store.reload()
        try PresetStore(directory: locations.presets).save(
            "work", text: "com.apple.TextEdit  .md\ncom.not.installed  .md\n")
        store.reload()

        store.beginPreview(preset: "work")

        #expect(store.presetNames == ["work"])
        #expect(store.preview?.plan.map(\.action) == [.change(from: xcode, to: textEdit), .missingApp])
    }
}
