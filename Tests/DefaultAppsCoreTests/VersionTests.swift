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

    @Test("newer compares numerically, tolerates a v prefix, never trusts garbage")
    func newer() {
        #expect(Version.isNewer("0.6.2", than: "0.6.1"))
        #expect(Version.isNewer("v0.7.0", than: "0.6.1"))
        #expect(Version.isNewer("0.10.0", than: "0.9.9"))
        #expect(Version.isNewer("1.0.0", than: "0.99.99"))
        #expect(Version.isNewer("0.6.1", than: "0.6.1") == false)
        #expect(Version.isNewer("0.6.0", than: "0.6.1") == false)
        #expect(Version.isNewer("latest", than: "0.6.1") == false)
        #expect(Version.isNewer("", than: "0.6.1") == false)
    }
}
