import AppKit
import SwiftUI

extension Notification.Name {
    static let focusFilter = Notification.Name("dev.klabast.macOSDefaultApps.focusFilter")
    static let reloadSnapshot = Notification.Name("dev.klabast.macOSDefaultApps.reload")
    static let switchByType = Notification.Name("dev.klabast.macOSDefaultApps.byType")
    static let switchByApp = Notification.Name("dev.klabast.macOSDefaultApps.byApp")
}

@main
struct MacOSDefaultAppsApp: App {
    init() {
        // Run from a bare executable (swift run) the process starts as an
        // accessory without focus; force a regular, activated app.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("Default Apps") {
            ContentView()
        }
        .commands {
            CommandGroup(after: .textEditing) {
                Button(t("Filter")) { post(.focusFilter) }
                    .keyboardShortcut("f", modifiers: .command)
            }
            CommandGroup(after: .sidebar) {
                Button(t("By Type")) { post(.switchByType) }
                    .keyboardShortcut("1", modifiers: .command)
                Button(t("By App")) { post(.switchByApp) }
                    .keyboardShortcut("2", modifiers: .command)
                Divider()
                Button(t("Reload")) { post(.reloadSnapshot) }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }

    private func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }
}
