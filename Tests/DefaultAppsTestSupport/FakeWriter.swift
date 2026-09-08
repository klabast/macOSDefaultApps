import DefaultAppsCore

public final class FakeWriter: HandlerWriter, @unchecked Sendable {
    public var typeCalls: [(bundleID: String, uti: String)] = []
    public var schemeCalls: [(bundleID: String, scheme: String)] = []
    public var error: (any Error)?

    public init() {}

    public func setDefaultApplication(_ app: AppInfo, forType uti: String) async throws {
        if let error { throw error }
        typeCalls.append((app.bundleID, uti))
    }

    public func setDefaultApplication(_ app: AppInfo, forScheme scheme: String) async throws {
        if let error { throw error }
        schemeCalls.append((app.bundleID, scheme))
    }
}
