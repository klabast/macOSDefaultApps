import Foundation

/// Port over "what is the newest published release". Faked in tests; the
/// real adapter is `GitHubReleases`.
public protocol ReleaseFeed: Sendable {
    func latestTag() async throws -> String
}

public enum UpdateCheckError: Error, Equatable, CustomStringConvertible {
    case badResponse(Int)

    public var description: String {
        switch self {
        case .badResponse(let status): "github answered \(status)"
        }
    }
}

public struct GitHubReleases: ReleaseFeed {
    public static let page = URL(string: "https://github.com/klabast/macOSDefaultApps/releases/latest")
    static let api = URL(string: "https://api.github.com/repos/klabast/macOSDefaultApps/releases/latest")

    public init() {}

    public func latestTag() async throws -> String {
        guard let api = Self.api else { throw URLError(.badURL) }
        var request = URLRequest(url: api, timeoutInterval: 5)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw UpdateCheckError.badResponse(http.statusCode)
        }
        return try Self.tag(in: data)
    }

    private struct Release: Decodable {
        let tagName: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
        }
    }

    static func tag(in data: Data) throws -> String {
        try JSONDecoder().decode(Release.self, from: data).tagName
    }
}

public struct UpdateCheck: Sendable {
    let feed: any ReleaseFeed

    public init(feed: any ReleaseFeed = GitHubReleases()) {
        self.feed = feed
    }

    /// The newer version as shown to people (no tag prefix), nil when current.
    public func newerVersion(than current: String = Version.current) async throws -> String? {
        let tag = try await feed.latestTag()
        guard Version.isNewer(tag, than: current) else { return nil }
        return tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }
}
