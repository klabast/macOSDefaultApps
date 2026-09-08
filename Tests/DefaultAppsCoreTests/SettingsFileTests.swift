import Testing
import DefaultAppsTestSupport
@testable import DefaultAppsCore

@Suite("settings file export")
struct SettingsFileTests {
    let sublime = app("com.sublimetext.4", "Sublime Text")
    let mail = app("com.apple.mail", "Mail")

    var snapshot: Snapshot {
        Snapshot(entries: [
            SnapshotEntry(
                family: "plain text", target: .fileExtension("md"),
                result: QueryResult(defaultApp: sublime, candidates: [sublime])),
            SnapshotEntry(
                family: "plain text", target: .fileExtension("weird"),
                result: QueryResult(defaultApp: nil, candidates: [])),
            SnapshotEntry(
                family: "url schemes", target: .scheme("mailto"),
                result: QueryResult(defaultApp: mail, candidates: [mail])),
        ])
    }

    @Test("round-trips through the apply parser, skipping entries without default")
    func roundTrip() throws {
        let spec = try ApplySpec.parse(snapshot.settingsFileText())

        #expect(spec.lines == [
            ApplyLine(bundleID: "com.sublimetext.4", target: .fileExtension("md")),
            ApplyLine(bundleID: "com.apple.mail", target: .scheme("mailto")),
        ])
    }

    @Test("groups by family and carries app names as comments")
    func readability() {
        let text = snapshot.settingsFileText()

        #expect(text.contains("# plain text"))
        #expect(text.contains("# url schemes"))
        #expect(text.contains("# Sublime Text"))
        #expect(text.contains(".md"))
        #expect(text.contains("mailto:"))
    }
}
