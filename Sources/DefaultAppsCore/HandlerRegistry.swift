/// Port over the system's type/handler database (LaunchServices).
/// Faked in tests; the real adapter is `LaunchServicesRegistry`.
public protocol HandlerRegistry: Sendable {
    func typeIdentifier(forExtension ext: String) -> String?
    func defaultApplication(forType uti: String) -> AppInfo?
    func applications(forType uti: String) -> [AppInfo]
    func defaultApplication(forScheme scheme: String) -> AppInfo?
    func applications(forScheme scheme: String) -> [AppInfo]
    func application(withBundleID bundleID: String) -> AppInfo?
}

/// A `QueryTarget` with its file extension resolved to the UTI the database keys on.
enum ResolvedTarget {
    case type(String)
    case scheme(String)
}

extension HandlerRegistry {
    func resolve(_ target: QueryTarget) throws -> ResolvedTarget {
        switch target {
        case .fileExtension(let ext):
            guard let uti = typeIdentifier(forExtension: ext) else {
                throw QueryError.unknownExtension(ext)
            }
            return .type(uti)
        case .contentType(let uti):
            return .type(uti)
        case .scheme(let scheme):
            return .scheme(scheme)
        }
    }
}
