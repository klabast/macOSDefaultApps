import ArgumentParser
import DefaultAppsCore
import Foundation

@main
struct MDA: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mda",
        abstract: "View and set default application associations on macOS.",
        version: Version.current,
        subcommands: [Get.self, List.self, Set.self, Dump.self, Apply.self, Save.self]
    )
}

struct TargetArgument: ParsableArguments {
    @Argument(help: "File extension (md, .md), UTI (public.html), or URL scheme (mailto:).")
    var target: String

    func parsed() throws -> QueryTarget {
        guard let parsed = QueryTarget.parse(target) else {
            throw ValidationError("'\(target)' is not a valid extension, UTI, or scheme.")
        }
        return parsed
    }
}

struct Get: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the default handler."
    )

    @OptionGroup var target: TargetArgument

    func run() throws {
        let result = try QueryService(registry: LaunchServicesRegistry()).query(target.parsed())
        guard let app = result.defaultApp else {
            fputs("no default handler for '\(target.target)'\n", stderr)
            throw ExitCode(1)
        }
        print(line(for: app))
    }
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ls",
        abstract: "List all candidate handlers; the default is marked with *."
    )

    @OptionGroup var target: TargetArgument

    func run() throws {
        let result = try QueryService(registry: LaunchServicesRegistry()).query(target.parsed())
        for app in result.candidates.sorted(by: { $0.name.lowercased() < $1.name.lowercased() }) {
            let marker = app == result.defaultApp ? "*" : " "
            print("\(marker) \(line(for: app))")
        }
    }
}

struct Set: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Set the default handler. May trigger a consent dialog for http/https."
    )

    @Argument(help: "Bundle id of the handler app (e.g. com.apple.Safari).")
    var bundleID: String

    @OptionGroup var target: TargetArgument

    func run() async throws {
        let service = SetService(registry: LaunchServicesRegistry(), writer: LaunchServicesWriter())
        let app = try await service.setDefault(bundleID: bundleID, for: target.parsed())
        print("\(target.target) -> \(line(for: app))")
    }
}

struct Dump: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Dump the curated catalog with current default handlers."
    )

    @Flag(help: "Emit JSON instead of tab-separated lines.")
    var json = false

    @Flag(help: "Also include every type and scheme the installed apps declare.")
    var all = false

    func run() throws {
        var catalog = try Catalog.bundled()
        if all {
            catalog = catalog.extended(with: InstalledAppScanner().discover())
        }
        let snapshot = SnapshotService(registry: LaunchServicesRegistry())
            .build(from: catalog)
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(decoding: try encoder.encode(snapshot), as: UTF8.self))
        } else {
            for entry in snapshot.entries {
                let app = entry.result.defaultApp
                print("\(entry.family)\t\(entry.target.displayString)\t\(app?.name ?? "-")\t\(app?.bundleID ?? "-")")
            }
        }
    }
}

struct Apply: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Apply a preset or settings file (duti-compatible). Applies what it can, reports the rest."
    )

    @Argument(help: "Preset name, path to a settings file, or '-' for stdin. Default: preset 'default'.")
    var source: String?

    func run() async throws {
        let store = PresetStore.standard
        let text: String
        switch source {
        case nil:
            text = try store.read("default")
        case "-":
            text = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
        case let path? where path.contains("/") || FileManager.default.fileExists(atPath: path):
            text = try String(contentsOfFile: path, encoding: .utf8)
        case let name?:
            text = try store.read(name)
        }

        let spec = try ApplySpec.parse(text)
        let results = await ApplyService(
            registry: LaunchServicesRegistry(), writer: LaunchServicesWriter()
        ).apply(spec)

        var counts: [String: Int] = [:]
        for result in results {
            let target = result.line.target.displayString
            switch result.outcome {
            case .applied:
                print("applied    \(target) -> \(result.line.bundleID)")
            case .unchanged:
                print("unchanged  \(target)")
            case .skippedMissingApp:
                print("skipped    \(target) — \(result.line.bundleID) not installed")
            case .failed(let reason):
                print("failed     \(target) — \(reason)")
            }
            counts[label(for: result.outcome), default: 0] += 1
        }
        print(
            ["applied", "unchanged", "skipped", "failed"]
                .compactMap { key in counts[key].map { "\($0) \(key)" } }
                .joined(separator: " · "))
        if counts["skipped", default: 0] + counts["failed", default: 0] > 0 {
            throw ExitCode(1)
        }
    }

    private func label(for outcome: ApplyOutcome) -> String {
        switch outcome {
        case .applied: "applied"
        case .unchanged: "unchanged"
        case .skippedMissingApp: "skipped"
        case .failed: "failed"
        }
    }
}

struct Save: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Save current handlers as a preset in ~/.mda."
    )

    @Argument(help: "Preset name.")
    var name: String = "default"

    func run() throws {
        let store = PresetStore.standard
        let snapshot = SnapshotService(registry: LaunchServicesRegistry())
            .build(from: try Catalog.bundled())
        try store.save(name, text: snapshot.settingsFileText())
        print("saved \(try store.url(for: name).path)")
        if !store.isVersioned {
            fputs(
                "warning: \(store.directory.path) is not inside a git repository — saves overwrite without history. consider: git init \(store.directory.path)\n",
                stderr)
        }
    }
}

private func line(for app: AppInfo) -> String {
    "\(app.name)\t\(app.bundleID)\t\(app.url.path)"
}
