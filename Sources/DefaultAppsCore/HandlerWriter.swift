/// Write side of the system's handler database. Kept separate from
/// `HandlerRegistry` so read paths stay trivially safe to test.
public protocol HandlerWriter: Sendable {
    func setDefaultApplication(_ app: AppInfo, forType uti: String) async throws
    func setDefaultApplication(_ app: AppInfo, forScheme scheme: String) async throws
}
