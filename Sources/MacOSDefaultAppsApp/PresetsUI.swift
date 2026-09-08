import AppKit
import DefaultAppsCore
import SwiftUI
import UniformTypeIdentifiers

struct PresetsMenu: View {
    @Bindable var store: AppStore

    var body: some View {
        Menu {
            if store.presetNames.isEmpty {
                Text(t("No presets yet"))
            }
            ForEach(store.presetNames, id: \.self) { name in
                Button(name) { store.beginPreview(preset: name) }
            }
            Divider()
            Button(t("Save Current as Preset…")) {
                store.presetName = ""
                store.savePresetSheet = true
            }
            if store.hasRestorePoint {
                Divider()
                Button(t("Restore Initial State…")) { store.beginPreviewRestorePoint() }
            }
            Divider()
            Button(t("Import File…")) { importFile() }
            Button(t("Export…")) { exportFile() }
        } label: {
            Label(t("Presets"), systemImage: "square.stack")
        }
    }

    private func importFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            store.beginPreview(
                text: try String(contentsOf: url, encoding: .utf8),
                title: url.lastPathComponent)
        } catch {
            store.errorMessage = String(describing: error)
        }
    }

    private func exportFile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "defaults.mda"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportText().write(to: url, atomically: true, encoding: .utf8)
        } catch {
            store.errorMessage = String(describing: error)
        }
    }
}

struct PreviewSheet: View {
    let store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            if let preview = store.preview {
                Text(preview.title)
                    .font(.headline)
                    .padding(12)
                Divider()
                List {
                    ForEach(Array(preview.plan.enumerated()), id: \.offset) { index, planned in
                        PlanRow(planned: planned, outcome: preview.results?[index].outcome)
                    }
                }
                Divider()
                footer(preview)
            }
        }
        .frame(width: 520, height: 440)
    }

    private func footer(_ preview: AppStore.Preview) -> some View {
        let changes = preview.plan.count { if case .change = $0.action { true } else { false } }
        let unchanged = preview.plan.count { if case .unchanged = $0.action { true } else { false } }
        let missing = preview.plan.count { $0.action == .missingApp }

        return HStack {
            if changes == 0 && missing == 0 {
                Text(t("Everything already matches."))
                    .foregroundStyle(.secondary)
            } else {
                Text(
                    String(
                        localized: "\(changes) to change · \(unchanged) unchanged · \(missing) missing",
                        bundle: .module)
                )
                .foregroundStyle(.secondary)
            }
            Spacer()
            if preview.results == nil {
                Button(t("Cancel")) { store.preview = nil }
                Button(t("Apply")) { store.confirmApply() }
                    .buttonStyle(.borderedProminent)
                    .disabled(changes == 0)
            } else {
                Button(t("Done")) { store.preview = nil }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
    }
}

struct PlanRow: View {
    let planned: PlannedChange
    let outcome: ApplyOutcome?

    var body: some View {
        HStack(spacing: 10) {
            outcomeIcon
            Text(planned.line.target.displayString)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 80, alignment: .leading)
            Spacer(minLength: 12)
            detail
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder private var outcomeIcon: some View {
        switch outcome {
        case .applied:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .unchanged:
            Image(systemName: "minus.circle").foregroundStyle(.secondary)
        case .skippedMissingApp:
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
        case .failed(let reason):
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red).help(reason)
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder private var detail: some View {
        switch planned.action {
        case .change(let from, let to):
            HStack(spacing: 6) {
                if let from {
                    Text(from.name).foregroundStyle(.secondary)
                }
                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                AppIcon(url: to.url, size: 16)
                Text(to.name)
            }
        case .unchanged(let app):
            HStack(spacing: 6) {
                AppIcon(url: app.url, size: 16)
                Text(app.name).foregroundStyle(.secondary)
            }
        case .missingApp:
            HStack(spacing: 6) {
                Text(planned.line.bundleID).foregroundStyle(.secondary)
                Text(t("not installed")).foregroundStyle(.orange)
            }
        }
    }
}

struct SavePresetSheet: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Save Current as Preset…")).font(.headline)
            TextField(t("Preset name"), text: $store.presetName)
                .frame(width: 260)
                .onSubmit { save() }
            if !store.storeIsVersioned {
                Label(
                    t("~/.mda is not a git repository — saves overwrite without history."),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.callout)
                .foregroundStyle(.orange)
            }
            HStack {
                Spacer()
                Button(t("Cancel")) { store.savePresetSheet = false }
                Button(t("Save")) { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.presetName.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private func save() {
        guard !store.presetName.isEmpty else { return }
        store.savePreset()
    }
}
