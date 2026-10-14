import Foundation

public enum Homebrew {
    public static let standardPrefixes = [URL(filePath: "/opt/homebrew"), URL(filePath: "/usr/local")]

    /// True when the app came in through `brew install --cask`, so
    /// `brew upgrade` already covers updates.
    public static func managesApp(prefixes: [URL] = standardPrefixes) -> Bool {
        prefixes.contains {
            FileManager.default.fileExists(atPath: $0.appending(path: "Caskroom/macosdefaultapps").path)
        }
    }
}
