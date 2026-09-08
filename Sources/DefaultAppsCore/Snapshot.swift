import Foundation

public struct SnapshotEntry: Equatable, Sendable, Codable {
    public let family: String
    public let target: QueryTarget
    public let result: QueryResult

    public init(family: String, target: QueryTarget, result: QueryResult) {
        self.family = family
        self.target = target
        self.result = result
    }
}

public struct Snapshot: Equatable, Sendable, Codable {
    public let entries: [SnapshotEntry]

    public init(entries: [SnapshotEntry]) {
        self.entries = entries
    }

    public func filtered(_ query: String) -> Snapshot {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return self }
        return Snapshot(entries: entries.filter { entry in
            let haystack =
                [entry.family, entry.target.displayString]
                + entry.result.allApps.flatMap { [$0.name, $0.bundleID] }
            return haystack.contains { $0.lowercased().contains(needle) }
        })
    }

    public func apps() -> [AppInfo] {
        var byBundleID: [String: AppInfo] = [:]
        for entry in entries {
            for app in entry.result.allApps {
                byBundleID[app.bundleID] = app
            }
        }
        return byBundleID.values.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Current defaults as an apply-format settings file.
    public func settingsFileText() -> String {
        let width = entries.compactMap { $0.result.defaultApp?.bundleID.count }.max() ?? 0
        var lines: [String] = []
        var lastFamily: String?
        for entry in entries {
            guard let app = entry.result.defaultApp else { continue }
            if entry.family != lastFamily {
                if lastFamily != nil { lines.append("") }
                lines.append("# \(entry.family)")
                lastFamily = entry.family
            }
            let padded = app.bundleID.padding(
                toLength: width, withPad: " ", startingAt: 0)
            lines.append("\(padded)  \(entry.target.displayString)  # \(app.name)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Only the families `catalog` declares — the curated ones, when the
    /// snapshot was built from a catalog extended by discovery.
    public func restricted(to catalog: Catalog) -> Snapshot {
        let families = Set(catalog.families.map(\.name))
        return Snapshot(entries: entries.filter { families.contains($0.family) })
    }

    public func entries(handledBy bundleID: String) -> [SnapshotEntry] {
        entries.filter { entry in
            entry.result.defaultApp?.bundleID == bundleID
                || entry.result.candidates.contains { $0.bundleID == bundleID }
        }
    }
}

public struct FamilyGroup: Equatable, Sendable {
    public let name: String
    public let entries: [SnapshotEntry]

    public init(name: String, entries: [SnapshotEntry]) {
        self.name = name
        self.entries = entries
    }
}

extension Array where Element == SnapshotEntry {
    public func groupedByFamily() -> [FamilyGroup] {
        var order: [String] = []
        var byName: [String: [SnapshotEntry]] = [:]
        for entry in self {
            if byName[entry.family] == nil { order.append(entry.family) }
            byName[entry.family, default: []].append(entry)
        }
        return order.map { FamilyGroup(name: $0, entries: byName[$0] ?? []) }
    }
}

public struct SnapshotService: Sendable {
    let registry: any HandlerRegistry

    public init(registry: any HandlerRegistry) {
        self.registry = registry
    }

    public func build(from catalog: Catalog) -> Snapshot {
        let service = QueryService(registry: registry)
        var entries: [SnapshotEntry] = []
        for family in catalog.families {
            for target in family.targets {
                let result = (try? service.query(target))
                    ?? QueryResult(defaultApp: nil, candidates: [])
                entries.append(SnapshotEntry(family: family.name, target: target, result: result))
            }
        }
        return Snapshot(entries: entries)
    }
}
