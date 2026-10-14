import Foundation
import Testing
@testable import DefaultAppsCore

@Suite("homebrew")
struct HomebrewTests {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "mda-homebrew-tests-\(UUID().uuidString)")

    var installed: URL { root.appending(path: "Applications/macOSDefaultApps.app") }

    /// What `brew install --cask` leaves behind: a versioned symlink to the app it moved.
    func installCask(version: String = "0.7.1") throws {
        let versionDir = root.appending(path: "brew/Caskroom/macosdefaultapps/\(version)")
        try FileManager.default.createDirectory(at: versionDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: installed, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: versionDir.appending(path: "macOSDefaultApps.app"), withDestinationURL: installed)
    }

    @Test("the running app is the one the cask installed")
    func runningTheCask() throws {
        try installCask()

        #expect(Homebrew.managesApp(at: installed, prefixes: [root.appending(path: "missing"), root.appending(path: "brew")]))
    }

    @Test("a cask is installed, but this copy came from somewhere else")
    func runningAnotherCopy() throws {
        try installCask()

        #expect(!Homebrew.managesApp(at: root.appending(path: "Downloads/macOSDefaultApps.app"), prefixes: [root.appending(path: "brew")]))
        #expect(!Homebrew.managesApp(at: root.appending(path: ".build/debug"), prefixes: [root.appending(path: "brew")]))
    }

    @Test("no homebrew at all means nobody updates it for us")
    func noHomebrew() {
        #expect(!Homebrew.managesApp(at: installed, prefixes: [root.appending(path: "missing")]))
    }
}
