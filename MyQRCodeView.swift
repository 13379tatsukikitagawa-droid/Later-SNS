import SwiftUI
import CoreImage.CIFilterBuiltins

struct MyQRCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("userName") private var userName: String = ""

    private var qrData: String {
        // Compose a simple deep-link like string for demonstration
        let id = userID.isEmpty ? "guest" : userID
        let name = userName.isEmpty ? "ゲスト" : userName
        return "laterapp://user?id=\(id)&name=\(name)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("あなたのQRコード")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 260, height: 260)

                        QRCodeView(text: qrData, size: 220)
                    }
                    .shadow(color: Color.brandGreen.opacity(0.3), radius: 16, x: 0, y: 8)

                    VStack(spacing: 4) {
                        Text("@\(userID.isEmpty ? "guest" : userID)")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(userName.isEmpty ? "ゲスト" : userName)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("マイQRコード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - QR Code Image Generator
struct QRCodeView: View {
    let text: String
    let size: CGFloat
    
    var body: some View {
        if let qrImage = generateQRCode(from: text) {
            Image(uiImage: qrImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size, height: size)
                .overlay(
                    Text("QRコード生成エラー")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                )
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        guard let data = string.data(using: .utf8) else { return nil }
        
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        
        guard let ciImage = filter.outputImage else { return nil }
        
        // Scale up the image
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}
#Preview {
    MyQRCodeView()
}


