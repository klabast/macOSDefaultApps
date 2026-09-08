import DefaultAppsCore
import SwiftUI

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
                    ForEach(store.visible.entries.groupedByFamily(), id: \.name) { group in
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
