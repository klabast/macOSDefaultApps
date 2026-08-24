import ArgumentParser
import DefaultAppsCore
import Foundation

@main
struct MDA: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mda",
        abstract: "View and set default application associations on macOS.",
        subcommands: [Get.self, List.self, Set.self, Dump.self, Apply.self]
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

    func run() throws {
        let snapshot = try SnapshotService(registry: LaunchServicesRegistry())
            .build(from: Catalog.bundled())
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
        abstract: "Apply a settings file (duti-compatible). Stops at the first failure."
    )

    @Argument(help: "Path to the settings file, or '-' for stdin.")
    var path: String

    func run() async throws {
        let text: String
        if path == "-" {
            text = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
        } else {
            text = try String(contentsOfFile: path, encoding: .utf8)
        }
        let spec = try ApplySpec.parse(text)
        let service = SetService(registry: LaunchServicesRegistry(), writer: LaunchServicesWriter())
        for entry in spec.lines {
            let app = try await service.setDefault(bundleID: entry.bundleID, for: entry.target)
            print("\(entry.target.displayString) -> \(app.name) (\(app.bundleID))")
        }
    }
}

private func line(for app: AppInfo) -> String {
    "\(app.name)\t\(app.bundleID)\t\(app.url.path)"
}
