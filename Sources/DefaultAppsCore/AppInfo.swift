import Foundation

public struct AppInfo: Equatable, Sendable, Codable {
    public let bundleID: String
    public let name: String
    public let url: URL

    public init(bundleID: String, name: String, url: URL) {
        self.bundleID = bundleID
        self.name = name
        self.url = url
    }
}
