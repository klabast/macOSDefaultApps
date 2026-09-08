import DefaultAppsCore

public struct FakeReleaseFeed: ReleaseFeed {
    public var tag: String
    public var error: (any Error)?

    public init(tag: String, error: (any Error)? = nil) {
        self.tag = tag
        self.error = error
    }

    public func latestTag() async throws -> String {
        if let error { throw error }
        return tag
    }
}
