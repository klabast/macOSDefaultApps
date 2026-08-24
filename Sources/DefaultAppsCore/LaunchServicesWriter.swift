import AppKit
import UniformTypeIdentifiers

/// Setting the http/https handler (the default browser) triggers a user
/// consent dialog; the call only returns once the user decides.
public struct LaunchServicesWriter: HandlerWriter {
    public init() {}

    public func setDefaultApplication(_ app: AppInfo, forType uti: String) async throws {
        guard let type = UTType(uti) else {
            throw SetError.systemRefused("invalid UTI '\(uti)'")
        }
        do {
            try await NSWorkspace.shared.setDefaultApplication(at: app.url, toOpen: type)
        } catch {
            throw SetError.systemRefused(error.localizedDescription)
        }
    }

    public func setDefaultApplication(_ app: AppInfo, forScheme scheme: String) async throws {
        do {
            try await NSWorkspace.shared.setDefaultApplication(at: app.url, toOpenURLsWithScheme: scheme)
        } catch {
            throw SetError.systemRefused(error.localizedDescription)
        }
    }
}
