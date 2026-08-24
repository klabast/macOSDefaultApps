import AppKit
import DefaultAppsCore
import Observation

enum SidebarItem: Hashable {
    case allTypes
    case family(String)
    case app(String)
}

@MainActor
@Observable
final class AppStore {
    enum Mode: String, CaseIterable, Identifiable {
        case byType, byApp

        var id: String { rawValue }

        var label: String {
            switch self {
            case .byType: t("By Type")
            case .byApp: t("By App")
            }
        }
    }

    private(set) var snapshot = Snapshot(entries: [])
    var filter = ""
    var errorMessage: String?
    var selection: SidebarItem? = .allTypes
    private(set) var busy: Set<String> = []

    var mode: Mode = .byType {
        didSet {
            guard mode != oldValue else { return }
            selection =
                mode == .byType
                ? .allTypes
                : snapshot.apps().first.map { .app($0.bundleID) }
        }
    }

    private let registry = LaunchServicesRegistry()

    var visible: Snapshot { snapshot.filtered(filter) }

    var detailEntries: [SnapshotEntry] {
        switch selection {
        case .family(let name): visible.entries.filter { $0.family == name }
        case .app(let bundleID): visible.entries(handledBy: bundleID)
        case .allTypes, nil: visible.entries
        }
    }

    var selectedApp: AppInfo? {
        guard case .app(let bundleID) = selection else { return nil }
        return snapshot.apps().first { $0.bundleID == bundleID }
    }

    func reload() {
        do {
            snapshot = SnapshotService(registry: registry).build(from: try Catalog.bundled())
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func setDefault(_ bundleID: String, for target: QueryTarget) {
        busy.insert(target.displayString)
        Task {
            do {
                _ = try await SetService(registry: registry, writer: LaunchServicesWriter())
                    .setDefault(bundleID: bundleID, for: target)
            } catch {
                errorMessage = String(describing: error)
            }
            reload()
            busy.remove(target.displayString)
        }
    }
}
