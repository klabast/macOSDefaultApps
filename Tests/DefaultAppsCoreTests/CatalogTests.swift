import Foundation
import Testing
@testable import DefaultAppsCore

@Suite("catalog")
struct CatalogTests {
    let sample = Data("""
        {"families":[
          {"name":"plain text","extensions":["txt","md"]},
          {"name":"web","extensions":["html"],"utis":["public.html"]},
          {"name":"url schemes","schemes":["http","mailto"]}
        ]}
        """.utf8)

    @Test("decodes families in order, missing keys default to empty")
    func decode() throws {
        let catalog = try Catalog.load(from: sample)

        #expect(catalog.families.map(\.name) == ["plain text", "web", "url schemes"])
        #expect(catalog.families[0].targets == [.fileExtension("txt"), .fileExtension("md")])
        #expect(catalog.families[1].targets == [.fileExtension("html"), .contentType("public.html")])
        #expect(catalog.families[2].targets == [.scheme("http"), .scheme("mailto")])
    }

    @Test("garbage input throws")
    func garbage() {
        #expect(throws: (any Error).self) {
            try Catalog.load(from: Data("not json".utf8))
        }
    }
}
