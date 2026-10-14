import Foundation

public enum Homebrew {
    public static let standardPrefixes = [URL(filePath: "/opt/homebrew"), URL(filePath: "/usr/local")]

    /// True when `bundle` is the app `brew install --cask` put in place, so
    /// `brew upgrade` already covers updates. The cask existing is not enough:
    /// a dev build or a zip copy can run next to it.
    public static func managesApp(at bundle: URL = Bundle.main.bundleURL, prefixes: [URL] = standardPrefixes)
        -> Bool
    {
        let running = bundle.resolvingSymlinksInPath()
        let fileManager = FileManager.default
        return prefixes.contains { prefix in
            let cask = prefix.appending(path: "Caskroom/macosdefaultapps")
            let versions = (try? fileManager.contentsOfDirectory(atPath: cask.path)) ?? []
            return versions.contains { version in
                cask.appending(path: "\(version)/macOSDefaultApps.app").resolvingSymlinksInPath() == running
            }
        }
    }
}
