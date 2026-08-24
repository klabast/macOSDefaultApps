import Testing
@testable import DefaultAppsCore

@Suite("querying handlers")
struct QueryServiceTests {
    let textEdit = app("com.apple.TextEdit", "TextEdit")
    let xcode = app("com.apple.dt.Xcode", "Xcode")
    let mail = app("com.apple.mail", "Mail")

    @Test("file extension resolves to its UTI's default handler and candidates")
    func handlerForExtension() throws {
        var registry = FakeRegistry()
        registry.typesByExtension["md"] = "net.daringfireball.markdown"
        registry.defaultByType["net.daringfireball.markdown"] = xcode
        registry.appsByType["net.daringfireball.markdown"] = [textEdit, xcode]

        let result = try QueryService(registry: registry).query(.fileExtension("md"))

        #expect(result.defaultApp == xcode)
        #expect(result.candidates == [textEdit, xcode])
    }

    @Test("unknown extension throws instead of returning an empty result")
    func unknownExtension() {
        let service = QueryService(registry: FakeRegistry())

        #expect(throws: QueryError.unknownExtension("xyzzy")) {
            try service.query(.fileExtension("xyzzy"))
        }
    }

    @Test("UTI is queried directly, without extension resolution")
    func handlerForContentType() throws {
        var registry = FakeRegistry()
        registry.defaultByType["public.html"] = textEdit
        registry.appsByType["public.html"] = [textEdit]

        let result = try QueryService(registry: registry).query(.contentType("public.html"))

        #expect(result.defaultApp == textEdit)
        #expect(result.candidates == [textEdit])
    }

    @Test("URL scheme returns its handlers")
    func handlerForScheme() throws {
        var registry = FakeRegistry()
        registry.defaultByScheme["mailto"] = mail
        registry.appsByScheme["mailto"] = [mail, textEdit]

        let result = try QueryService(registry: registry).query(.scheme("mailto"))

        #expect(result.defaultApp == mail)
        #expect(result.candidates == [mail, textEdit])
    }

    @Test("a type nothing handles yields empty result, not an error")
    func typeWithoutHandlers() throws {
        var registry = FakeRegistry()
        registry.typesByExtension["weird"] = "dyn.weird"

        let result = try QueryService(registry: registry).query(.fileExtension("weird"))

        #expect(result.defaultApp == nil)
        #expect(result.candidates.isEmpty)
    }
}
