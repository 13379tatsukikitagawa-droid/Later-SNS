import SwiftUI

/// マイQRコード表示ビュー（代替実装）
struct MyQRCodeViewAlt: View {
    let user: UserProfile
    @State private var qrImage: UIImage?
    @State private var showShareSheet = false
    
    var body: some View {
        ZStack {
            // 背景
            Color.brandBlack
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // ヘッダー
                    VStack(spacing: 8) {
                        Text("マイQRコード")
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        
                        Text("友達に読み取ってもらいましょう")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)
                    
                    // QRコードカード
                    qrCodeCard
                    
                    // ユーザー情報
                    userInfoSection
                    
                    // シェアボタン
                    shareButton
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            generateQRCode()
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = qrImage {
                ShareSheetAlt(items: [image])
            }
        }
    }
    
    // MARK: - View Components
    
    private var qrCodeCard: some View {
        VStack(spacing: 0) {
            // QRコード
            ZStack {
                // グロー背景
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.brandGreen.opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 320, height: 320)
                
                // QRコード画像
                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 280, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.brandGreen.opacity(0.5),
                                            Color.brandGreen.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: .brandGreen.opacity(0.3), radius: 20)
                } else {
                    // ローディング
                    ProgressView()
                        .tint(.brandGreen)
                        .frame(width: 280, height: 280)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.brandDarkGray.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private var userInfoSection: some View {
        VStack(spacing: 12) {
            // プロフィールアイコン
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.brandGreen.opacity(0.6),
                                Color.brandGreen.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.9))
            }
            
            // ユーザー名
            VStack(spacing: 4) {
                Text(user.name)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.brandDarkGray.opacity(0.4))
        )
    }
    
    private var shareButton: some View {
        Button(action: {
            showShareSheet = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up")
                    .font(.headline)
                Text("QRコードを共有")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.brandGreen)
            )
            .shadow(color: .brandGreen.opacity(0.3), radius: 10)
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateQRCode() {
        let qrData = QRCodeGenerator.createUserQRData(
            userID: user.id.uuidString,
            userName: user.username
        )
        
        // ロゴ画像を作成（カメラアイコン）
        let logoImage = createLogoImage()
        
        // QRコード生成
        DispatchQueue.global(qos: .userInitiated).async {
            let image = QRCodeGenerator.generateQRCodeWithLogo(
                from: qrData,
                size: 1024,
                logo: logoImage,
                logoSizeRatio: 0.15
            )
            
            DispatchQueue.main.async {
                self.qrImage = image
            }
        }
    }
    
    private func createLogoImage() -> UIImage? {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 背景の円
            let circleRect = CGRect(origin: .zero, size: size)
            context.cgContext.setFillColor(UIColor(red: 0.2, green: 0.8, blue: 0.5, alpha: 1.0).cgColor)
            context.cgContext.fillEllipse(in: circleRect)
            
            // カメラアイコン
            let config = UIImage.SymbolConfiguration(pointSize: 100, weight: .bold)
            if let cameraIcon = UIImage(systemName: "camera.fill", withConfiguration: config) {
                let iconRect = CGRect(x: 50, y: 50, width: 100, height: 100)
                cameraIcon.withTintColor(.white, renderingMode: .alwaysOriginal).draw(in: iconRect)
            }
        }
    }
}

// MARK: - ShareSheet

struct ShareSheetAlt: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview("マイQRコード（代替）") {
    let profile = UserProfile(name: "テストユーザー", username: "testuser")
    MyQRCodeViewAlt(user: profile)
}
