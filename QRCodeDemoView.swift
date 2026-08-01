import SwiftUI

// MARK: - QRコード機能デモビュー
/// QRコードスキャナーと自分のQRコード表示のデモ
struct QRCodeDemoView: View {
    @State private var showingScanner = false
    @State private var showingMyQRCode = false
    @State private var lastScannedCode: String?
    @State private var showingAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // ヘッダー
                        headerSection
                        
                        // QRコード機能の説明
                        featureExplanation
                        
                        // アクションボタン
                        actionButtons
                        
                        // 最後にスキャンしたコード
                        if let code = lastScannedCode {
                            lastScannedSection(code: code)
                        }
                        
                        // 使い方ガイド
                        usageGuide
                    }
                    .padding()
                }
            }
            .navigationTitle("QRコード機能")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showingScanner) {
                QRCodeScannerView { scannedCode in
                    handleScannedCode(scannedCode)
                }
            }
            .sheet(isPresented: $showingMyQRCode) {
                MyQRCodeView()
            }
            .alert("スキャン成功", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                if let code = lastScannedCode {
                    Text("ユーザーID: \(code)\nをスキャンしました！")
                }
            }
        }
    }
    
    // MARK: - サブビュー
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // アイコン
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "qrcode")
                    .font(.system(size: 50))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)
            }
            
            Text("QRコードで簡単に繋がろう")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("カメラでQRコードを読み取って、友達を素早くフォローしよう")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
    }
    
    private var featureExplanation: some View {
        VStack(spacing: 16) {
            FeatureCard(
                icon: "camera.viewfinder",
                iconColor: .blue,
                title: "QRコードをスキャン",
                description: "友達のQRコードをカメラで読み取って、瞬時にフォローできます"
            )
            
            FeatureCard(
                icon: "qrcode",
                iconColor: .green,
                title: "自分のQRコードを表示",
                description: "あなたのQRコードを友達に見せて、簡単にフォローしてもらえます"
            )
            
            FeatureCard(
                icon: "square.and.arrow.up",
                iconColor: .orange,
                title: "QRコードを共有",
                description: "QRコードを画像として保存・共有して、どこでも使えます"
            )
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // スキャンボタン
            Button {
                showingScanner = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.title3.weight(.semibold))
                    
                    Text("QRコードをスキャン")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 4)
            }
            
            // 自分のQRコードボタン
            Button {
                showingMyQRCode = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "qrcode")
                        .font(.title3.weight(.semibold))
                    
                    Text("自分のQRコードを表示")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1.5)
                        )
                )
            }
        }
        .padding(.horizontal)
    }
    
    private func lastScannedSection(code: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("最後にスキャンしたコード", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ユーザーID")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Text(code)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
    
    private var usageGuide: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("使い方ガイド")
                .font(.title3.bold())
                .foregroundStyle(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                GuideStep(
                    number: 1,
                    title: "カメラの許可",
                    description: "初回使用時に、カメラへのアクセスを許可してください"
                )
                
                GuideStep(
                    number: 2,
                    title: "QRコードをスキャン",
                    description: "友達のQRコードをカメラで読み取ります"
                )
                
                GuideStep(
                    number: 3,
                    title: "フォローする",
                    description: "スキャン後、そのユーザーのプロフィールが表示されます"
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal)
    }
    
    // MARK: - メソッド
    
    private func handleScannedCode(_ code: String) {
        lastScannedCode = code
        showingScanner = false
        
        // ハプティクフィードバック
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // アラートを表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingAlert = true
        }
    }
}

// MARK: - 機能カード
private struct FeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // アイコン
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
            }
            
            // テキスト
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal)
    }
}

// MARK: - ガイドステップ
private struct GuideStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 番号バッジ
            Text("\(number)")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            
            // テキスト
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
        }
    }
}

// MARK: - 統合テストビュー
/// QRコード機能とフォロー機能を統合したテストビュー
struct IntegratedQRFollowTestView: View {
    @State private var showingUserSearch = false
    @State private var showingQRScanner = false
    @State private var showingMyQRCode = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("友達と繋がろう")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    
                    Text("3つの方法で友達をフォローできます")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    VStack(spacing: 16) {
                        // QRコードスキャン
                        ActionButton(
                            icon: "qrcode.viewfinder",
                            title: "QRコードをスキャン",
                            subtitle: "カメラで読み取る",
                            color: .blue
                        ) {
                            showingQRScanner = true
                        }
                        
                        // ユーザー検索
                        ActionButton(
                            icon: "magnifyingglass",
                            title: "ユーザーを検索",
                            subtitle: "名前やIDで探す",
                            color: .green
                        ) {
                            showingUserSearch = true
                        }
                        
                        // 自分のQRコード
                        ActionButton(
                            icon: "qrcode",
                            title: "自分のQRコードを表示",
                            subtitle: "友達に見せる",
                            color: .orange
                        ) {
                            showingMyQRCode = true
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingUserSearch) {
                ModernUserSearchView()
            }
            .fullScreenCover(isPresented: $showingQRScanner) {
                QRCodeScannerView { code in
                    print("スキャンされたコード: \(code)")
                    showingQRScanner = false
                }
            }
            .sheet(isPresented: $showingMyQRCode) {
                MyQRCodeView()
            }
        }
    }
}

// MARK: - アクションボタン
private struct ActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // アイコン
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                }
                
                // テキスト
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                // 矢印
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - プレビュー
#Preview("QR Code Demo View") {
    QRCodeDemoView()
}

#Preview("Integrated QR Follow Test") {
    IntegratedQRFollowTestView()
}

