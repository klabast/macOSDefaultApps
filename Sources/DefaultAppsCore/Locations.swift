import Foundation

/// Where mda keeps its two kinds of file. Presets are meant to be shared —
/// people keep ~/.mda in a dotfiles repo. Machine state is the opposite: a
/// restore point describes one Mac and is wrong on any other, so it lives
/// outside anything a dotfiles checkout would carry.
public struct Locations: Sendable {
    public let presets: URL
    public let state: URL

    public init(presets: URL, state: URL) {
        self.presets = presets
        self.state = state
    }

    public static var standard: Locations {
        standard(environment: ProcessInfo.processInfo.environment)
    }

    /// The env overrides exist so the cli can be exercised end to end without
    /// aiming at the real ~/.mda.
    static func standard(environment: [String: String]) -> Locations {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return Locations(
            presets: environment["MDA_PRESETS_DIR"].map { URL(filePath: $0) }
                ?? home.appending(path: ".mda"),
            state: environment["MDA_STATE_DIR"].map { URL(filePath: $0) }
                ?? (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                    .first ?? home.appending(path: "Library/Application Support"))
                    .appending(path: "mda"))
    }
}
