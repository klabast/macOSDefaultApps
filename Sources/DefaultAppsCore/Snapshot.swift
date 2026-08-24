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

    public func entries(handledBy bundleID: String) -> [SnapshotEntry] {
        entries.filter { entry in
            entry.result.defaultApp?.bundleID == bundleID
                || entry.result.candidates.contains { $0.bundleID == bundleID }
        }
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
