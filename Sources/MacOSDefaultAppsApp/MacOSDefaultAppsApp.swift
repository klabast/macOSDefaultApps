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
        // bare executables (swift run) start as accessory without focus
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        // the menu cmd-f loses to the system find action; intercept
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                event.charactersIgnoringModifiers == "f" {
                NotificationCenter.default.post(name: .focusFilter, object: nil)
                return nil
            }
            return event
        }
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
