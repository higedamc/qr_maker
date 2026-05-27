import AppKit

final class ClipboardService {

    static let shared = ClipboardService()

    private init() {}

    func read() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    func write(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
