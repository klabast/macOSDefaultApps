import Testing
import DefaultAppsTestSupport
@testable import DefaultAppsCore

@Suite("apply planning and execution")
struct ApplyServiceTests {
    let sublime = app("com.sublimetext.4", "Sublime Text")
    let xcode = app("com.apple.dt.Xcode", "Xcode")

    var registry: FakeRegistry {
        var registry = FakeRegistry()
        registry.appsByBundleID["com.sublimetext.4"] = sublime
        registry.appsByBundleID["com.apple.dt.Xcode"] = xcode
        registry.typesByExtension["md"] = "net.daringfireball.markdown"
        registry.typesByExtension["txt"] = "public.plain-text"
        registry.defaultByType["net.daringfireball.markdown"] = xcode
        registry.defaultByType["public.plain-text"] = sublime
        return registry
    }

    var spec: ApplySpec {
        get throws {
            try ApplySpec.parse("""
                com.sublimetext.4  .md
                com.sublimetext.4  .txt
                com.not.installed  .md
                """)
        }
    }

    @Test("plan classifies change, unchanged and missing app")
    func planning() throws {
        let plan = ApplyService(registry: registry, writer: FakeWriter()).plan(try spec)

        #expect(plan.map(\.action) == [
            .change(from: xcode, to: sublime),
            .unchanged(sublime),
            .missingApp,
        ])
    }

    @Test("apply writes only actual changes and reports everything")
    func applying() async throws {
        let writer = FakeWriter()

        let results = await ApplyService(registry: registry, writer: writer).apply(try spec)

        #expect(results.map(\.outcome) == [.applied, .unchanged, .skippedMissingApp])
        #expect(writer.typeCalls.count == 1)
        #expect(writer.typeCalls.first?.uti == "net.daringfireball.markdown")
    }

    @Test("planning reads defaults only, never candidate lists")
    func planningSkipsCandidates() throws {
        let counting = CountingRegistry(registry)

        _ = ApplyService(registry: counting, writer: FakeWriter()).plan(try spec)

        #expect(counting.candidateCalls == 0)
        #expect(counting.defaultCalls == 2)
    }

    @Test("planning resolves each bundle id once, however often it appears")
    func planningResolvesAppsOnce() throws {
        let counting = CountingRegistry(registry)

        _ = ApplyService(registry: counting, writer: FakeWriter()).plan(try spec)

        #expect(counting.applicationCalls == 2, "sublime twice and one missing app is two lookups")
    }

    @Test("applying a plan does not redo the plan's lookups")
    func applyingReusesThePlan() async throws {
        let counting = CountingRegistry(registry)
        let writer = FakeWriter()
        let service = ApplyService(registry: counting, writer: writer)
        let plan = service.plan(try spec)
        counting.reset()

        let results = await service.apply(plan)

        #expect(results.map(\.outcome) == [.applied, .unchanged, .skippedMissingApp])
        #expect(counting.applicationCalls == 0)
        #expect(counting.defaultCalls == 0)
        #expect(counting.candidateCalls == 0)
    }

    @Test("a refused write reports failed and the rest still runs")
    func failure() async throws {
        let writer = FakeWriter()
        writer.error = SetError.systemRefused("nope")

        let results = await ApplyService(registry: registry, writer: writer).apply(try spec)

        #expect(results.map(\.outcome) == [
            .failed("launch services refused: nope"), .unchanged, .skippedMissingApp,
        ])
    }
}
