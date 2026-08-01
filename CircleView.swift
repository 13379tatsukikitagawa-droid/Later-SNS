import SwiftUI
import SwiftData

/// Circle画面 - グループのベストショット閲覧（円形ダイヤルUI）
struct CircleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var groups: [LaterGroup]
    @Query private var profiles: [UserProfile]
    @Query(sort: \LaterPhoto.captureDate, order: .reverse) private var allPhotos: [LaterPhoto]
    
    // テーマカラー
    @AppStorage("themeColor") private var themeColorName: String = "green"
    
    // 選択中の日付インデックス (0 = 今日, 6 = 6日前)
    @State private var selectedDayIndex: Int = 0
    
    // 選択中のグループ
    @State private var selectedGroupIndex: Int = 0
    
    // シート表示状態
    @State private var showingCreateGroup = false
    @State private var showingJoinWithPass = false
    @State private var showingQRScanner = false
    @State private var showingGroupDetail = false
    @State private var scannedQRCode: String?
    @State private var showingQRResult = false
    
    // アニメーション用
    @State private var photoOpacity: Double = 1.0
    @State private var photoScale: CGFloat = 1.0
    
    // ハプティクス
    private let haptics = UISelectionFeedbackGenerator()
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    private var userGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }
    }
    
    private var selectedGroup: LaterGroup? {
        guard !userGroups.isEmpty, selectedGroupIndex < userGroups.count else { return nil }
        return userGroups[selectedGroupIndex]
    }
    
    // テーマカラー
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
    
    // 直近7日間の日付配列（今日から遡る）
    private var last7Days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).map { calendar.date(byAdding: .day, value: -$0, to: today)! }
    }
    
    // 選択中の日付
    private var selectedDate: Date {
        last7Days[selectedDayIndex]
    }
    
    // 選択中の日付のベストショット（選択中のグループ）
    private var selectedDayBestShot: LaterPhoto? {
        guard let group = selectedGroup else { return nil }
        let calendar = Calendar.current
        
        return group.photos.first { photo in
            photo.isGroupBestShot && calendar.isDate(photo.captureDate, inSameDayAs: selectedDate)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景（暗室風）
                Color.black.ignoresSafeArea()
                
                if userGroups.isEmpty {
                    // グループ未参加時の初期画面
                    emptyStateWithActions
                } else {
                    // グループ参加済み：円形ダイヤル + ベストショット表示
                    circleMainView
                }
            }
            .navigationTitle("Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingCreateGroup = true
                        } label: {
                            Label("Create Group", systemImage: "plus.circle")
                        }
                        
                        Button {
                            showingJoinWithPass = true
                        } label: {
                            Label("Join with Passphrase", systemImage: "key.fill")
                        }
                        
                        Button {
                            showingQRScanner = true
                        } label: {
                            Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                        }
                        
                        if !userGroups.isEmpty {
                            Divider()
                            
                            Button {
                                showingGroupDetail = true
                            } label: {
                                Label("Group Settings", systemImage: "gearshape")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(themeColor)
                    }
                }
            }
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupView { newGroup in
                    handleGroupCreated(newGroup)
                }
            }
            .sheet(isPresented: $showingJoinWithPass) {
                JoinWithPassphraseView { passphrase in
                    handlePassphraseEntered(passphrase)
                }
            }
            .fullScreenCover(isPresented: $showingQRScanner) {
                QRCodeScannerView { scannedCode in
                    handleQRCodeScanned(scannedCode)
                }
            }
            .sheet(isPresented: $showingGroupDetail) {
                if let group = selectedGroup {
                    CircleDetailView(group: group)
                }
            }
            .onAppear {
                haptics.prepare()
            }
        }
        .overlay {
            if showingQRResult, let code = scannedQRCode {
                QRScanResultView(
                    scannedData: code,
                    onConfirm: {
                        handleQRConfirm(code)
                    },
                    onCancel: {
                        showingQRResult = false
                        scannedQRCode = nil
                    }
                )
            }
        }
    }
    
    // MARK: - グループ未参加時の初期画面
    
    private var emptyStateWithActions: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // アイコン
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                themeColor.opacity(0.3),
                                themeColor.opacity(0.08)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                
                Image(systemName: "person.3.sequence.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(themeColor.opacity(0.7))
            }
            .padding(.bottom, 32)
            
            // テキスト
            VStack(spacing: 12) {
                Text("Circle で繋がろう")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                
                Text("グループを作成するか、\n合言葉で参加して思い出を共有しましょう")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.bottom, 48)
            
            // アクションボタン
            VStack(spacing: 16) {
                // Create Button
                Button(action: {
                    HapticsManager.swipeFeedback()
                    showingCreateGroup = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                        
                        Text("Create Group")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [themeColor, themeColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: themeColor.opacity(0.5), radius: 24, x: 0, y: 12)
                    )
                }
                .buttonStyle(.plain)
                
                // Join with Passphrase Button
                Button(action: {
                    HapticsManager.swipeFeedback()
                    showingJoinWithPass = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Text("Join with Passphrase")
                            .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(themeColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(themeColor, lineWidth: 2)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(themeColor.opacity(0.12))
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - グループ参加済みのメインビュー（円形ダイヤル）
    
    private var circleMainView: some View {
        VStack(spacing: 0) {
            // グループセレクター（複数グループ対応）
            if userGroups.count > 1 {
                groupSelector
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
            }
            
            // 日付ヘッダー
            dateHeader
                .padding(.top, 24)
            
            Spacer()
            
            // 中央：ベストショット表示
            bestShotDisplayArea
                .opacity(photoOpacity)
                .scaleEffect(photoScale)
            
            Spacer()
            
            // 下部：タクタイルダイヤルナビゲーション
            TactileDialNavigation(
                dates: last7Days,
                selectedIndex: $selectedDayIndex,
                themeColor: themeColor,
                onDateChanged: {
                    haptics.selectionChanged()
                    animatePhotoTransition()
                }
            )
            .frame(height: 300)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - グループセレクター
    
    private var groupSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(userGroups.indices, id: \.self) { index in
                    GroupSelectorChip(
                        group: userGroups[index],
                        isSelected: selectedGroupIndex == index,
                        themeColor: themeColor
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            selectedGroupIndex = index
                        }
                        haptics.selectionChanged()
                        animatePhotoTransition()
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - 日付ヘッダー
    
    private var dateHeader: some View {
        VStack(spacing: 8) {
            // 日付
            Text(formattedDate(selectedDate))
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            
            // 曜日
            Text(weekdayString(for: selectedDate))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(themeColor)
                .textCase(.uppercase)
            
            // グループ名（1つの場合）
            if userGroups.count == 1, let group = selectedGroup {
                Text(group.name)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - ベストショット表示エリア
    
    @ViewBuilder
    private var bestShotDisplayArea: some View {
        if let bestShot = selectedDayBestShot {
            GroupBestShotCard(photo: bestShot, themeColor: themeColor)
                .padding(.horizontal, 24)
        } else {
            // 投票中かベストショットなし
            bestShotEmptyOrVotingView
        }
    }
    
    @ViewBuilder
    private var bestShotEmptyOrVotingView: some View {
        let votingSession = VotingManager.shared.activeVotingSession
        let isVoting = votingSession?.isActive ?? false
        
        if isVoting {
            // 投票中
            VotingInProgressView(themeColor: themeColor)
        } else {
            // ベストショットなし
            circleBestShotEmptyState
        }
    }
    
    private var circleBestShotEmptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(themeColor.opacity(0.3))
            }
            
            VStack(spacing: 8) {
                Text("この日のベストショットはまだありません")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                Text("みんなで写真を撮って投票しましょう")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(40)
    }
    
    // MARK: - ヘルパー関数
    
    private func animatePhotoTransition() {
        withAnimation(.easeOut(duration: 0.15)) {
            photoOpacity = 0.0
            photoScale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                photoOpacity = 1.0
                photoScale = 1.0
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
    
    private func weekdayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    // MARK: - ハンドラー
    
    private func handleGroupCreated(_ group: LaterGroup) {
        guard let user = currentUser else { return }
        
        // ユーザーをグループに追加
        group.members.append(user)
        
        // データベースに保存
        modelContext.insert(group)
        
        HapticsManager.unlockSuccess()
        showingCreateGroup = false
    }
    
    private func handlePassphraseEntered(_ passphrase: String) {
        // 合言葉（inviteCode）でグループを検索
        if let group = groups.first(where: { $0.inviteCode == passphrase }) {
            joinGroup(group)
            showingJoinWithPass = false
        } else {
            // グループが見つからない
            print("Group not found with passphrase: \(passphrase)")
            // TODO: エラーメッセージを表示
        }
    }
    
    private func handleQRCodeScanned(_ code: String) {
        scannedQRCode = code
        showingQRScanner = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingQRResult = true
        }
    }
    
    private func handleQRConfirm(_ code: String) {
        if let groupData = QRCodeGenerator.parseGroupQRData(code) {
            if let existingGroup = groups.first(where: { $0.id.uuidString == groupData.id }) {
                joinGroup(existingGroup)
            } else {
                print("Group not found: \(groupData.id)")
            }
        }
        
        showingQRResult = false
        scannedQRCode = nil
    }
    
    private func joinGroup(_ group: LaterGroup) {
        guard let user = currentUser else { return }
        
        if group.members.contains(where: { $0.id == user.id }) {
            print("Already a member")
            return
        }
        
        group.members.append(user)
        HapticsManager.unlockSuccess()
    }
}

// MARK: - グループセレクターチップ

struct GroupSelectorChip: View {
    let group: LaterGroup
    let isSelected: Bool
    let themeColor: Color
    
    private var memberCount: Int {
        group.members.count
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // グループアイコン
            Image(systemName: "person.3.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? .black : themeColor)
            
            // グループ名
            Text(group.name)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? .black : .white)
                .lineLimit(1)
            
            // メンバー数
            Text("\(memberCount)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(isSelected ? .black.opacity(0.6) : .white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [themeColor, themeColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: themeColor.opacity(0.5), radius: 12, x: 0, y: 6)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
            }
        )
    }
}

// MARK: - 合言葉入力シート

struct JoinWithPassphraseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var passphrase: String = ""
    
    let onSubmit: (String) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // アイコン
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.brandGreen.opacity(0.3),
                                        Color.brandGreen.opacity(0.08)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "key.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(Color.brandGreen.opacity(0.7))
                    }
                    .padding(.top, 40)
                    
                    // タイトル
                    VStack(spacing: 12) {
                        Text("合言葉で参加")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                        
                        Text("ホストから共有された合言葉を\n入力してグループに参加")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    
                    // 入力フィールド
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Passphrase")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.brandGreen)
                            .textCase(.uppercase)
                        
                        TextField("例: sunset-memory-2026", text: $passphrase)
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(
                                                passphrase.isEmpty ? Color.white.opacity(0.15) : Color.brandGreen.opacity(0.5),
                                                lineWidth: 1.5
                                            )
                                    )
                            )
                    }
                    .padding(.horizontal, 32)
                    
                    // 参加ボタン
                    Button(action: {
                        guard !passphrase.isEmpty else { return }
                        onSubmit(passphrase)
                        dismiss()
                    }) {
                        Text("Join Group")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.brandGreen, Color.brandGreen.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: Color.brandGreen.opacity(0.5), radius: 24, x: 0, y: 12)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(passphrase.isEmpty)
                    .opacity(passphrase.isEmpty ? 0.5 : 1.0)
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
            }
            .navigationTitle("Join Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - プレビュー

#Preview("Circle - Empty State") {
    CircleView()
        .modelContainer(for: [LaterGroup.self, UserProfile.self, LaterPhoto.self], inMemory: true)
}
#Preview("Circle - With Groups") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: LaterGroup.self, UserProfile.self, LaterPhoto.self, configurations: config)
    
    // サンプルデータ作成
    let context = container.mainContext
    
    let user = UserProfile(name: "Test User", username: "testuser")
    context.insert(user)
    
    let group = LaterGroup(
        name: "Family",
        host: user
    )
    group.members.append(user)
    context.insert(group)
    
    return CircleView()
        .modelContainer(container)
}

#Preview("Join with Passphrase") {
    JoinWithPassphraseView { passphrase in
        print("Entered: \(passphrase)")
    }
}

