import DefaultAppsTestSupport
import Foundation
import Testing
@testable import DefaultAppsCore

@Suite("update check")
struct UpdateCheckTests {
    @Test("a newer release is reported without its tag prefix")
    func newer() async throws {
        let check = UpdateCheck(feed: FakeReleaseFeed(tag: "v0.9.0"))

        #expect(try await check.newerVersion(than: "0.6.1") == "0.9.0")
    }

    @Test("the same or an older release is nothing to report")
    func upToDate() async throws {
        #expect(try await UpdateCheck(feed: FakeReleaseFeed(tag: "v0.6.1")).newerVersion(than: "0.6.1") == nil)
        #expect(try await UpdateCheck(feed: FakeReleaseFeed(tag: "v0.5.0")).newerVersion(than: "0.6.1") == nil)
    }

    @Test("a feed failure propagates; the caller decides how quiet to be")
    func failure() async {
        let check = UpdateCheck(feed: FakeReleaseFeed(tag: "", error: URLError(.notConnectedToInternet)))

        await #expect(throws: URLError.self) {
            try await check.newerVersion(than: "0.6.1")
        }
    }

    @Test("the github release payload yields its tag")
    func githubPayload() throws {
        let payload = Data(#"{"tag_name":"v0.6.1","html_url":"https://github.com/klabast/macOSDefaultApps/releases/tag/v0.6.1","name":"v0.6.1"}"#.utf8)

        #expect(try GitHubReleases.tag(in: payload) == "v0.6.1")
        #expect(throws: (any Error).self) { try GitHubReleases.tag(in: Data("{}".utf8)) }
    }

    @Test("the release page is a constant, valid url")
    func releasePage() {
        #expect(GitHubReleases.page?.absoluteString == "https://github.com/klabast/macOSDefaultApps/releases/latest")
    }
}
