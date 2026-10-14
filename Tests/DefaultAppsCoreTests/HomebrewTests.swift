import Foundation
import Testing
@testable import DefaultAppsCore

@Suite("homebrew")
struct HomebrewTests {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "mda-homebrew-tests-\(UUID().uuidString)")

    @Test("an installed cask means brew owns updates")
    func caskInstalled() throws {
        try FileManager.default.createDirectory(
            at: root.appending(path: "Caskroom/macosdefaultapps/0.7.1"), withIntermediateDirectories: true)

        #expect(Homebrew.managesApp(prefixes: [root.appending(path: "missing"), root]))
    }

    @Test("no cask, or no homebrew at all, means nobody updates it for us")
    func noCask() throws {
        try FileManager.default.createDirectory(
            at: root.appending(path: "Caskroom/something-else"), withIntermediateDirectories: true)

        #expect(!Homebrew.managesApp(prefixes: [root]))
        #expect(!Homebrew.managesApp(prefixes: [root.appending(path: "missing")]))
    }
}
