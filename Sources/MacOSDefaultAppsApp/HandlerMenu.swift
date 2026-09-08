import AppKit
import DefaultAppsCore
import SwiftUI
import UniformTypeIdentifiers

// popover instead of Menu: a Menu can't host the filter text field
struct HandlerMenu: View {
    let store: AppStore
    let entry: SnapshotEntry

    @State private var open = false
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var candidates: [AppInfo] {
        entry.result.candidates.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private var filtered: [AppInfo] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return candidates }
        return candidates.filter {
            $0.name.lowercased().contains(needle) || $0.bundleID.lowercased().contains(needle)
        }
    }

    var body: some View {
        Button {
            open.toggle()
        } label: {
            HStack(spacing: 6) {
                if let app = entry.result.defaultApp {
                    AppIcon(url: app.url, size: 16)
                    Text(app.name)
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open, arrowEdge: .bottom) { picker }
    }

    private var picker: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(t("Filter"), text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit {
                        // field is auto-focused; a stray return must not pick an app
                        guard !query.trimmingCharacters(in: .whitespaces).isEmpty,
                            let first = filtered.first
                        else { return }
                        choose(first)
                    }
            }
            .padding(8)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(filtered, id: \.bundleID) { app in
                        CandidateRow(
                            app: app,
                            isDefault: app == entry.result.defaultApp
                        ) {
                            choose(app)
                        }
                    }
                }
                .padding(4)
            }
            .frame(maxHeight: 280)

            Divider()

            Button(t("Other…")) { chooseOther() }
                .buttonStyle(.plain)
                .padding(8)
        }
        .frame(width: 260)
        .onAppear {
            query = ""
            searchFocused = true
        }
    }

    private func choose(_ app: AppInfo) {
        open = false
        Task { await store.setDefault(app.bundleID, for: entry.target) }
    }

    private func chooseOther() {
        open = false
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(filePath: "/Applications")
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundleID = Bundle(url: url)?.bundleIdentifier else {
            store.errorMessage = String(
                localized: "'\(url.lastPathComponent)' has no bundle identifier", bundle: .module)
            return
        }
        Task { await store.setDefault(bundleID, for: entry.target) }
    }
}

private struct CandidateRow: View {
    let app: AppInfo
    let isDefault: Bool
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                AppIcon(url: app.url, size: 18)
                Text(app.name).lineLimit(1)
                Spacer(minLength: 8)
                if isDefault {
                    Image(systemName: "checkmark").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            hovered ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear),
            in: RoundedRectangle(cornerRadius: 5)
        )
        .onHover { hovered = $0 }
    }
}
