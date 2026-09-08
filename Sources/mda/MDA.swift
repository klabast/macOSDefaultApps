import ArgumentParser
import DefaultAppsCore
import Foundation

@main
struct MDA: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mda",
        abstract: "View and set default application associations on macOS.",
        version: Version.current,
        subcommands: [Get.self, List.self, SetDefault.self, Dump.self, Apply.self, Save.self]
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

struct SetDefault: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set the default handler. May trigger a consent dialog for http/https."
    )

    @Argument(help: "Bundle id of the handler app (e.g. com.apple.Safari).")
    var bundleID: String

    @OptionGroup var target: TargetArgument

    func run() async throws {
        recordRestorePoint()
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

    @Argument(help: "Preset name, 'initial' for the restore point, a settings file path, or '-' for stdin. Default: preset 'default'.")
    var source: String?

    func run() async throws {
        let store = PresetStore.standard
        let text: String
        switch source {
        case nil:
            text = try store.read("default")
        case "-":
            text = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
        case RestorePoint.name:
            text = try RestorePoint.standard(registry: LaunchServicesRegistry()).text()
        case let path? where path.contains("/") || FileManager.default.fileExists(atPath: path):
            text = try String(contentsOfFile: path, encoding: .utf8)
        case let name?:
            text = try store.read(name)
        }

        let spec = try ApplySpec.parse(text)
        recordRestorePoint()
        let results = await ApplyService(
            registry: LaunchServicesRegistry(), writer: LaunchServicesWriter()
        ).apply(spec)

        var counts: [String: Int] = [:]
        for result in results {
            let target = result.line.target.displayString
            let (label, detail): (String, String) = switch result.outcome {
            case .applied: ("applied", "\(target) -> \(result.line.bundleID)")
            case .unchanged: ("unchanged", target)
            case .skippedMissingApp: ("skipped", "\(target) — \(result.line.bundleID) not installed")
            case .failed(let reason): ("failed", "\(target) — \(reason)")
            }
            print(label.padding(toLength: 11, withPad: " ", startingAt: 0) + detail)
            counts[label, default: 0] += 1
        }
        print(
            ["applied", "unchanged", "skipped", "failed"]
                .compactMap { key in counts[key].map { "\($0) \(key)" } }
                .joined(separator: " · "))
        if counts["skipped", default: 0] + counts["failed", default: 0] > 0 {
            throw ExitCode(1)
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
        recordRestorePoint()
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

/// Captures the restore point on the first run that is about to change
/// something. A failure here warns but does not block the command the user
/// actually asked for.
private func recordRestorePoint() {
    let restore = RestorePoint.standard(registry: LaunchServicesRegistry())
    do {
        let captured = try restore.captureIfMissing {
            try Catalog.bundled().extended(with: InstalledAppScanner().discover())
        }
        if captured {
            fputs("recorded \(restore.url.path) — 'mda apply initial' puts things back\n", stderr)
        }
    } catch {
        fputs("warning: could not record the restore point — \(error)\n", stderr)
    }
}

private func line(for app: AppInfo) -> String {
    "\(app.name)\t\(app.bundleID)\t\(app.url.path)"
}
