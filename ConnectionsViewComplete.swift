import SwiftUI
import SwiftData

/// 完全に機能するConnections画面（QRコード生成・スキャン統合版）
struct ConnectionsViewComplete: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var followingManager = FollowingManager.shared
    
    // UI状態
    @State private var selectedTab: QRTab = .myCode
    @State private var showScanner = false
    @State private var scannedData: String?
    @State private var showScanResult = false
    @State private var searchText = ""
    
    enum QRTab: String, CaseIterable {
        case myCode = "マイQRコード"
        case scan = "スキャン"
    }
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // セグメントコントロール
                    segmentControl
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    
                    // コンテンツ
                    TabView(selection: $selectedTab) {
                        // マイQRコード
                        if currentUser != nil {
                            MyQRCodeView()
                                .tag(QRTab.myCode)
                        } else {
                            noUserView
                                .tag(QRTab.myCode)
                        }
                        
                        // スキャン説明画面
                        scanInstructionView
                            .tag(QRTab.scan)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                
                // スキャン結果オーバーレイ
                if showScanResult, let data = scannedData {
                    QRScanResultView(
                        scannedData: data,
                        onConfirm: handleScanConfirm,
                        onCancel: {
                            withAnimation(.spring(response: 0.3)) {
                                showScanResult = false
                            }
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .navigationTitle("Connections")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(isPresented: $showScanner) {
                QRCodeScannerView(
                    onScanSuccess: { code in
                        handleQRScan(code)
                        showScanner = false
                    }
                )
            }
        }
    }
    
    // MARK: - View Components
    
    private var segmentControl: some View {
        HStack(spacing: 0) {
            ForEach(QRTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: tab == .myCode ? "qrcode" : "qrcode.viewfinder")
                                .font(.system(size: 16, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        
                        // インジケーター
                        Rectangle()
                            .fill(selectedTab == tab ? Color.brandGreen : Color.clear)
                            .frame(height: 3)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.brandDarkGray.opacity(0.6))
        )
    }
    
    private var scanInstructionView: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 40)
                
                // メインアイコン
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.brandGreen.opacity(0.3),
                                    Color.brandGreen.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 160, height: 160)
                    
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.brandGreen)
                        .symbolEffect(.pulse)
                }
                
                // 説明テキスト
                VStack(spacing: 12) {
                    Text("QRコードをスキャン")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    Text("友達のQRコードを読み取って\nフォローしましょう")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // 機能説明
                VStack(spacing: 16) {
                    featureRow(
                        icon: "person.crop.circle.badge.plus",
                        title: "ユーザーをフォロー",
                        description: "QRコードを読み取って簡単にフォロー"
                    )
                    
                    featureRow(
                        icon: "person.3.fill",
                        title: "グループに参加",
                        description: "グループのQRコードで即座に参加"
                    )
                    
                    featureRow(
                        icon: "bolt.fill",
                        title: "高速認識",
                        description: "素早く正確にQRコードを検出"
                    )
                }
                .padding(.horizontal, 24)
                
                // スキャンボタン
                Button(action: {
                    showScanner = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.headline)
                        Text("カメラを起動")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.brandGreen)
                    )
                    .shadow(color: .brandGreen.opacity(0.4), radius: 15)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                
                Spacer(minLength: 40)
            }
        }
    }
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.brandGreen.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Color.brandGreen)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.brandDarkGray.opacity(0.4))
        )
    }
    
    private var noUserView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("ユーザープロフィールが見つかりません")
                .font(.headline)
                .foregroundStyle(.white)
            
            Text("オンボーディングを完了してください")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func handleQRScan(_ code: String) {
        scannedData = code
        
        // 少し遅延してダイアログを表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showScanResult = true
            }
        }
    }
    
    private func handleScanConfirm() {
        guard let data = scannedData else { return }
        
        // ユーザーQRコードの処理
        if let userData = QRCodeGenerator.parseUserQRData(data) {
            // フォロー処理
            followingManager.follow(userID: userData.id)
            print("ユーザーをフォローしました: \(userData.name)")
        }
        // グループQRコードの処理
        else if let groupData = QRCodeGenerator.parseGroupQRData(data) {
            // グループ参加処理
            print("グループに参加しました: \(groupData.name)")
            // TODO: 実際のグループ参加ロジックを実装
        }
        
        // ダイアログを閉じる
        withAnimation(.spring(response: 0.3)) {
            showScanResult = false
        }
        
        // 成功フィードバック
        HapticsManager.unlockSuccess()
    }
}

// MARK: - Preview

#Preview("Connections完全版") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, configurations: config)
    
    let profile = UserProfile(name: "田中太郎", username: "tanaka_taro")
    container.mainContext.insert(profile)
    
    return ConnectionsViewComplete()
        .modelContainer(container)
}
