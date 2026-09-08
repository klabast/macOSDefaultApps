public struct QueryResult: Equatable, Sendable, Codable {
    public let defaultApp: AppInfo?
    public let candidates: [AppInfo]

    public init(defaultApp: AppInfo?, candidates: [AppInfo]) {
        self.defaultApp = defaultApp
        self.candidates = candidates
    }

    // the default is not always among the candidates
    public var allApps: [AppInfo] {
        var seen: Set<String> = []
        return (candidates + [defaultApp].compactMap { $0 })
            .filter { seen.insert($0.bundleID).inserted }
    }
}

public enum QueryError: Error, Equatable, CustomStringConvertible {
    case unknownExtension(String)

    public var description: String {
        switch self {
        case .unknownExtension(let ext): "unknown file extension '\(ext)'"
        }
    }
}

public struct QueryService: Sendable {
    let registry: any HandlerRegistry

    public init(registry: any HandlerRegistry) {
        self.registry = registry
    }

    public func query(_ target: QueryTarget) throws -> QueryResult {
        switch try registry.resolve(target) {
        case .type(let uti):
            QueryResult(
                defaultApp: registry.defaultApplication(forType: uti),
                candidates: registry.applications(forType: uti))
        case .scheme(let scheme):
            QueryResult(
                defaultApp: registry.defaultApplication(forScheme: scheme),
                candidates: registry.applications(forScheme: scheme))
        }
    }

    public func defaultApplication(for target: QueryTarget) throws -> AppInfo? {
        switch try registry.resolve(target) {
        case .type(let uti): registry.defaultApplication(forType: uti)
        case .scheme(let scheme): registry.defaultApplication(forScheme: scheme)
        }
    }
}
