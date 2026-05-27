import SwiftUI

@main
struct QRMakerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            ShortcutSettingsView()
        }
    }
}
