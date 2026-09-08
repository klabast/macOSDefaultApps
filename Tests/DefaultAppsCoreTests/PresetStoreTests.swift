import Foundation
import Testing
@testable import DefaultAppsCore

@Suite("preset store")
struct PresetStoreTests {
    func makeStore() -> PresetStore {
        PresetStore(
            directory: FileManager.default.temporaryDirectory
                .appending(path: "mda-tests-\(UUID().uuidString)/store"))
    }

    @Test("save creates the directory, read round-trips, list is sorted")
    func saveReadList() throws {
        let store = makeStore()

        try store.save("work", text: "com.apple.Safari  public.html  all\n")
        try store.save("default", text: "# empty\n")

        #expect(try store.read("work") == "com.apple.Safari  public.html  all\n")
        #expect(store.list() == ["default", "work"])
    }

    @Test("names with path tricks are rejected")
    func badNames() {
        let store = makeStore()

        for name in ["a/b", "../up", ".hidden", "", "a b"] {
            #expect(throws: PresetError.invalidName(name)) {
                try store.save(name, text: "x")
            }
        }
    }

    @Test("the restore point cannot be overwritten through save")
    func reservedName() throws {
        let store = makeStore()

        #expect(throws: PresetError.reserved("initial")) {
            try store.save("initial", text: "x")
        }
        #expect(store.list().contains("initial") == false)
    }

    @Test("reading a missing preset names it")
    func missing() {
        #expect(throws: PresetError.notFound("nope")) {
            try makeStore().read("nope")
        }
    }

    @Test("versioned only when a .git exists in the directory chain")
    func gitDetection() throws {
        let store = makeStore()
        try store.save("x", text: "y")
        #expect(store.isVersioned == false)

        try FileManager.default.createDirectory(
            at: store.directory.appending(path: ".git"), withIntermediateDirectories: true)
        #expect(store.isVersioned == true)

        let nested = PresetStore(directory: store.directory.appending(path: "sub/dir"))
        #expect(nested.isVersioned == true)
    }
}
