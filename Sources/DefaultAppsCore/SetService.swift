import Foundation

public enum SetError: Error, Equatable, CustomStringConvertible {
    case unknownApplication(String)
    case systemRefused(String)

    public var description: String {
        switch self {
        case .unknownApplication(let id): "no installed application with bundle id '\(id)'"
        case .systemRefused(let reason): "launch services refused: \(reason)"
        }
    }
}

public struct SetService: Sendable {
    let registry: any HandlerRegistry
    let writer: any HandlerWriter

    public init(registry: any HandlerRegistry, writer: any HandlerWriter) {
        self.registry = registry
        self.writer = writer
    }

    public func setDefault(bundleID: String, for target: QueryTarget) async throws -> AppInfo {
        guard let app = registry.application(withBundleID: bundleID) else {
            throw SetError.unknownApplication(bundleID)
        }
        try await setDefault(app, for: target)
        return app
    }

    public func setDefault(_ app: AppInfo, for target: QueryTarget) async throws {
        switch try registry.resolve(target) {
        case .type(let uti): try await writer.setDefaultApplication(app, forType: uti)
        case .scheme(let scheme): try await writer.setDefaultApplication(app, forScheme: scheme)
        }
    }
}
