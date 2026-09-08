import AppKit
import AVFoundation
import Combine

final class ScannerViewModel: NSObject, ObservableObject {

    private enum DefaultsKey {
        static let preferredCameraID = "scanner.preferredCameraID"
        static let preferredCameraName = "scanner.preferredCameraName"
        static let cameraAutoSelectDenyList = "scanner.cameraAutoSelectDenyList"
    }

    @Published var detectedText: String = ""
    @Published var isRunning = false
    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var selectedCameraID: String = ""
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published private(set) var isCameraAccessDenied = false
    @Published private(set) var isSearchingForPreferredCamera = false
    @Published private(set) var preferredCameraID: String?
    @Published private(set) var preferredCameraName: String?

    let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private var deviceObservers: [NSObjectProtocol] = []

    private static let reconnectAttempts = 6
    private static let reconnectInterval: TimeInterval = 1.0

    override init() {
        super.init()
        preferredCameraID = UserDefaults.standard.string(forKey: DefaultsKey.preferredCameraID)
        preferredCameraName = UserDefaults.standard.string(forKey: DefaultsKey.preferredCameraName)
        loadCameras()
        observeDeviceChanges()
    }

    deinit {
        deviceObservers.forEach(NotificationCenter.default.removeObserver)
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
            if let preferredID = preferredCameraID,
               availableCameras.contains(where: { $0.uniqueID == preferredID }) {
                selectedCameraID = preferredID
            } else {
                selectedCameraID = availableCameras.first(where: isAutoSelectable)?.uniqueID ?? ""
            }
        }
    }

    /// Virtual cameras (e.g. OBS Virtual Camera) enumerate before physical
    /// ones and would win automatic selection. Deny-listed names are never
    /// auto-selected or remembered — picking them manually still works.
    private var autoSelectDenyList: [String] {
        UserDefaults.standard.stringArray(forKey: DefaultsKey.cameraAutoSelectDenyList) ?? ["OBS"]
    }

    private func isAutoSelectable(_ device: AVCaptureDevice) -> Bool {
        let name = device.localizedName.lowercased()
        return !autoSelectDenyList.contains { name.contains($0.lowercased()) }
    }

    var selectedCamera: AVCaptureDevice? {
        availableCameras.first { $0.uniqueID == selectedCameraID }
    }

    var isPreferredCameraAvailable: Bool {
        guard let preferredID = preferredCameraID else { return false }
        return availableCameras.contains { $0.uniqueID == preferredID }
    }

    // MARK: - Preferred Camera

    private func rememberPreferredCamera(_ device: AVCaptureDevice) {
        guard isAutoSelectable(device) else { return }
        preferredCameraID = device.uniqueID
        preferredCameraName = device.localizedName
        UserDefaults.standard.set(device.uniqueID, forKey: DefaultsKey.preferredCameraID)
        UserDefaults.standard.set(device.localizedName, forKey: DefaultsKey.preferredCameraName)
        AVCaptureDevice.userPreferredCamera = device
    }

    /// Re-runs discovery for a few seconds and switches to the remembered
    /// camera as soon as it shows up. Continuity Camera discovery can be slow
    /// or flaky when a VPN (e.g. Tailscale) is active, so a one-shot check is
    /// not enough.
    func reconnectPreferredCamera() {
        guard !isSearchingForPreferredCamera else { return }
        guard preferredCameraID != nil else {
            loadCameras()
            return
        }
        isSearchingForPreferredCamera = true
        statusMessage = "Searching for \(preferredCameraName ?? "camera")..."
        attemptReconnect(attemptsLeft: Self.reconnectAttempts)
    }

    private func attemptReconnect(attemptsLeft: Int) {
        guard isSearchingForPreferredCamera else { return }
        loadCameras()

        if let preferredID = preferredCameraID, isPreferredCameraAvailable {
            isSearchingForPreferredCamera = false
            statusMessage = nil
            switchCamera(to: preferredID, rememberChoice: false)
            if !isRunning { startScanning() }
            return
        }

        guard attemptsLeft > 1 else {
            isSearchingForPreferredCamera = false
            statusMessage = "\(preferredCameraName ?? "Camera") not found. Unlock your iPhone and keep Wi-Fi/Bluetooth on."
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reconnectInterval) { [weak self] in
            self?.attemptReconnect(attemptsLeft: attemptsLeft - 1)
        }
    }

    private func cancelReconnectSearch() {
        guard isSearchingForPreferredCamera else { return }
        isSearchingForPreferredCamera = false
        statusMessage = nil
    }

    // MARK: - Device Hotplug

    private func observeDeviceChanges() {
        let center = NotificationCenter.default
        deviceObservers.append(center.addObserver(
            forName: .AVCaptureDeviceWasConnected, object: nil, queue: .main
        ) { [weak self] note in
            guard let device = note.object as? AVCaptureDevice, device.hasMediaType(.video) else { return }
            self?.handleDeviceConnected(device)
        })
        deviceObservers.append(center.addObserver(
            forName: .AVCaptureDeviceWasDisconnected, object: nil, queue: .main
        ) { [weak self] note in
            guard let device = note.object as? AVCaptureDevice, device.hasMediaType(.video) else { return }
            self?.handleDeviceDisconnected(device)
        })
    }

    private func handleDeviceConnected(_ device: AVCaptureDevice) {
        loadCameras()
        guard device.uniqueID == preferredCameraID, selectedCameraID != device.uniqueID else { return }
        cancelReconnectSearch()
        statusMessage = nil
        switchCamera(to: device.uniqueID, rememberChoice: false)
    }

    private func handleDeviceDisconnected(_ device: AVCaptureDevice) {
        let wasSelected = device.uniqueID == selectedCameraID
        if wasSelected { selectedCameraID = "" }
        loadCameras()
        guard wasSelected, isRunning else { return }

        if selectedCameraID.isEmpty {
            stopScanning()
            errorMessage = "\(device.localizedName) disconnected"
        } else {
            switchCamera(to: selectedCameraID, rememberChoice: false)
        }
    }

    // MARK: - Camera Permission

    /// Resolves camera permission before any capture starts. First launch
    /// (.notDetermined) triggers the system prompt automatically; a previous
    /// denial cannot be re-prompted, so the user is pointed to System Settings.
    private func ensureCameraAccess(then proceed: @escaping () -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraAccessDenied = false
            proceed()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isCameraAccessDenied = !granted
                    if granted {
                        proceed()
                    } else {
                        self.errorMessage = "Camera access was denied"
                    }
                }
            }
        default:
            isCameraAccessDenied = true
            errorMessage = "Camera access is denied. Allow QRMaker in System Settings > Privacy & Security > Camera."
        }
    }

    func openCameraPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Session Control

    func startScanning() {
        ensureCameraAccess { [weak self] in
            self?.startScanningAuthorized()
        }
    }

    private func startScanningAuthorized() {
        guard !isRunning else { return }
        loadCameras()

        // The remembered camera (typically the iPhone) is not visible yet —
        // keep looking for it in the background while scanning starts on
        // whatever camera is available now.
        if preferredCameraID != nil, !isPreferredCameraAvailable {
            reconnectPreferredCamera()
        }

        guard let camera = selectedCamera else {
            errorMessage = availableCameras.isEmpty
                ? "No camera available"
                : "Select a camera to start scanning"
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

    func stopScanning(cancelSearch: Bool = true) {
        if cancelSearch { cancelReconnectSearch() }
        guard isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.detectedText = ""
            }
        }
    }

    func switchCamera(to id: String, rememberChoice: Bool = true) {
        selectedCameraID = id
        if rememberChoice, let device = availableCameras.first(where: { $0.uniqueID == id }) {
            rememberPreferredCamera(device)
        }
        if isRunning {
            stopScanning(cancelSearch: false)
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
