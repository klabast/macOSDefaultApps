import AppKit
import UniformTypeIdentifiers

/// The real `HandlerRegistry`, backed by NSWorkspace + UniformTypeIdentifiers.
/// Read-only; mutations live elsewhere. Never uses deprecated `LS*` C calls.
public struct LaunchServicesRegistry: HandlerRegistry {
    public init() {}

    /// Unknown extensions still resolve — LaunchServices mints a dynamic
    /// (`dyn.*`) UTI for them, which can legitimately carry associations.
    public func typeIdentifier(forExtension ext: String) -> String? {
        UTType(filenameExtension: ext)?.identifier
    }

    public func defaultApplication(forType uti: String) -> AppInfo? {
        guard let type = UTType(uti) else { return nil }
        return NSWorkspace.shared.urlForApplication(toOpen: type).flatMap(appInfo(at:))
    }

    public func applications(forType uti: String) -> [AppInfo] {
        guard let type = UTType(uti) else { return [] }
        return NSWorkspace.shared.urlsForApplications(toOpen: type).compactMap(appInfo(at:))
    }

    public func defaultApplication(forScheme scheme: String) -> AppInfo? {
        guard let url = schemeURL(scheme) else { return nil }
        return NSWorkspace.shared.urlForApplication(toOpen: url).flatMap(appInfo(at:))
    }

    public func applications(forScheme scheme: String) -> [AppInfo] {
        guard let url = schemeURL(scheme) else { return [] }
        return NSWorkspace.shared.urlsForApplications(toOpen: url).compactMap(appInfo(at:))
    }

    public func application(withBundleID bundleID: String) -> AppInfo? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).flatMap(appInfo(at:))
    }

    private func schemeURL(_ scheme: String) -> URL? {
        URL(string: "\(scheme)://")
    }

    private func appInfo(at url: URL) -> AppInfo? {
        guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return nil }
        return AppInfo(bundleID: id, name: url.deletingPathExtension().lastPathComponent, url: url)
    }
}
