import SwiftUI
import SwiftData

// MARK: - 📅 Today画面（一括解禁システム統合版）
/// 1日の撮影目標と一括解禁の状態を管理するメイン画面

struct SecretTodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LaterPhoto.captureDate, order: .reverse) private var allPhotos: [LaterPhoto]
    
    @AppStorage("dailyGoal") private var dailyGoal: Int = 3
    @AppStorage("userName") private var userName: String = ""
    
    @State private var sessionManager = DailyPhotoSessionManager.shared
    @State private var showingCamera = false
    @State private var showingGallery = false
    @State private var showingGoalSettings = false
    @State private var currentDate = Date()
    
    // タイマーで定期的に更新
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // 今日の写真
    private var todayPhotos: [LaterPhoto] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return allPhotos.filter { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: today)
        }
    }
    
    // 今日の撮影枚数
    private var todayPhotoCount: Int {
        todayPhotos.count
    }
    
    // 目標達成度
    private var goalProgress: Double {
        Double(todayPhotoCount) / Double(dailyGoal)
    }
    
    // 目標達成済みか
    private var isGoalAchieved: Bool {
        todayPhotoCount >= dailyGoal
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // ウェルカムヘッダー
                        welcomeHeader
                            .padding(.top, 20)
                        
                        // 目標カード
                        goalCard
                        
                        // セッション状態カード
                        sessionStatusCard
                        
                        // アクションボタン
                        actionButtons
                        
                        // 今日の写真プレビュー
                        if !todayPhotos.isEmpty {
                            todayPhotosSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingGoalSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(.white)
                    }
                }
            }
            .onReceive(timer) { _ in
                currentDate = Date()
            }
            .sheet(isPresented: $showingCamera) {
                SecretCameraView()
            }
            .sheet(isPresented: $showingGallery) {
                SecretPhotoGalleryView()
            }
            .sheet(isPresented: $showingGoalSettings) {
                GoalSettingsView(dailyGoal: $dailyGoal)
            }
        }
    }
    
    // MARK: - ウェルカムヘッダー
    
    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greetingMessage)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
            
            Text(currentDateText)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<12:
            return "おはよう\(userName.isEmpty ? "" : "、\(userName)さん")"
        case 12..<18:
            return "こんにちは\(userName.isEmpty ? "" : "、\(userName)さん")"
        default:
            return "こんばんは\(userName.isEmpty ? "" : "、\(userName)さん")"
        }
    }
    
    private var currentDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日（E）"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: Date())
    }
    
    // MARK: - 目標カード
    
    private var goalCard: some View {
        VStack(spacing: 20) {
            // タイトル
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 20))
                    .foregroundStyle(.brandGreen)
                
                Text("今日の目標")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                // 目標枚数バッジ
                Text("\(dailyGoal)枚")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.brandGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.brandGreen.opacity(0.15))
                    )
            }
            
            // 進捗リング
            ZStack {
                // 背景リング
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 140, height: 140)
                
                // 進捗リング
                Circle()
                    .trim(from: 0, to: min(goalProgress, 1.0))
                    .stroke(
                        LinearGradient(
                            colors: [.brandGreen, .brandGreen.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: goalProgress)
                
                // 中央のテキスト
                VStack(spacing: 4) {
                    Text("\(todayPhotoCount)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    
                    Text("/ \(dailyGoal)")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            
            // ステータステキスト
            statusText
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    isGoalAchieved ? Color.brandGreen.opacity(0.3) : Color.white.opacity(0.1),
                    lineWidth: 1.5
                )
        )
    }
    
    private var statusText: some View {
        HStack(spacing: 8) {
            Image(systemName: isGoalAchieved ? "checkmark.circle.fill" : "camera.fill")
                .font(.system(size: 16))
                .foregroundStyle(isGoalAchieved ? .green : .brandGreen)
            
            Text(isGoalAchieved ? "目標達成！" : "残り\(dailyGoal - todayPhotoCount)枚")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isGoalAchieved ? Color.green.opacity(0.15) : Color.brandGreen.opacity(0.15))
        )
    }
    
    // MARK: - セッション状態カード
    
    private var sessionStatusCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                // ステータスアイコン
                ZStack {
                    Circle()
                        .fill(sessionManager.statusColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: sessionManager.statusIcon)
                        .font(.system(size: 22))
                        .foregroundStyle(sessionManager.statusColor)
                }
                
                // ステータステキスト
                VStack(alignment: .leading, spacing: 4) {
                    Text(sessionManager.statusMessage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    if sessionManager.isSessionLocked && !sessionManager.arePhotosUnlocked() {
                        Text(sessionManager.developmentMessage)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    } else if sessionManager.arePhotosUnlocked() {
                        Text("写真を確認できます")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                    }
                }
                
                Spacer()
            }
            
            // 現像進行度バー（現像中のみ）
            if sessionManager.isSessionLocked && !sessionManager.arePhotosUnlocked() {
                developmentProgressView
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(sessionManager.statusColor.opacity(0.3), lineWidth: 1.5)
        )
    }
    
    // 現像進行度ビュー
    private var developmentProgressView: some View {
        VStack(spacing: 10) {
            // プログレスバー
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [sessionManager.statusColor, sessionManager.statusColor.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * sessionManager.unlockProgress(),
                            height: 6
                        )
                        .animation(.linear(duration: 1.0), value: sessionManager.unlockProgress())
                }
            }
            .frame(height: 6)
            
            // ステータステキスト
            HStack {
                Image(systemName: "hourglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                Text("写真を現像しています...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // 進行段階
                let progress = sessionManager.unlockProgress()
                let stage = progress < 0.33 ? "初期" : progress < 0.66 ? "中期" : "後期"
                
                Text(stage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(sessionManager.statusColor)
            }
        }
    }
    
    // MARK: - アクションボタン
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // カメラボタン
            if !isGoalAchieved {
                cameraButton
            }
            
            // ギャラリーボタン
            galleryButton
        }
    }
    
    private var cameraButton: some View {
        Button {
            showingCamera = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("写真を撮る")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [.brandGreen, .brandGreen.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .brandGreen.opacity(0.4), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(BounceButtonStyle())
    }
    
    private var galleryButton: some View {
        Button {
            showingGallery = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("写真を見る")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                // 写真枚数バッジ
                if todayPhotoCount > 0 {
                    Text("\(todayPhotoCount)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(sessionManager.statusColor)
                        )
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(BounceButtonStyle())
    }
    
    // MARK: - 今日の写真プレビュー
    
    private var todayPhotosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // セクションヘッダー
            HStack {
                Text("今日の写真")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    showingGallery = true
                } label: {
                    Text("すべて見る")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.brandGreen)
                }
            }
            
            // 写真プレビュー（最大3枚）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(todayPhotos.prefix(3)) { photo in
                        PhotoThumbnailView(
                            photo: photo,
                            isUnlocked: sessionManager.arePhotosUnlocked()
                        )
                    }
                }
            }
        }
    }
}

// MARK: - 写真サムネイルビュー

struct PhotoThumbnailView: View {
    let photo: LaterPhoto
    let isUnlocked: Bool
    
    var body: some View {
        ZStack {
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipped()
                    .blur(radius: isUnlocked ? 0 : 10)
                    .grayscale(isUnlocked ? 0 : 0.8)
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(isUnlocked ? 0 : 0.35))
                    )
            }
            
            if !isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - 目標設定ビュー

struct GoalSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var dailyGoal: Int
    
    let goalOptions = [1, 2, 3, 4, 5]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // 説明
                    VStack(spacing: 12) {
                        Text("1日の撮影目標")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        
                        Text("毎日何枚の写真を撮影しますか？")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // 選択肢
                    VStack(spacing: 12) {
                        ForEach(goalOptions, id: \.self) { option in
                            Button {
                                dailyGoal = option
                            } label: {
                                HStack {
                                    Text("\(option)枚")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                    
                                    Spacer()
                                    
                                    if dailyGoal == option {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.brandGreen)
                                    } else {
                                        Circle()
                                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                                            .frame(width: 24, height: 24)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(dailyGoal == option ? Color.brandGreen.opacity(0.15) : Color.white.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(
                                            dailyGoal == option ? Color.brandGreen.opacity(0.5) : Color.white.opacity(0.1),
                                            lineWidth: 1.5
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
            }
            .navigationTitle("目標設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .foregroundStyle(.brandGreen)
                }
            }
        }
    }
}

// MARK: - プレビュー
#Preview {
    SecretTodayView()
}
