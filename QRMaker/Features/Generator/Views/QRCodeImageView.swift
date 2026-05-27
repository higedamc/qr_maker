import SwiftUI

struct QRCodeImageView: View {
    let page: QRCodePage?
    let errorMessage: String?

    var body: some View {
        ZStack {
            if let page {
                Image(nsImage: page.image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else if let errorMessage {
                errorPlaceholder(errorMessage)
            } else {
                emptyPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "qrcode")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Enter text to generate QR code")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorPlaceholder(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
