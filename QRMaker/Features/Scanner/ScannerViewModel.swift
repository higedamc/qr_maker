import AVFoundation
import Combine

final class ScannerViewModel: NSObject, ObservableObject {

    @Published var detectedText: String = ""
    @Published var isRunning = false
    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var selectedCameraID: String = ""
    @Published var errorMessage: String?

    let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()

    override init() {
        super.init()
        loadCameras()
    }

    // MARK: - Camera Discovery

    func loadCameras() {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 14.0, *) {
            deviceTypes.append(.external)
            deviceTypes.append(.continuityCamera)
        } else {
            deviceTypes.append(.externalUnknown)
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        availableCameras = discovery.devices

        if selectedCameraID.isEmpty || !availableCameras.contains(where: { $0.uniqueID == selectedCameraID }) {
            selectedCameraID = availableCameras.first?.uniqueID ?? ""
        }
    }

    var selectedCamera: AVCaptureDevice? {
        availableCameras.first { $0.uniqueID == selectedCameraID }
    }

    // MARK: - Session Control

    func startScanning() {
        guard !isRunning else { return }
        loadCameras()

        guard let camera = selectedCamera else {
            errorMessage = "No camera available"
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: camera) else {
            errorMessage = "Cannot access camera: \(camera.localizedName)"
            return
        }

        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(metadataOutput) { session.addOutput(metadataOutput) }

        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
            metadataOutput.metadataObjectTypes = [.qr]
        }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async {
                self?.isRunning = true
                self?.errorMessage = nil
            }
        }
    }

    func stopScanning() {
        guard isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.detectedText = ""
            }
        }
    }

    func switchCamera(to id: String) {
        selectedCameraID = id
        if isRunning {
            stopScanning()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.startScanning()
            }
        }
    }
}

// MARK: - QR Detection

extension ScannerViewModel: AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue,
              value != detectedText
        else { return }

        detectedText = value
    }
}
