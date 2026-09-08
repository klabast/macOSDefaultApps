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
                .navigationSplitViewColumnWidth(min: 220, ideal: 280)
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
        .alert(
            t("Update available"),
            isPresented: Binding(
                get: { store.availableUpdate != nil },
                set: { if !$0 { store.availableUpdate = nil } })
        ) {
            Button(t("OK")) {}
                .keyboardShortcut(.defaultAction)
            Button(t("Go to GitHub")) {
                if let page = GitHubReleases.page { NSWorkspace.shared.open(page) }
            }
        } message: {
            Text(
                String(
                    localized: "Version \(store.availableUpdate ?? "") is available, you have \(Version.current).",
                    bundle: .module))
        }
        .task { await store.reload() }
        .task { await store.checkForUpdate() }
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
