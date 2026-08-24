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

    struct Preview {
        let title: String
        let spec: ApplySpec
        let plan: [PlannedChange]
        var results: [AppliedChange]?
    }

    private(set) var presetNames: [String] = []
    private(set) var storeIsVersioned = true
    var preview: Preview?
    var savePresetSheet = false
    var presetName = ""

    private let registry = LaunchServicesRegistry()
    private let presets = PresetStore.standard

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
        presetNames = presets.list()
        storeIsVersioned = presets.isVersioned
    }

    func beginPreview(preset name: String) {
        do {
            beginPreview(text: try presets.read(name), title: name)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func beginPreview(text: String, title: String) {
        do {
            let spec = try ApplySpec.parse(text)
            let plan = ApplyService(registry: registry, writer: LaunchServicesWriter()).plan(spec)
            preview = Preview(title: title, spec: spec, plan: plan, results: nil)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func confirmApply() {
        guard let spec = preview?.spec else { return }
        Task {
            let results = await ApplyService(registry: registry, writer: LaunchServicesWriter())
                .apply(spec)
            preview?.results = results
            reload()
        }
    }

    func savePreset() {
        do {
            try presets.save(presetName, text: snapshot.settingsFileText())
            savePresetSheet = false
            reload()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func exportText() -> String {
        snapshot.settingsFileText()
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
