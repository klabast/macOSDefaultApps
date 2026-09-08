import Testing
@testable import DefaultAppsCore

@Suite("apply settings parsing")
struct ApplySpecTests {
    @Test("duti-style three-field lines: bundle, uti, role (role ignored)")
    func dutiThreeFields() throws {
        let spec = try ApplySpec.parse("com.apple.Safari  public.html  all")

        #expect(spec.lines == [
            ApplyLine(bundleID: "com.apple.Safari", target: .contentType("public.html"))
        ])
    }

    @Test("duti-style two-field lines are scheme assignments")
    func dutiTwoFieldsIsScheme() throws {
        let spec = try ApplySpec.parse("com.apple.Finder  ftp")

        #expect(spec.lines == [
            ApplyLine(bundleID: "com.apple.Finder", target: .scheme("ftp"))
        ])
    }

    @Test("two-field lines with our explicit forms keep their meaning")
    func explicitTargets() throws {
        let spec = try ApplySpec.parse("""
            com.apple.TextEdit  .md
            com.apple.Mail      mailto:
            """)

        #expect(spec.lines == [
            ApplyLine(bundleID: "com.apple.TextEdit", target: .fileExtension("md")),
            ApplyLine(bundleID: "com.apple.Mail", target: .scheme("mailto")),
        ])
    }

    @Test("comments and blank lines are skipped, inline comments stripped")
    func commentsAndBlanks() throws {
        let spec = try ApplySpec.parse("""
            # full-line comment

            com.apple.Safari  public.html  all   # inline comment
            """)

        #expect(spec.lines.count == 1)
    }

    @Test("crlf line endings parse like lf")
    func crlf() throws {
        let spec = try ApplySpec.parse(
            "com.apple.Safari  public.html  all\r\n\r\n# comment\r\ncom.apple.Finder  ftp\r\n")

        #expect(spec.lines == [
            ApplyLine(bundleID: "com.apple.Safari", target: .contentType("public.html")),
            ApplyLine(bundleID: "com.apple.Finder", target: .scheme("ftp")),
        ])
    }

    @Test("unknown role and wrong field counts are rejected with the line number")
    func badLines() {
        #expect(throws: ApplyParseError.badLine(number: 2, content: "com.apple.Safari public.html sometimes")) {
            try ApplySpec.parse("\ncom.apple.Safari public.html sometimes")
        }
        #expect(throws: ApplyParseError.badLine(number: 1, content: "just-one-field")) {
            try ApplySpec.parse("just-one-field")
        }
    }
}
