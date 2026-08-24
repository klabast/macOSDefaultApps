import Foundation

public enum PresetError: Error, Equatable, CustomStringConvertible {
    case invalidName(String)
    case notFound(String)

    public var description: String {
        switch self {
        case .invalidName(let name): "invalid preset name '\(name)'"
        case .notFound(let name): "no preset named '\(name)'"
        }
    }
}

/// Presets are plain settings files in one directory (default ~/.mda),
/// so the cli, the ui and a dotfiles repo all work on the same data.
public struct PresetStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static var standard: PresetStore {
        PresetStore(directory: FileManager.default.homeDirectoryForCurrentUser.appending(path: ".mda"))
    }

    public func url(for name: String) throws -> URL {
        guard let first = name.first, first.isLetter || first.isNumber,
            name.allSatisfy({ $0.isLetter || $0.isNumber || "._-".contains($0) })
        else { throw PresetError.invalidName(name) }
        return directory.appending(path: name)
    }

    public func list() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.filter { !$0.hasPrefix(".") }.sorted()
    }

    public func read(_ name: String) throws -> String {
        let url = try url(for: name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PresetError.notFound(name)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    public func save(_ name: String, text: String) throws {
        let url = try url(for: name)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// True when the store directory lives inside a git repository —
    /// without one, saves overwrite silently instead of being diffable.
    public var isVersioned: Bool {
        var current = directory.resolvingSymlinksInPath().standardizedFileURL
        // deletingLastPathComponent on "/" appends ".." forever — count down instead
        while current.pathComponents.count > 1 {
            if FileManager.default.fileExists(atPath: current.appending(path: ".git").path) {
                return true
            }
            current.deleteLastPathComponent()
        }
        return false
    }
}
