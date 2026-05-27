import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum CorrectionLevel: String, CaseIterable {
    case H, Q, M, L

    /// QR Version 40 max byte capacity (binary mode)
    var maxBytes: Int {
        switch self {
        case .H: return 1273
        case .Q: return 1663
        case .M: return 2331
        case .L: return 2953
        }
    }

    var recoveryPercent: Int {
        switch self {
        case .H: return 30
        case .Q: return 25
        case .M: return 15
        case .L: return 7
        }
    }

    var label: String { "\(rawValue) (\(recoveryPercent)%)" }

    static let preferredOrder: [CorrectionLevel] = [.H, .Q, .M, .L]

    static func bestLevel(forByteCount count: Int) -> CorrectionLevel? {
        preferredOrder.first { count <= $0.maxBytes }
    }
}

struct QRCodePage {
    let image: NSImage
    let correctionLevel: CorrectionLevel
    let capacityRatio: Double
}

struct QRCodeResult {
    let pages: [QRCodePage]
    let totalBytes: Int
    var pageCount: Int { pages.count }
    var isMultipart: Bool { pages.count > 1 }

    var correctionLevel: CorrectionLevel? { pages.first?.correctionLevel }
    var capacityRatio: Double { pages.first?.capacityRatio ?? 0 }
}

enum QRCodeError: LocalizedError {
    case empty
    case generationFailed
    case tooLarge(byteCount: Int)

    var errorDescription: String? {
        switch self {
        case .empty:
            return nil
        case .generationFailed:
            return "Failed to generate QR code"
        case .tooLarge(let byteCount):
            return "Input too large: \(byteCount) bytes (exceeds practical limit)"
        }
    }
}

final class QRCodeService {

    static let shared = QRCodeService()
    static let maxSupportedBytes = maxPages * CorrectionLevel.L.maxBytes

    private static let maxPages = 20

    private let context = CIContext()

    private init() {}

    func generate(from text: String, size: CGFloat = 512) -> Result<QRCodeResult, QRCodeError> {
        let totalBytes = text.lengthOfBytes(using: .utf8)

        guard totalBytes > 0 else {
            return .failure(.empty)
        }

        guard totalBytes <= Self.maxSupportedBytes else {
            return .failure(.tooLarge(byteCount: totalBytes))
        }

        let data = Data(text.utf8)

        if let level = CorrectionLevel.bestLevel(forByteCount: totalBytes) {
            return generateSingle(data: data, level: level, size: size)
        }

        return generateMultipart(data: data, size: size)
    }

    // MARK: - Single QR

    private func generateSingle(
        data: Data, level: CorrectionLevel, size: CGFloat
    ) -> Result<QRCodeResult, QRCodeError> {
        guard let image = renderQR(data: data, level: level, size: size) else {
            return .failure(.generationFailed)
        }

        let ratio = Double(data.count) / Double(level.maxBytes)
        let page = QRCodePage(image: image, correctionLevel: level, capacityRatio: ratio)
        return .success(QRCodeResult(pages: [page], totalBytes: data.count))
    }

    // MARK: - Multi-part QR

    private func generateMultipart(
        data: Data, size: CGFloat
    ) -> Result<QRCodeResult, QRCodeError> {
        let totalBytes = data.count

        for numParts in 2...Self.maxPages {
            let chunkSize = Int(ceil(Double(totalBytes) / Double(numParts)))

            guard let level = CorrectionLevel.bestLevel(forByteCount: chunkSize) else {
                continue
            }

            var pages: [QRCodePage] = []
            var offset = 0
            var success = true

            while offset < totalBytes {
                let end = min(offset + chunkSize, totalBytes)
                let chunk = data[offset..<end]

                guard let image = renderQR(data: chunk, level: level, size: size) else {
                    success = false
                    break
                }

                let ratio = Double(chunk.count) / Double(level.maxBytes)
                pages.append(QRCodePage(image: image, correctionLevel: level, capacityRatio: ratio))
                offset = end
            }

            if success {
                return .success(QRCodeResult(pages: pages, totalBytes: totalBytes))
            }
        }

        return .failure(.tooLarge(byteCount: totalBytes))
    }

    // MARK: - Render

    private func renderQR(data: Data, level: CorrectionLevel, size: CGFloat) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = level.rawValue

        guard let ciImage = filter.outputImage else { return nil }

        let scaleX = size / ciImage.extent.size.width
        let scaleY = size / ciImage.extent.size.height
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }

        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
}
