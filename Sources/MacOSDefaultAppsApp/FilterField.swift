import AppKit
import SwiftUI

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
func focusFilterField() {
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
