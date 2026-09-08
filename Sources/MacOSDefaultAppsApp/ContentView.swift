import AppKit
import DefaultAppsCore
import SwiftUI

struct ContentView: View {
    @State private var store = AppStore()

    var body: some View {
        // The mode switcher lives in the sidebar, so collapsing it would
        // strand the detail view without context — keep it locked open.
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 190, ideal: 230)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            DetailView(store: store)
        }
        .alert(
            t("Something went wrong"),
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } })
        ) {
            Button(t("OK")) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .sheet(
            isPresented: Binding(
                get: { store.preview != nil },
                set: { if !$0 { store.preview = nil } })
        ) {
            PreviewSheet(store: store)
        }
        .sheet(isPresented: Binding(get: { store.savePresetSheet }, set: { store.savePresetSheet = $0 })) {
            SavePresetSheet(store: store)
        }
        .task { await store.reload() }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            Task { await store.reload() }
        }
        .frame(minWidth: 720, minHeight: 460)
        .onReceive(NotificationCenter.default.publisher(for: .focusFilter)) { _ in
            focusFilterField()
        }
        .onReceive(NotificationCenter.default.publisher(for: .reloadSnapshot)) { _ in
            Task { await store.reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchByType)) { _ in
            store.mode = .byType
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchByApp)) { _ in
            store.mode = .byApp
        }
    }
}

struct SidebarView: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $store.mode) {
                ForEach(AppStore.Mode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)

            List(selection: $store.selection) {
                switch store.mode {
                case .byType:
                    Label(t("All Types"), systemImage: "square.grid.2x2")
                        .tag(SidebarItem.allTypes)
                    ForEach(groupedByFamily(store.visible.entries), id: \.name) { group in
                        Label(tKey(group.name), systemImage: familySymbol(group.name))
                            .badge(group.entries.count)
                            .tag(SidebarItem.family(group.name))
                    }
                case .byApp:
                    ForEach(store.visible.apps(), id: \.bundleID) { app in
                        HStack(spacing: 8) {
                            AppIcon(url: app.url, size: 18)
                            Text(app.name)
                        }
                        .tag(SidebarItem.app(app.bundleID))
                    }
                }
            }
        }
    }
}

struct DetailView: View {
    let store: AppStore

    var body: some View {
        Group {
            if store.loading, store.snapshot.entries.isEmpty {
                ProgressView()
            } else {
                switch store.mode {
                case .byType:
                    TypeEntriesList(store: store)
                case .byApp:
                    if let app = store.selectedApp {
                        AppEntriesList(store: store, app: app)
                    } else {
                        ContentUnavailableView(t("Select an app"), systemImage: "app.dashed")
                    }
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem {
                PresetsMenu(store: store)
            }
            ToolbarItem {
                FilterField(store: store)
            }
            ToolbarItem {
                Button(t("Reload"), systemImage: "arrow.clockwise") { Task { await store.reload() } }
            }
        }
        .safeAreaInset(edge: .bottom) { StatusBar(store: store) }
    }

    private var title: String {
        switch store.selection {
        case .family(let name): tKey(name)
        case .app: store.selectedApp?.name ?? ""
        case .allTypes, nil: t("All Types")
        }
    }
}

struct FilterField: View {
    @Bindable var store: AppStore

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(t("Filter"), text: $store.filter)
                .textFieldStyle(.plain)
                .frame(width: 180)
            if !store.filter.isEmpty {
                Button {
                    store.filter = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }
}

// swiftui can't focus a toolbar text field; grab it from the window chrome
@MainActor
private func focusFilterField() {
    guard let window = NSApp.keyWindow ?? NSApp.windows.first,
        let field = findEditableTextField(in: window.contentView?.superview)
    else { return }
    window.makeFirstResponder(field)
}

@MainActor
private func findEditableTextField(in view: NSView?) -> NSTextField? {
    guard let view else { return nil }
    for subview in view.subviews {
        if let field = subview as? NSTextField, field.isEditable { return field }
        if let found = findEditableTextField(in: subview) { return found }
    }
    return nil
}

struct TypeEntriesList: View {
    let store: AppStore

    var body: some View {
        List {
            if case .family = store.selection {
                ForEach(store.detailEntries, id: \.target.displayString) { entry in
                    TypeRow(store: store, entry: entry)
                }
            } else {
                ForEach(groupedByFamily(store.detailEntries), id: \.name) { group in
                    Section(tKey(group.name)) {
                        ForEach(group.entries, id: \.target.displayString) { entry in
                            TypeRow(store: store, entry: entry)
                        }
                    }
                }
            }
        }
    }
}

struct TypeRow: View {
    let store: AppStore
    let entry: SnapshotEntry

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.target.displayString)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 90, alignment: .leading)
            Text(typeDescription(for: entry.target) ?? "")
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 16)
            if store.busy.contains(entry.target.displayString) {
                ProgressView().controlSize(.small)
            } else {
                HandlerMenu(store: store, entry: entry)
            }
        }
        .padding(.vertical, 5)
    }
}

struct AppEntriesList: View {
    let store: AppStore
    let app: AppInfo

    var body: some View {
        List {
            ForEach(store.detailEntries, id: \.target.displayString) { entry in
                AppEntryRow(store: store, app: app, entry: entry)
            }
        }
    }
}

struct AppEntryRow: View {
    let store: AppStore
    let app: AppInfo
    let entry: SnapshotEntry

    private var isDefault: Bool {
        entry.result.defaultApp?.bundleID == app.bundleID
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.target.displayString)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 90, alignment: .leading)
            Text(typeDescription(for: entry.target) ?? "")
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 16)
            if let current = entry.result.defaultApp {
                HStack(spacing: 6) {
                    AppIcon(url: current.url, size: 16)
                    Text(current.name)
                }
                .foregroundStyle(isDefault ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            }
            if store.busy.contains(entry.target.displayString) {
                ProgressView().controlSize(.small)
            } else if isDefault {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .help(t("Default"))
            } else {
                Button(t("Make Default")) {
                    Task { await store.setDefault(app.bundleID, for: entry.target) }
                }
            }
        }
        .padding(.vertical, 5)
    }
}

struct StatusBar: View {
    let store: AppStore

    var body: some View {
        HStack {
            Text(
                String(
                    localized:
                        "\(store.visible.entries.count) of \(store.snapshot.entries.count) types · \(store.snapshot.apps().count) apps",
                    bundle: .module))
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

func groupedByFamily(_ entries: [SnapshotEntry]) -> [(name: String, entries: [SnapshotEntry])] {
    var groups: [(name: String, entries: [SnapshotEntry])] = []
    for entry in entries {
        if let index = groups.firstIndex(where: { $0.name == entry.family }) {
            groups[index].entries.append(entry)
        } else {
            groups.append((entry.family, [entry]))
        }
    }
    return groups
}

struct AppIcon: View {
    let url: URL
    let size: CGFloat

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .frame(width: size, height: size)
    }
}
