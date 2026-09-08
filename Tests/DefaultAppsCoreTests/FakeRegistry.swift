import Foundation
@testable import DefaultAppsCore

struct FakeRegistry: HandlerRegistry {
    var typesByExtension: [String: String] = [:]
    var defaultByType: [String: AppInfo] = [:]
    var appsByType: [String: [AppInfo]] = [:]
    var defaultByScheme: [String: AppInfo] = [:]
    var appsByScheme: [String: [AppInfo]] = [:]
    var appsByBundleID: [String: AppInfo] = [:]

    func typeIdentifier(forExtension ext: String) -> String? { typesByExtension[ext] }
    func defaultApplication(forType uti: String) -> AppInfo? { defaultByType[uti] }
    func applications(forType uti: String) -> [AppInfo] { appsByType[uti] ?? [] }
    func defaultApplication(forScheme scheme: String) -> AppInfo? { defaultByScheme[scheme] }
    func applications(forScheme scheme: String) -> [AppInfo] { appsByScheme[scheme] ?? [] }
    func application(withBundleID bundleID: String) -> AppInfo? { appsByBundleID[bundleID] }
}

func app(_ id: String, _ name: String) -> AppInfo {
    AppInfo(bundleID: id, name: name, url: URL(filePath: "/Applications/\(name).app"))
}

/// Counts calls per method so tests can prove what a code path does not do.
final class CountingRegistry: HandlerRegistry, @unchecked Sendable {
    let inner: FakeRegistry
    private(set) var typeIdentifierCalls = 0
    private(set) var defaultCalls = 0
    private(set) var candidateCalls = 0
    private(set) var applicationCalls = 0

    init(_ inner: FakeRegistry) {
        self.inner = inner
    }

    func reset() {
        typeIdentifierCalls = 0
        defaultCalls = 0
        candidateCalls = 0
        applicationCalls = 0
    }

    func typeIdentifier(forExtension ext: String) -> String? {
        typeIdentifierCalls += 1
        return inner.typeIdentifier(forExtension: ext)
    }

    func defaultApplication(forType uti: String) -> AppInfo? {
        defaultCalls += 1
        return inner.defaultApplication(forType: uti)
    }

    func applications(forType uti: String) -> [AppInfo] {
        candidateCalls += 1
        return inner.applications(forType: uti)
    }

    func defaultApplication(forScheme scheme: String) -> AppInfo? {
        defaultCalls += 1
        return inner.defaultApplication(forScheme: scheme)
    }

    func applications(forScheme scheme: String) -> [AppInfo] {
        candidateCalls += 1
        return inner.applications(forScheme: scheme)
    }

    func application(withBundleID bundleID: String) -> AppInfo? {
        applicationCalls += 1
        return inner.application(withBundleID: bundleID)
    }
}
