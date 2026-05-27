import SwiftUI

struct ScannerView: View {
    @ObservedObject var viewModel: ScannerViewModel
    var onTextScanned: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            cameraPicker
            cameraPreview
            detectedResult
        }
        .onAppear { viewModel.startScanning() }
        .onDisappear { viewModel.stopScanning() }
    }

    // MARK: - Camera Picker

    @ViewBuilder
    private var cameraPicker: some View {
        if viewModel.availableCameras.count > 1 {
            Picker("Camera", selection: Binding(
                get: { viewModel.selectedCameraID },
                set: { viewModel.switchCamera(to: $0) }
            )) {
                ForEach(viewModel.availableCameras, id: \.uniqueID) { device in
                    Text(device.localizedName).tag(device.uniqueID)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    // MARK: - Camera Preview

    private var cameraPreview: some View {
        ZStack {
            if viewModel.isRunning {
                CameraPreviewView(session: viewModel.session)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Starting camera...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if viewModel.isRunning && viewModel.detectedText.isEmpty {
                scanOverlay
            }
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var scanOverlay: some View {
        RoundedRectangle(cornerRadius: 4)
            .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 2)
            .padding(32)
    }

    // MARK: - Detected Result

    @ViewBuilder
    private var detectedResult: some View {
        if !viewModel.detectedText.isEmpty {
            HStack(spacing: 8) {
                Text(viewModel.detectedText)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Use") {
                    onTextScanned(viewModel.detectedText)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(8)
            .background(Color.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
