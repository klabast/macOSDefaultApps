import Testing
import DefaultAppsTestSupport
@testable import DefaultAppsCore

@Suite("setting handlers")
struct SetServiceTests {
    let textEdit = app("com.apple.TextEdit", "TextEdit")

    func makeService(_ writer: FakeWriter) -> SetService {
        var registry = FakeRegistry()
        registry.appsByBundleID["com.apple.TextEdit"] = textEdit
        registry.typesByExtension["md"] = "net.daringfireball.markdown"
        return SetService(registry: registry, writer: writer)
    }

    @Test("extension resolves to its UTI before writing")
    func setForExtension() async throws {
        let writer = FakeWriter()

        let result = try await makeService(writer).setDefault(
            bundleID: "com.apple.TextEdit", for: .fileExtension("md"))

        #expect(result == textEdit)
        #expect(writer.typeCalls.count == 1)
        #expect(writer.typeCalls.first?.bundleID == "com.apple.TextEdit")
        #expect(writer.typeCalls.first?.uti == "net.daringfireball.markdown")
    }

    @Test("UTI is written directly")
    func setForContentType() async throws {
        let writer = FakeWriter()

        _ = try await makeService(writer).setDefault(
            bundleID: "com.apple.TextEdit", for: .contentType("public.html"))

        #expect(writer.typeCalls.first?.uti == "public.html")
    }

    @Test("scheme goes through the scheme path")
    func setForScheme() async throws {
        let writer = FakeWriter()

        _ = try await makeService(writer).setDefault(
            bundleID: "com.apple.TextEdit", for: .scheme("mailto"))

        #expect(writer.schemeCalls.first?.scheme == "mailto")
        #expect(writer.typeCalls.isEmpty)
    }

    @Test("unknown bundle id throws before anything is written")
    func unknownApp() async {
        let writer = FakeWriter()

        await #expect(throws: SetError.unknownApplication("com.not.installed")) {
            try await makeService(writer).setDefault(
                bundleID: "com.not.installed", for: .fileExtension("md"))
        }
        #expect(writer.typeCalls.isEmpty)
    }

    @Test("unknown extension throws before anything is written")
    func unknownExtension() async {
        let writer = FakeWriter()

        await #expect(throws: QueryError.unknownExtension("xyzzy")) {
            try await makeService(writer).setDefault(
                bundleID: "com.apple.TextEdit", for: .fileExtension("xyzzy"))
        }
        #expect(writer.typeCalls.isEmpty)
    }
}
