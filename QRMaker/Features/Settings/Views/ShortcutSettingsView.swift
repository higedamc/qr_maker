import KeyboardShortcuts
import SwiftUI

struct ShortcutSettingsView: View {
    @AppStorage("autoClipboardImport") private var autoClipboard = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Global Shortcut")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                KeyboardShortcuts.Recorder("", name: .togglePopover)
            }

            Divider()

            Toggle("Auto-paste from clipboard on open", isOn: $autoClipboard)
                .font(.subheadline)
        }
        .padding(16)
        .frame(width: 280)
    }
}
