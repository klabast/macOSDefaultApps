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
    private var curated = Catalog(families: [])
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
        let plan: [PlannedChange]
        var results: [AppliedChange]?
    }

    private(set) var presetNames: [String] = []
    private(set) var hasRestorePoint = false
    private(set) var storeIsVersioned = true
    var preview: Preview?
    var savePresetSheet = false
    var presetName = ""

    private let registry: any HandlerRegistry
    private let discovery: any TypeDiscovery
    private let writer: any HandlerWriter
    private let presets: PresetStore
    private let restorePoint: RestorePoint

    init(
        registry: any HandlerRegistry = LaunchServicesRegistry(),
        discovery: any TypeDiscovery = InstalledAppScanner(),
        writer: any HandlerWriter = LaunchServicesWriter(),
        locations: Locations = .standard
    ) {
        self.registry = registry
        self.discovery = discovery
        self.writer = writer
        presets = PresetStore(directory: locations.presets)
        restorePoint = RestorePoint(directory: locations.state, registry: registry)
    }

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
            curated = try Catalog.bundled()
            snapshot = SnapshotService(registry: registry)
                .build(from: curated.extended(with: discovery.discover()))
            try restorePoint.captureIfMissing(from: snapshot)
        } catch {
            errorMessage = String(describing: error)
        }
        presetNames = presets.list()
        hasRestorePoint = restorePoint.exists
        storeIsVersioned = presets.isVersioned
    }

    func beginPreview(preset name: String) {
        do {
            beginPreview(text: try presets.read(name), title: name)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func beginPreviewRestorePoint() {
        do {
            beginPreview(text: try restorePoint.text(), title: t("Initial State"))
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func beginPreview(text: String, title: String) {
        do {
            let spec = try ApplySpec.parse(text)
            let plan = ApplyService(registry: registry, writer: writer).plan(spec)
            preview = Preview(title: title, plan: plan, results: nil)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func confirmApply() async {
        guard let plan = preview?.plan else { return }
        let results = await ApplyService(registry: registry, writer: writer).apply(plan)
        preview?.results = results
        reload()
    }

    /// Presets carry the curated catalog only, same as `mda save`. The
    /// discovered long tail is machine state and stays in the restore point.
    var presetText: String {
        snapshot.restricted(to: curated).settingsFileText()
    }

    func savePreset() {
        do {
            try presets.save(presetName, text: presetText)
            savePresetSheet = false
            reload()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func setDefault(_ bundleID: String, for target: QueryTarget) async {
        busy.insert(target.displayString)
        do {
            _ = try await SetService(registry: registry, writer: writer)
                .setDefault(bundleID: bundleID, for: target)
        } catch {
            errorMessage = String(describing: error)
        }
        reload()
        busy.remove(target.displayString)
    }
}
