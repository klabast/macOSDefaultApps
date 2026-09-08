import DefaultAppsCore
import SwiftUI

struct TargetLabel: View {
    let target: QueryTarget

    var body: some View {
        Text(target.displayString)
            .font(.system(.body, design: .monospaced))
            .frame(minWidth: 90, alignment: .leading)
        Text(typeDescription(for: target) ?? "")
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

struct TypeRow: View {
    let store: AppStore
    let entry: SnapshotEntry

    var body: some View {
        HStack(spacing: 12) {
            TargetLabel(target: entry.target)
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

struct AppEntryRow: View {
    let store: AppStore
    let app: AppInfo
    let entry: SnapshotEntry

    private var isDefault: Bool {
        entry.result.defaultApp?.bundleID == app.bundleID
    }

    var body: some View {
        HStack(spacing: 12) {
            TargetLabel(target: entry.target)
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
