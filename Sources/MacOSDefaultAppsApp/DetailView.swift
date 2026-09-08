import DefaultAppsCore
import SwiftUI

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

struct TypeEntriesList: View {
    let store: AppStore

    var body: some View {
        if case .family(let name) = store.selection {
            EntryList(groups: [FamilyGroup(name: name, entries: store.detailEntries)], headers: false) {
                TypeRow(store: store, entry: $0)
            }
        } else {
            EntryList(groups: store.detailEntries.groupedByFamily()) {
                TypeRow(store: store, entry: $0)
            }
        }
    }
}

struct AppEntriesList: View {
    let store: AppStore
    let app: AppInfo

    var body: some View {
        EntryList(groups: [FamilyGroup(name: app.bundleID, entries: store.detailEntries)], headers: false) {
            AppEntryRow(store: store, app: app, entry: $0)
        }
    }
}

struct StatusBar: View {
    let store: AppStore

    var body: some View {
        HStack {
            Text(
                String(
                    localized:
                        "\(store.visible.entries.count) of \(store.snapshot.entries.count) types · \(store.apps.count) apps",
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
