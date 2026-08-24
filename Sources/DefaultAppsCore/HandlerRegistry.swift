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
