import AppKit
import KeyboardShortcuts
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let viewModel = GeneratorViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        registerShortcut()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "qrcode", accessibilityDescription: "QR Maker")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        let contentView = GeneratorView(viewModel: viewModel)
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }

        let autoClipboard = UserDefaults.standard.bool(forKey: "autoClipboardImport")
        if autoClipboard, let text = ClipboardService.shared.read(), !text.isEmpty {
            viewModel.setInputText(text)
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    // MARK: - Keyboard Shortcut

    private func registerShortcut() {
        KeyboardShortcuts.onKeyUp(for: .togglePopover) { [weak self] in
            self?.togglePopover()
        }
    }
}
