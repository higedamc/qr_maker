import SwiftUI

struct GeneratorView: View {
    @ObservedObject var viewModel: GeneratorViewModel
    @StateObject private var scannerVM = ScannerViewModel()
    @State private var isScanning = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 12) {
            header
            mainContent
            if !isScanning {
                statusBar
            }
            textInput
            actionButtons
        }
        .padding(16)
        .frame(width: 360)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Text("QR Maker")
                .font(.headline)
            Spacer()

            Button {
                isScanning.toggle()
                if !isScanning { scannerVM.stopScanning() }
            } label: {
                Image(systemName: isScanning ? "qrcode" : "camera.viewfinder")
                    .font(.body)
            }
            .buttonStyle(.borderless)
            .help(isScanning ? "Switch to generator" : "Scan QR code")

            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.body)
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showSettings, arrowEdge: .trailing) {
                ShortcutSettingsView()
            }

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.body)
            }
            .buttonStyle(.borderless)
            .help("Quit QR Maker")
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if isScanning {
            ScannerView(viewModel: scannerVM) { scannedText in
                viewModel.setInputText(scannedText)
                isScanning = false
                scannerVM.stopScanning()
            }
        } else {
            QRCodeImageView(
                page: viewModel.currentQRPage,
                errorMessage: viewModel.errorMessage
            )
        }
    }

    // MARK: - Status Bar (Correction Level + Capacity + Pagination)

    @ViewBuilder
    private var statusBar: some View {
        if !viewModel.pages.isEmpty {
            VStack(spacing: 6) {
                if viewModel.isMultipart {
                    paginationControls
                }
                capacityIndicator
            }
        }
    }

    private var paginationControls: some View {
        HStack(spacing: 12) {
            Button { viewModel.prevPage() } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            Text("\(viewModel.currentPage + 1) / \(viewModel.totalPages)")
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()

            Button { viewModel.nextPage() } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)

            Spacer()

            Button { viewModel.toggleAutoAdvance() } label: {
                Image(systemName: viewModel.isAutoAdvancing ? "pause.fill" : "play.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help(viewModel.isAutoAdvancing ? "Pause auto-advance" : "Auto-advance pages")
        }
    }

    private var capacityIndicator: some View {
        HStack(spacing: 6) {
            if let page = viewModel.currentQRPage {
                Text(page.correctionLevel.label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(badgeColor(for: page.correctionLevel).opacity(0.15))
                    .foregroundStyle(badgeColor(for: page.correctionLevel))
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                ProgressView(value: min(page.capacityRatio, 1.0))
                    .tint(capacityColor(for: page.capacityRatio))

                Text("\(Int(page.capacityRatio * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func capacityColor(for ratio: Double) -> Color {
        switch ratio {
        case ..<0.7: return .accentColor
        case 0.7..<0.9: return .yellow
        default: return .red
        }
    }

    private func badgeColor(for level: CorrectionLevel) -> Color {
        switch level {
        case .H: return .green
        case .Q: return .blue
        case .M: return .orange
        case .L: return .red
        }
    }

    // MARK: - Text Input

    private var textInput: some View {
        TextEditor(text: $viewModel.inputText)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(height: 100)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.pasteFromClipboard()
            } label: {
                Label("Paste", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("v", modifiers: .command)

            Button {
                viewModel.clear()
            } label: {
                Label("Clear", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.inputText.isEmpty)
        }
    }
}
