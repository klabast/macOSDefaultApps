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
