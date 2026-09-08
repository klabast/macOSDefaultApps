import DefaultAppsCore
import Foundation

public struct FakeRegistry: HandlerRegistry {
    public var typesByExtension: [String: String] = [:]
    public var defaultByType: [String: AppInfo] = [:]
    public var appsByType: [String: [AppInfo]] = [:]
    public var defaultByScheme: [String: AppInfo] = [:]
    public var appsByScheme: [String: [AppInfo]] = [:]
    public var appsByBundleID: [String: AppInfo] = [:]

    public init() {}

    public func typeIdentifier(forExtension ext: String) -> String? { typesByExtension[ext] }
    public func defaultApplication(forType uti: String) -> AppInfo? { defaultByType[uti] }
    public func applications(forType uti: String) -> [AppInfo] { appsByType[uti] ?? [] }
    public func defaultApplication(forScheme scheme: String) -> AppInfo? { defaultByScheme[scheme] }
    public func applications(forScheme scheme: String) -> [AppInfo] { appsByScheme[scheme] ?? [] }
    public func application(withBundleID bundleID: String) -> AppInfo? { appsByBundleID[bundleID] }
}

public func app(_ id: String, _ name: String) -> AppInfo {
    AppInfo(bundleID: id, name: name, url: URL(filePath: "/Applications/\(name).app"))
}

/// Counts calls per method so tests can prove what a code path does not do.
public final class CountingRegistry: HandlerRegistry, @unchecked Sendable {
    let inner: FakeRegistry
    public private(set) var typeIdentifierCalls = 0
    public private(set) var defaultCalls = 0
    public private(set) var candidateCalls = 0
    public private(set) var applicationCalls = 0

    public init(_ inner: FakeRegistry) {
        self.inner = inner
    }

    public func reset() {
        typeIdentifierCalls = 0
        defaultCalls = 0
        candidateCalls = 0
        applicationCalls = 0
    }

    public func typeIdentifier(forExtension ext: String) -> String? {
        typeIdentifierCalls += 1
        return inner.typeIdentifier(forExtension: ext)
    }

    public func defaultApplication(forType uti: String) -> AppInfo? {
        defaultCalls += 1
        return inner.defaultApplication(forType: uti)
    }

    public func applications(forType uti: String) -> [AppInfo] {
        candidateCalls += 1
        return inner.applications(forType: uti)
    }

    public func defaultApplication(forScheme scheme: String) -> AppInfo? {
        defaultCalls += 1
        return inner.defaultApplication(forScheme: scheme)
    }

    public func applications(forScheme scheme: String) -> [AppInfo] {
        candidateCalls += 1
        return inner.applications(forScheme: scheme)
    }

    public func application(withBundleID bundleID: String) -> AppInfo? {
        applicationCalls += 1
        return inner.application(withBundleID: bundleID)
    }
}
