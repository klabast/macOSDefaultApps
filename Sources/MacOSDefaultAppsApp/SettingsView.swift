import DefaultAppsCore
import SwiftUI

struct SettingsView: View {
    @AppStorage(AppStore.checkForUpdatesKey) private var checkForUpdates = false
    private let brewManaged = Homebrew.managesApp()

    var body: some View {
        Form {
            if brewManaged {
                Text(t("Installed with Homebrew: brew upgrade updates the app."))
            } else {
                Toggle(t("Check GitHub for updates at launch"), isOn: $checkForUpdates)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
