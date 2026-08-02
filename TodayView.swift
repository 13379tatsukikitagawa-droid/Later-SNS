import SwiftUI
import SwiftData
import AVFoundation

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @State private var showingCamera = false
    @State private var showSuccessMessage = false
    @State private var showMissionAccomplished = false
    @State private var showDailyGoalLock = false
    @State private var justCompletedGoal = false
    @State private var pendingImageData: Data?
    @State private var showCaptionPrompt = false
    
    private let photoManager = PhotoManager.shared

    @AppStorage("dailyGoal") private var dailyGoal: Int = 5
    @AppStorage("countdownStartDate") private var countdownStartDate: String = ""
    @AppStorage("lastGoalSettingDate") private var lastGoalSettingDate: String = ""
    @State private var showDayFinishedAlert = false
    
    @Query private var profiles: [UserProfile]

    private var isGoalSetToday: Bool {
        let today = CountdownBanner.todayKey()
        return lastGoalSettingDate == today && dailyGoal > 0
    }
    
    private var isGoalAchieved: Bool {
        photoManager.isGoalAchieved
    }
    
    // 今日のロック状態をチェック
    private var isCameraLockedToday: Bool {
        photoManager.isLockedToday
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 🎯 目標未設定時：目標設定画面を表示
                    if !isGoalSetToday {
                        DailyGoalSelector {
                            // 目標設定完了後にカメラを自動起動
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showingCamera = true
                            }
                        }
                    } else {
                        // 🎯 目標設定済み：カウントダウンとミッション画面
                        missionContent
                    }
                }
            }
            .navigationTitle("Today's Mission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 右上に進捗バッジを常時表示
                if isGoalSetToday {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        GoalProgressBadge(
                            current: photoManager.todayPhotoCount,
                            goal: photoManager.dailyLimit
                        )
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                TrueBlindCameraView { imageData in
                    pendingImageData = imageData
                    showingCamera = false
                }
                .ignoresSafeArea()
            }
            .onChange(of: showingCamera) { _, isShowing in
                if !isShowing, pendingImageData != nil {
                    showCaptionPrompt = true
                }
            }
            .fullScreenCover(isPresented: $showCaptionPrompt) {
                CaptionEntryPromptView { caption in
                    if let imageData = pendingImageData {
                        savePhoto(imageData, caption: caption)
                    }
                    pendingImageData = nil
                    showCaptionPrompt = false
                }
            }
            .overlay {
                if showSuccessMessage {
                    successMessageOverlay
                }
            }
            .overlay {
                if showMissionAccomplished {
                    MissionAccomplishedView(
                        photosTaken: photoManager.todayPhotoCount,
                        goal: photoManager.dailyLimit
                    ) {
                        showMissionAccomplished = false
                    }
                }
            }
            .overlay {
                // 🔒 新しい：目標達成時のロック演出
                if showDailyGoalLock {
                    SimpleLockOverlay(
                        photosTaken: photoManager.todayPhotoCount,
                        goal: photoManager.dailyLimit
                    ) {
                        showDailyGoalLock = false
                        // 演出終了後にミッション達成画面を表示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showMissionAccomplished = true
                        }
                    }
                }
            }
            .alert("本日のカウントダウンが終了しました", isPresented: $showDayFinishedAlert) {
                Button("OK") {
                    showDayFinishedAlert = false
                }
            } message: {
                let messageText = isGoalAchieved 
                    ? "おめでとうございます！目標を達成しました。" 
                    : "今日は目標未達でした。明日も頑張りましょう。"
                return Text(messageText)
            }
            .onChange(of: photoManager.todayPhotoCount) { oldValue, newValue in
                // 🔒 目標達成の瞬間を検知
                if photoManager.isGoalAchieved && !justCompletedGoal {
                    justCompletedGoal = true
                    
                    // ロック演出を表示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            showDailyGoalLock = true
                        }
                    }
                }
            }
            .onAppear {
                photoManager.syncDailyLimit(from: UserProfile.current(from: profiles))
                photoManager.resetIfNewDay()
            }
        }
    }
    
    // MARK: - ミッション画面コンテンツ
    private var missionContent: some View {
        VStack(spacing: 20) {
            // 📅 カウントダウンタイマー（最上部）
            CountdownBanner {
                // 24時間経過時の処理
                showDayFinishedAlert = true
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Spacer()
            
            // ミッション説明
            VStack(spacing: 12) {
                Text("今日のミッション")
                    .font(.title.weight(.heavy))
                    .foregroundStyle(.white)
                
                Text("今この瞬間を切り取ろう。\n写真はプレビューされず、直接封印されます。")
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal)
            
            Spacer()
            
            // 📸 撮影ボタン
            if isCameraLockedToday {
                // 🔒 完全にロック済み：何もできない状態
                lockedCameraView
            } else if isGoalAchieved {
                // 目標達成済み（ロック処理中または確認中）
                achievedCameraView
            } else {
                // 目標未達成：撮影ボタン有効
                activeCameraView
            }
            
            Spacer()
        }
        .onAppear {
            autoUnlockPhotos()
        }
    }
    
    // MARK: - カメラビュー（状態別）
    
    /// 🔒 完全ロック状態のビュー
    private var lockedCameraView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            
            VStack(spacing: 8) {
                Text("今日の撮影は完了しました")
                    .foregroundStyle(.white)
                    .font(.headline.weight(.bold))
                
                Text("目標 \(dailyGoal) 枚を達成したため、\n本日の撮影機能はロックされています")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.6))
                    .font(.subheadline)
                
                Text("解禁までお楽しみに...")
                    .foregroundStyle(Color.brandGreen.opacity(0.8))
                    .font(.caption.weight(.semibold))
                    .padding(.top, 4)
            }
            .padding(.horizontal)
        }
    }
    
    /// ✅ 達成済み（まだロックされていない）
    private var achievedCameraView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.brandGreen)
            }
            
            Text("今日の目標を達成しました！")
                .foregroundStyle(Color.brandGreen)
                .font(.headline.weight(.bold))
            
            Button {
                showMissionAccomplished = true
            } label: {
                Text("達成状況を見る")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }
    
    /// 📸 撮影可能状態
    private var activeCameraView: some View {
        VStack(spacing: 16) {
            Button(action: { 
                if !isCameraLockedToday {
                    showingCamera = true
                }
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.brandGreen, Color.brandGreen.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.brandGreen.opacity(0.4), radius: 20, x: 0, y: 10)
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isCameraLockedToday)
            
            Text("タップして撮影")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
    
    // MARK: - 成功メッセージオーバーレイ
    private var successMessageOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.brandGreen)
                Text("記憶を封印しました。")
                    .foregroundStyle(.white)
            }
            .font(.headline)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.brandBlack.opacity(0.95))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            .padding(.bottom, 50)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - 写真保存処理
    /// 撮影直後は必ずisUnlocked=falseで保存する。CKRecordConvertibleはisUnlockedが
    /// falseの間、画像フィールドを一切CKRecordに設定しないため、CloudKit上には
    /// メタデータ(キャプション含む)だけが「現像中」レコードとして存在し、
    /// 自分を含めどのユーザーの端末にも画像本体は届かない。
    private func savePhoto(_ imageData: Data, caption: String? = nil) {
        let calendar = Calendar.current
        let now = Date()

        // 翌日0時を基点に、1〜4日後にランダムで解禁(グループ全員の条件が揃えば
        // GroupUnlockPolicy側の判定でこれより早く解禁されることもある)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let startOfTomorrow = calendar.startOfDay(for: tomorrow)
        let randomOffsetDays = Int.random(in: 1...4)
        let unlock = calendar.date(byAdding: .day, value: randomOffsetDays, to: startOfTomorrow) ?? startOfTomorrow

        let user = UserProfile.current(from: profiles)
        let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)

        let newPhoto = LaterPhoto(
            imageData: imageData,
            captureDate: now,
            unlockDate: unlock,
            owner: user,
            caption: (trimmedCaption?.isEmpty ?? true) ? nil : trimmedCaption
        )
        newPhoto.authorCloudKitUserRecordName = CloudKitManager.current?.currentUserRecordName
        newPhoto.authorNameCache = user?.name

        if let group = user?.groups.first {
            newPhoto.groupID = group.id
            context.insert(newPhoto)
            try? context.save()
            CloudKitManager.current?.markForUpload(photo: newPhoto, in: group)
        } else {
            context.insert(newPhoto)
            try? context.save()
        }

        // 📸 PhotoManagerのカウントを更新
        photoManager.incrementPhotoCount()

        // 自動アンロック
        autoUnlockPhotos()
        
        // 成功メッセージ表示
        withAnimation(.spring()) {
            showSuccessMessage = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut) {
                showSuccessMessage = false
            }
        }
        
        // 🔒 目標達成チェックは onChange で自動的に処理される
    }
    
    // MARK: - ロック管理（廃止：PhotoManagerが管理）
    
    // 以下の関数は不要になりましたが、コンパイルエラー回避のため空実装として残す
    // 実際の削除は後で行います
    
    // MARK: - 自動アンロック処理
    /// ロック中だった写真をローカルで解禁するとともに、自分が撮影した写真については
    /// 画像入りでCKRecordを再送する(他人の写真は自分の端末に実データを持っていないため
    /// 再送できないし、しない。その人自身の端末が同じ処理を行う)。
    private func autoUnlockPhotos() {
        do {
            let descriptor = FetchDescriptor<LaterPhoto>()
            let all = try context.fetch(descriptor)
            let nowDate = Date()
            let myRecordName = CloudKitManager.current?.currentUserRecordName
            for p in all where p.unlockDate <= nowDate && p.isUnlocked == false {
                p.isUnlocked = true
                if let myRecordName, p.authorCloudKitUserRecordName == myRecordName,
                   let groupID = p.groupID,
                   let group = try? context.fetch(FetchDescriptor<LaterGroup>()).first(where: { $0.id == groupID }) {
                    CloudKitManager.current?.markForUpload(photo: p, in: group)
                }
            }
            try? context.save()
        } catch {
            print("Failed to auto-unlock photos: \(error)")
        }
    }
}

// MARK: - スケールボタンスタイル
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// 📸 AVFoundationを使った「プレビューさせない」真のオリジナルカメラ
struct TrueBlindCameraView: UIViewControllerRepresentable {
    var onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let photoManager = PhotoManager.shared

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.isLocked = photoManager.isLockedToday
        vc.onCapture = { data in
            onCapture(data)
            dismiss() // 撮影した瞬間に強制的にカメラを閉じる（プレビューさせない）
        }
        vc.onDismiss = {
            dismiss()
        }
        return vc
    }
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.isLocked = photoManager.isLockedToday
    }
}

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var session = AVCaptureSession()
    var photoOutput = AVCapturePhotoOutput()
    var previewLayer = AVCaptureVideoPreviewLayer()
    var onCapture: ((Data) -> Void)?
    var onDismiss: (() -> Void)?
    var isLocked: Bool = false
    
    private var shutterButton: UIButton?
    private var closeButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermissions()
    }

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { DispatchQueue.main.async { self.setupCamera() } }
            }
        default: break
        }
    }

    func setupCamera() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
            if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)

            // 閉じるボタン（左上）
            let closeBtn = UIButton(frame: CGRect(x: 20, y: 50, width: 44, height: 44))
            closeBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
            closeBtn.tintColor = .white
            closeBtn.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            closeBtn.layer.cornerRadius = 22
            closeBtn.addTarget(self, action: #selector(closeCamera), for: .touchUpInside)
            view.addSubview(closeBtn)
            closeButton = closeBtn

            // オリジナルのシャッターボタン
            let shutterBtn = UIButton(frame: CGRect(x: (view.bounds.width - 80)/2, y: view.bounds.height - 130, width: 80, height: 80))
            shutterBtn.layer.cornerRadius = 40
            shutterBtn.backgroundColor = isLocked ? .gray : .white
            shutterBtn.layer.borderWidth = 5
            shutterBtn.layer.borderColor = isLocked ? UIColor.darkGray.cgColor : UIColor.lightGray.cgColor
            shutterBtn.isEnabled = !isLocked
            shutterBtn.alpha = isLocked ? 0.5 : 1.0
            shutterBtn.addTarget(self, action: #selector(takePhoto), for: .touchUpInside)
            view.addSubview(shutterBtn)
            shutterButton = shutterBtn
            
            // ロック状態の表示
            if isLocked {
                let lockLabel = UILabel()
                lockLabel.text = "🔒 撮影完了"
                lockLabel.textColor = .white
                lockLabel.font = .systemFont(ofSize: 16, weight: .bold)
                lockLabel.textAlignment = .center
                lockLabel.frame = CGRect(x: 0, y: view.bounds.height - 200, width: view.bounds.width, height: 30)
                view.addSubview(lockLabel)
            }

            DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
        } catch { print(error) }
    }
    
    @objc func closeCamera() {
        session.stopRunning()
        onDismiss?()
    }

    @objc func takePhoto() {
        guard !isLocked else {
            // ロック状態では撮影できないことをハプティクスで通知
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return
        }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
        
        // シャッターを切った瞬間に画面をフラッシュさせて「撮った感」だけ出す
        let flashView = UIView(frame: view.bounds)
        flashView.backgroundColor = .white
        view.addSubview(flashView)
        UIView.animate(withDuration: 0.1, animations: { flashView.alpha = 0 }) { _ in flashView.removeFromSuperview() }
        
        // ハプティクスフィードバック
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }
        session.stopRunning()
        onCapture?(data) // データを渡して即終了
    }
}



// MARK: - SimpleLockOverlay

/// 🔒 目標達成時に表示される「撮影完了・ロック」演出オーバーレイ（簡易版）
struct SimpleLockOverlay: View {
    let photosTaken: Int
    let goal: Int
    var onComplete: () -> Void
    
    @State private var showLock = false
    @State private var lockScale: CGFloat = 0.3
    @State private var lockRotation: Double = -90
    @State private var lockOpacity: Double = 0
    
    @State private var showMessage = false
    @State private var messageScale: CGFloat = 0.5
    @State private var messageOpacity: Double = 0
    
    @State private var darkOverlayOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // 1. ダークフィルター
            Color.black
                .opacity(darkOverlayOpacity)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // 2. 南京錠アイコン
                ZStack {
                    // 後光エフェクト
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.brandGreen.opacity(0.3),
                                    Color.brandGreen.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(lockScale * 1.2)
                        .opacity(lockOpacity)
                    
                    // 錠前アイコン
                    Image(systemName: "lock.fill")
                        .font(.system(size: 100, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.brandGreen, Color.brandGreen.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.brandGreen.opacity(0.6), radius: 30, x: 0, y: 10)
                        .scaleEffect(lockScale)
                        .rotationEffect(.degrees(lockRotation))
                        .opacity(lockOpacity)
                }
                .opacity(showLock ? 1 : 0)
                
                // 3. メインメッセージ
                VStack(spacing: 16) {
                    Text("MISSION COMPLETE")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.brandGreen.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.brandGreen.opacity(0.5), radius: 10, x: 0, y: 5)
                        .multilineTextAlignment(.center)
                    
                    Text("今日の思い出は全て封印されました")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    // 統計バッジ
                    HStack(spacing: 20) {
                        lockCompletionBadge(icon: "camera.fill", value: "\(photosTaken)")
                        lockCompletionBadge(icon: "checkmark.seal.fill", value: "\(goal)")
                    }
                    .padding(.top, 8)
                    
                    Text("解禁までお楽しみに...")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 8)
                }
                .scaleEffect(messageScale)
                .opacity(messageOpacity)
                .opacity(showMessage ? 1 : 0)
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            startAnimation()
        }
    }
    
    // MARK: - バッジビュー
    
    private func lockCompletionBadge(icon: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(Color.brandGreen)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.brandGreen.opacity(0.15))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.brandGreen.opacity(0.4), lineWidth: 2)
        )
    }
    
    // MARK: - アニメーション制御
    
    private func startAnimation() {
        // 0. 触覚フィードバック（重い衝撃）
        let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
        heavyImpact.impactOccurred()
        
        // 1. ダークオーバーレイをフェードイン (0-0.3秒)
        withAnimation(.easeIn(duration: 0.3)) {
            darkOverlayOpacity = 0.85
        }
        
        // 2. 南京錠を表示 (0.2-0.8秒)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showLock = true
            
            // ロック回転＆スケールアニメーション
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                lockScale = 1.0
                lockRotation = 0
                lockOpacity = 1.0
            }
            
            // ロック音の代わりにハプティクス
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        }
        
        // 3. メッセージ表示 (0.8-1.4秒)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showMessage = true
            
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                messageScale = 1.0
                messageOpacity = 1.0
            }
            
            // 追加ハプティクス
            let lightImpact = UIImpactFeedbackGenerator(style: .light)
            lightImpact.impactOccurred()
        }
        
        // 4. 自動遷移 (3.0秒後)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                darkOverlayOpacity = 0
                lockOpacity = 0
                messageOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete()
            }
        }
    }
}

