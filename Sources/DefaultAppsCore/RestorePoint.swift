import Foundation

public enum RestorePointError: Error, Equatable, CustomStringConvertible {
    case notCaptured

    public var description: String {
        switch self {
        case .notCaptured: "no restore point on this machine yet"
        }
    }
}

/// The associations as they were before mda first changed anything. Written
/// once and never again — a restore point that moves is not a restore point —
/// and kept in machine-local state rather than alongside the presets, so it
/// cannot follow a dotfiles checkout onto a Mac it does not describe.
public struct RestorePoint: Sendable {
    public static let name = "initial"

    public let directory: URL
    private let registry: any HandlerRegistry

    public init(directory: URL, registry: any HandlerRegistry) {
        self.directory = directory
        self.registry = registry
    }

    public static func standard(registry: any HandlerRegistry) -> RestorePoint {
        RestorePoint(directory: Locations.standard.state, registry: registry)
    }

    public var url: URL {
        directory.appending(path: RestorePoint.name)
    }

    public var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public func text() throws -> String {
        guard exists else { throw RestorePointError.notCaptured }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// `catalog` stays unevaluated when the restore point already exists, so
    /// callers pay for enumerating types only on the run that captures.
    @discardableResult
    public func captureIfMissing(catalog: () throws -> Catalog) throws -> Bool {
        guard exists == false else { return false }
        return try captureIfMissing(
            from: SnapshotService(registry: registry).build(from: try catalog()))
    }

    @discardableResult
    public func captureIfMissing(from snapshot: Snapshot) throws -> Bool {
        guard exists == false else { return false }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try snapshot.settingsFileText().write(to: url, atomically: true, encoding: .utf8)
        return true
    }
}
