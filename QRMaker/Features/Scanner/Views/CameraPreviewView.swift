import AVFoundation
import SwiftUI

struct CameraPreviewView: NSViewRepresentable {

    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraHostingView {
        CameraHostingView(session: session)
    }

    func updateNSView(_ nsView: CameraHostingView, context: Context) {}
}

final class CameraHostingView: NSView {

    private let previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        previewLayer.videoGravity = .resizeAspectFill
        layer = previewLayer
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}
