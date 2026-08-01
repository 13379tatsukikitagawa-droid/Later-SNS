import SwiftUI

// MARK: - マイQRコード表示ビュー
/// ユーザーのQRコードを大きく表示するハーフモーダルシート

struct MyQRCodeView: View {
    @Environment(\.dismiss) private var dismiss
    
    // ユーザー情報（@AppStorageから取得）
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userID") private var userID: String = ""
    @AppStorageData("profileImageData") private var profileImageData: Data?
    
    // テーマカラー
    @AppStorage("themeColor") private var themeColorName: String = "green"
    
    // アニメーション用
    @State private var qrCodeOpacity: Double = 0
    @State private var qrCodeScale: CGFloat = 0.8
    @State private var showCopiedMessage = false
    
    // 計算プロパティ: テーマカラー
    private var themeColor: Color {
        switch themeColorName {
        case "green": return .brandGreen
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        default: return .brandGreen
        }
    }
    
    // 計算プロパティ: 表示名
    private var displayName: String {
        userName.isEmpty ? "ゲスト" : userName
    }
    
    // 計算プロパティ: 表示用ユーザーID
    private var displayUserID: String {
        userID.isEmpty ? "guest" : userID
    }
    
    // 計算プロパティ: プロフィール画像
    private var displayProfileImage: UIImage? {
        guard let data = profileImageData else { return nil }
        return UIImage(data: data)
    }
    
    // 計算プロパティ: QRコード用データ
    private var qrData: String {
        QRCodeGenerator.createQRData(userID: displayUserID, userName: displayName)
    }
    
    // 計算プロパティ: QRコード画像
    private var qrCodeImage: UIImage? {
        QRCodeGenerator.generateQRCode(from: qrData, size: 300)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // ヘッダーセクション
                        headerSection
                            .padding(.top, 20)
                        
                        // QRコードセクション
                        qrCodeSection
                            .opacity(qrCodeOpacity)
                            .scaleEffect(qrCodeScale)
                        
                        // 説明テキスト
                        instructionSection
                        
                        // アクションボタン
                        actionButtons
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("マイQRコード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .onAppear {
                // QRコード表示アニメーション
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                    qrCodeOpacity = 1.0
                    qrCodeScale = 1.0
                }
            }
            .overlay {
                // コピー完了メッセージ
                if showCopiedMessage {
                    copiedMessageOverlay
                }
            }
        }
    }
    
    // MARK: - サブビュー
    
    // ヘッダーセクション（プロフィール画像と名前）
    private var headerSection: some View {
        VStack(spacing: 16) {
            // プロフィール画像
            if let uiImage = displayProfileImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [themeColor, themeColor.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: themeColor.opacity(0.3), radius: 15, x: 0, y: 8)
            } else {
                // デフォルト画像
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white.opacity(0.3))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                Color.white.opacity(0.2),
                                style: StrokeStyle(lineWidth: 2, dash: [6, 3])
                            )
                    )
            }
            
            // ユーザー名とID
            VStack(spacing: 6) {
                Text(displayName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("@\(displayUserID)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
    
    // QRコードセクション
    private var qrCodeSection: some View {
        VStack(spacing: 0) {
            // QRコード本体
            if let qrImage = qrCodeImage {
                Image(uiImage: qrImage)
                    .interpolation(.none) // QRコードはピクセルアートなので補間しない
                    .resizable()
                    .scaledToFit()
                    .frame(width: 260, height: 260)
                    .padding(24)
                    .background(
                        // 白背景（QRコードはスキャンしやすくするため白背景）
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        // テーマカラーの枠線
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [themeColor, themeColor.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                    )
                    .shadow(color: themeColor.opacity(0.4), radius: 30, x: 0, y: 15)
                    // 外側のグロー効果
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(themeColor.opacity(0.2), lineWidth: 1)
                            .blur(radius: 10)
                            .offset(y: 5)
                    )
            } else {
                // QRコード生成失敗時のフォールバック
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 260, height: 260)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.3))
                            
                            Text("QRコードを生成できません")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    )
            }
        }
    }
    
    // 説明テキストセクション
    private var instructionSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 18))
                    .foregroundStyle(themeColor)
                
                Text("QRコードをスキャン")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            Text("このQRコードをスキャンすることで\nあなたのプロフィールをフォローできます")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // アクションボタン
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // QRコードを保存ボタン
            saveButton
            
            // IDをコピーボタン
            copyButton
        }
    }
    
    private var saveButton: some View {
        Button {
            saveQRCodeToPhotos()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("QRコードを保存")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [themeColor, themeColor.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: themeColor.opacity(0.4), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(BounceButtonStyle())
    }
    
    private var copyButton: some View {
        Button {
            copyUserIDToClipboard()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("IDをコピー")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white.opacity(0.08))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(BounceButtonStyle())
    }
    
    // コピー完了メッセージ
    private var copiedMessageOverlay: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(themeColor)
                
                Text("IDをコピーしました")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.bottom, 100)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    // MARK: - アクション
    
    // QRコードを写真アルバムに保存
    private func saveQRCodeToPhotos() {
        guard let qrImage = qrCodeImage else {
            print("❌ QRコード画像が生成されていません")
            return
        }
        
        // より大きなサイズでQRコードを生成（保存用）
        guard let highResQRImage = QRCodeGenerator.generateQRCode(from: qrData, size: 1000) else {
            print("❌ 高解像度QRコード生成に失敗しました")
            return
        }
        
        // 写真ライブラリに保存
        UIImageWriteToSavedPhotosAlbum(highResQRImage, nil, nil, nil)
        
        // ハプティクスフィードバック
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        print("✅ QRコードを写真に保存しました")
    }
    
    // ユーザーIDをクリップボードにコピー
    private func copyUserIDToClipboard() {
        UIPasteboard.general.string = displayUserID
        
        // コピー完了メッセージを表示
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showCopiedMessage = true
        }
        
        // 2秒後にメッセージを非表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showCopiedMessage = false
            }
        }
        
        // ハプティクスフィードバック
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        print("✅ ユーザーIDをクリップボードにコピーしました: \(displayUserID)")
    }
}

// MARK: - プレビュー
#Preview {
    MyQRCodeView()
}
