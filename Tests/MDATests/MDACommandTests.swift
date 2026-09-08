import Foundation
import Testing

/// Anchors `Bundle(for:)` on the test bundle — under `swift test` the helper
/// process reports the toolchain as `Bundle.main`, so there is no other way
/// to find the products directory the binary was just built into.
private final class BundleAnchor {}

/// End-to-end runs of the built `mda` binary against throwaway directories.
/// Only non-mutating commands live here: they read the live LaunchServices
/// database but write nothing outside the temp dirs.
@Suite("mda command")
struct MDACommandTests {
    struct Run {
        let stdout: String
        let stderr: String
        let status: Int32
    }

    let presets: URL
    let state: URL

    init() {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "mda-e2e-\(UUID().uuidString)")
        presets = root.appending(path: "presets")
        state = root.appending(path: "state")
    }

    func mda(_ arguments: String...) throws -> Run {
        let binary = Bundle(for: BundleAnchor.self)
            .bundleURL.deletingLastPathComponent().appending(path: "mda")
        try #require(
            FileManager.default.isExecutableFile(atPath: binary.path),
            "no mda binary next to the test bundle at \(binary.path)")

        let process = Process()
        process.executableURL = binary
        process.arguments = arguments
        process.environment = [
            "MDA_PRESETS_DIR": presets.path,
            "MDA_STATE_DIR": state.path,
        ]
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Run(
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self),
            status: process.terminationStatus)
    }

    @Test("the first mutating command records the restore point, outside the presets dir")
    func firstRunCaptures() throws {
        let run = try mda("save")

        #expect(run.status == 0)
        #expect(run.stderr.contains("recorded"))
        #expect(FileManager.default.fileExists(atPath: state.appending(path: "initial").path))
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: presets.path) == ["default"],
            "'initial' must not be a preset")
    }

    @Test("a second run leaves the restore point alone")
    func secondRunKeepsIt() throws {
        _ = try mda("save")
        let captured = try String(contentsOf: state.appending(path: "initial"), encoding: .utf8)

        let run = try mda("save", "work")

        #expect(run.status == 0)
        #expect(run.stderr.contains("recorded") == false)
        #expect(
            try String(contentsOf: state.appending(path: "initial"), encoding: .utf8) == captured)
    }

    @Test("a preset cannot shadow the restore point")
    func reservedName() throws {
        let run = try mda("save", "initial")

        #expect(run.status == 1)
        #expect(run.stderr.contains("restore point"))
    }

    @Test("applying a restore point that was never captured explains itself")
    func applyWithoutCapture() throws {
        let run = try mda("apply", "initial")

        #expect(run.status == 1)
        #expect(run.stderr.lowercased().contains("no restore point"))
    }
}
