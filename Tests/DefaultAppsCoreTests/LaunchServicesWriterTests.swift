import Foundation
import Testing
@testable import DefaultAppsCore

/// MUTATES the live LaunchServices database — opt-in only.
/// Uses a throwaway extension nothing on a real machine cares about;
/// the association it leaves behind is inert.
@Suite(
    "LaunchServices writer (live system, MUTATING — opt-in)",
    .enabled(if: ProcessInfo.processInfo.environment["MDA_MUTATION_TESTS"] == "1"))
struct LaunchServicesWriterTests {
    @Test("round-trip: set TextEdit for a throwaway extension, read it back")
    func setAndReadBack() async throws {
        let registry = LaunchServicesRegistry()
        let target = QueryTarget.fileExtension("zz-mda-mutation-test")

        _ = try await SetService(registry: registry, writer: LaunchServicesWriter())
            .setDefault(bundleID: "com.apple.TextEdit", for: target)

        let result = try QueryService(registry: registry).query(target)
        #expect(result.defaultApp?.bundleID == "com.apple.TextEdit")
    }
}
