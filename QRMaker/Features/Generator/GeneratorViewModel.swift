import AppKit
import Combine

final class GeneratorViewModel: ObservableObject {

    @Published var inputText: String = ""
    @Published var pages: [QRCodePage] = []
    @Published var currentPage: Int = 0
    @Published var errorMessage: String?
    @Published var isAutoAdvancing = false

    var totalPages: Int { pages.count }
    var isMultipart: Bool { pages.count > 1 }

    var currentQRPage: QRCodePage? {
        guard currentPage >= 0, currentPage < pages.count else { return nil }
        return pages[currentPage]
    }

    private var cancellables = Set<AnyCancellable>()
    private var autoAdvanceTimer: AnyCancellable?
    private let qrService = QRCodeService.shared

    init() {
        $inputText
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] text in
                self?.generateQR(from: text)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func pasteFromClipboard() {
        if let text = ClipboardService.shared.read(), !text.isEmpty {
            inputText = text
        }
    }

    func clear() {
        inputText = ""
    }

    func nextPage() {
        guard isMultipart else { return }
        currentPage = (currentPage + 1) % totalPages
    }

    func prevPage() {
        guard isMultipart else { return }
        currentPage = (currentPage - 1 + totalPages) % totalPages
    }

    func toggleAutoAdvance() {
        isAutoAdvancing.toggle()
        if isAutoAdvancing {
            startAutoAdvance()
        } else {
            stopAutoAdvance()
        }
    }

    // MARK: - QR Generation

    private func generateQR(from text: String) {
        stopAutoAdvance()
        currentPage = 0

        guard !text.isEmpty else {
            pages = []
            errorMessage = nil
            return
        }

        switch qrService.generate(from: text) {
        case .success(let result):
            pages = result.pages
            errorMessage = nil
        case .failure(let error):
            pages = []
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Auto-advance

    private func startAutoAdvance() {
        guard isMultipart else {
            isAutoAdvancing = false
            return
        }
        autoAdvanceTimer = Timer.publish(every: 0.4, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.nextPage()
            }
    }

    private func stopAutoAdvance() {
        autoAdvanceTimer?.cancel()
        autoAdvanceTimer = nil
        isAutoAdvancing = false
    }
}
