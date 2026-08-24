import Foundation
import Testing
@testable import DefaultAppsCore

@Suite("target parsing")
struct QueryTargetTests {
    @Test("bare word is a file extension")
    func bareWord() {
        #expect(QueryTarget.parse("md") == .fileExtension("md"))
    }

    @Test("leading dot is a file extension")
    func leadingDot() {
        #expect(QueryTarget.parse(".tar.gz") == .fileExtension("tar.gz"))
    }

    @Test("dotted identifier is a UTI")
    func dottedIsUTI() {
        #expect(QueryTarget.parse("public.html") == .contentType("public.html"))
    }

    @Test("trailing colon is a URL scheme")
    func trailingColon() {
        #expect(QueryTarget.parse("mailto:") == .scheme("mailto"))
    }

    @Test("scheme is lowercased, extension case preserved")
    func normalization() {
        #expect(QueryTarget.parse("MAILTO:") == .scheme("mailto"))
        #expect(QueryTarget.parse("MD") == .fileExtension("MD"))
    }

    @Test("displayString round-trips through parse")
    func displayRoundTrip() {
        let targets: [QueryTarget] = [.fileExtension("md"), .contentType("public.html"), .scheme("mailto")]
        for target in targets {
            #expect(QueryTarget.parse(target.displayString) == target)
        }
        #expect(QueryTarget.fileExtension("md").displayString == ".md")
    }

    @Test("codable round-trips all three kinds")
    func codableRoundTrip() throws {
        let targets: [QueryTarget] = [
            .fileExtension("md"), .contentType("public.html"), .scheme("mailto"),
        ]
        let decoded = try JSONDecoder().decode(
            [QueryTarget].self, from: JSONEncoder().encode(targets))
        #expect(decoded == targets)
    }

    @Test("empty and whitespace-only input is rejected")
    func emptyInput() {
        #expect(QueryTarget.parse("") == nil)
        #expect(QueryTarget.parse("   ") == nil)
        #expect(QueryTarget.parse(":") == nil)
        #expect(QueryTarget.parse(".") == nil)
    }
}
