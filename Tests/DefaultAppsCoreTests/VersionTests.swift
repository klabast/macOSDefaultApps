import Testing
@testable import DefaultAppsCore

@Suite("version")
struct VersionTests {
    @Test("is a semver triple of numbers")
    func semver() {
        // Given the shipped version string
        let parts = Version.current.split(separator: ".", omittingEmptySubsequences: false)

        // Then it parses as major.minor.patch — the release workflow compares it
        // against the git tag, so anything else fails the release, not the build
        #expect(parts.count == 3)
        #expect(parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) })
    }
}
