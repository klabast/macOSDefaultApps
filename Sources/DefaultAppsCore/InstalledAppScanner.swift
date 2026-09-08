import Foundation

/// The real `TypeDiscovery`: the union of what installed apps declare in
/// their Info.plist. Why this and not LaunchServices or Spotlight: ADR 0001.
public struct InstalledAppScanner: TypeDiscovery {
    public static let defaultSearchPaths: [URL] = [
        URL(filePath: "/Applications"),
        URL(filePath: NSHomeDirectory()).appending(path: "Applications"),
        URL(filePath: "/System/Applications"),
        URL(filePath: "/System/Library/CoreServices"),
    ]

    private let searchPaths: [URL]
    private let maxDepth: Int

    public init(searchPaths: [URL] = InstalledAppScanner.defaultSearchPaths, maxDepth: Int = 3) {
        self.searchPaths = searchPaths
        self.maxDepth = maxDepth
    }

    public func discover() -> DiscoveredTypes {
        var extensions: Set<String> = []
        var schemes: Set<String> = []

        for app in appBundles() {
            guard let info = infoDictionary(at: app) else { continue }
            extensions.formUnion(declaredExtensions(in: info))
            schemes.formUnion(declaredSchemes(in: info))
        }
        return DiscoveredTypes(extensions: extensions, schemes: schemes)
    }

    private func appBundles() -> [URL] {
        var found: [URL] = []
        for root in searchPaths {
            var frontier = [(root, 0)]
            while let (dir, depth) = frontier.popLast() {
                guard depth <= maxDepth,
                      let entries = try? FileManager.default.contentsOfDirectory(
                        at: dir, includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles])
                else { continue }
                for entry in entries {
                    if entry.pathExtension == "app" {
                        found.append(entry)
                    } else if (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                        frontier.append((entry, depth + 1))
                    }
                }
            }
        }
        return found
    }

    private func infoDictionary(at app: URL) -> [String: Any]? {
        let plist = app.appending(path: "Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let object = try? PropertyListSerialization.propertyList(from: data, format: nil)
        else { return nil }
        return object as? [String: Any]
    }

    private func declaredExtensions(in info: [String: Any]) -> Set<String> {
        var result: Set<String> = []

        for case let type as [String: Any] in info["CFBundleDocumentTypes"] as? [Any] ?? [] {
            for case let ext as String in type["CFBundleTypeExtensions"] as? [Any] ?? [] {
                result.formUnion(normalized(ext))
            }
        }
        for key in ["UTExportedTypeDeclarations", "UTImportedTypeDeclarations"] {
            for case let declaration as [String: Any] in info[key] as? [Any] ?? [] {
                let tags = declaration["UTTypeTagSpecification"] as? [String: Any] ?? [:]
                switch tags["public.filename-extension"] {
                case let one as String: result.formUnion(normalized(one))
                case let many as [Any]:
                    for case let ext as String in many { result.formUnion(normalized(ext)) }
                default: break
                }
            }
        }
        return result
    }

    private func declaredSchemes(in info: [String: Any]) -> Set<String> {
        var result: Set<String> = []
        for case let urlType as [String: Any] in info["CFBundleURLTypes"] as? [Any] ?? [] {
            for case let scheme as String in urlType["CFBundleURLSchemes"] as? [Any] ?? [] {
                let lowered = scheme.lowercased()
                if !lowered.isEmpty { result.insert(lowered) }
            }
        }
        return result
    }

    /// `*` is a wildcard some apps use to claim every extension, not a type.
    private func normalized(_ raw: String) -> Set<String> {
        let ext = raw.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return ext.isEmpty || ext == "*" ? [] : [ext]
    }
}
