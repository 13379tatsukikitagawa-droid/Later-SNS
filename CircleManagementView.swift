import SwiftUI
import SwiftData

/// Circle管理画面 - グループの作成・参加・管理を行うサブ画面
struct CircleManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var groups: [LaterGroup]
    @Query private var profiles: [UserProfile]
    
    @State private var showingCreateGroup = false
    @State private var showingJoinWithPass = false
    @State private var showingQRScanner = false
    @State private var scannedQRCode: String?
    @State private var showingQRResult = false
    
    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    private var userGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.brandBlack.ignoresSafeArea()
                
                // 液体アニメーション背景
                LiquidBackgroundView()
                    .opacity(0.2)
                
                ScrollView {
                    VStack(spacing: 32) {
                        // ヘッダー説明
                        headerSection
                        
                        // アクションボタン群
                        actionButtonsSection
                        
                        // 所属グループ一覧
                        if !userGroups.isEmpty {
                            groupsListSection
                        } else {
                            emptyGroupsView
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("Circles")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        HapticsManager.swipeFeedback()
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundStyle(Color.brandGreen)
                    }
                }
            }
            .sheet(isPresented: $showingCreateGroup) {
                CircleCreateGroupView()
            }
            .sheet(isPresented: $showingJoinWithPass) {
                JoinWithWordPassView()
            }
            .fullScreenCover(isPresented: $showingQRScanner) {
                QRCodeScannerView(onScanSuccess: { code in
                    scannedQRCode = code
                    showingQRResult = true
                })
            }
            .alert("QRコード読み取り成功", isPresented: $showingQRResult) {
                Button("グループに参加") {
                    if let code = scannedQRCode {
                        joinGroup(withCode: code)
                    }
                }
                Button("キャンセル", role: .cancel) {
                    scannedQRCode = nil
                }
            } message: {
                Text("グループに参加しますか？")
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // アイコン
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.brandGreen.opacity(0.3),
                                Color.brandGreen.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color.brandGreen)
            }
            
            // タイトルと説明
            VStack(spacing: 8) {
                Text("グループで繋がろう")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                
                Text("合言葉やQRコードでグループに参加")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            // 所属グループ数
            if !userGroups.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text("\(userGroups.count)個のグループに所属中")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color.brandGreen)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.brandGreen.opacity(0.15))
                )
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Create Circle ボタン
            Button(action: {
                HapticsManager.cardChange()
                showingCreateGroup = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create Circle")
                            .font(.system(size: 18, weight: .bold))
                        
                        Text("新しいグループを作成（合言葉設定あり）")
                            .font(.system(size: 13, weight: .medium))
                            .opacity(0.7)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .opacity(0.5)
                }
                .foregroundStyle(Color.black)
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [
                            Color.brandGreen,
                            Color.brandGreen.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.brandGreen.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            
            // Join with Word ボタン
            Button(action: {
                HapticsManager.cardChange()
                showingJoinWithPass = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 24, weight: .semibold))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Join with Word")
                            .font(.system(size: 18, weight: .bold))
                        
                        Text("合言葉を入力してグループに参加")
                            .font(.system(size: 13, weight: .medium))
                            .opacity(0.7)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .opacity(0.5)
                }
                .foregroundStyle(Color.white)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.brandGreen.opacity(0.3), lineWidth: 2)
                        )
                )
            }
            
            // Join with QR Code ボタン
            Button(action: {
                HapticsManager.cardChange()
                showingQRScanner = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 24, weight: .semibold))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Join with QR Code")
                            .font(.system(size: 18, weight: .bold))
                        
                        Text("QRコードをスキャンして参加")
                            .font(.system(size: 13, weight: .medium))
                            .opacity(0.7)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .opacity(0.5)
                }
                .foregroundStyle(Color.white)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1.5)
                        )
                )
            }
        }
    }
    
    // MARK: - Groups List Section
    
    private var groupsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // セクションヘッダー
            HStack {
                Text("所属グループ")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)
                
                Spacer()
                
                Text("\(userGroups.count)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brandGreen)
            }
            .padding(.horizontal, 4)
            
            // グループカード
            LazyVStack(spacing: 12) {
                ForEach(userGroups) { group in
                    GroupCard(group: group)
                }
            }
        }
    }
    
    // MARK: - Empty Groups View
    
    private var emptyGroupsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "circle.dotted")
                .font(.system(size: 60))
                .foregroundStyle(Color.white.opacity(0.3))
                .symbolEffect(.pulse)
            
            VStack(spacing: 8) {
                Text("グループに参加していません")
                    .font(.headline)
                    .foregroundStyle(Color.white)
                
                Text("上のボタンから\nグループを作成または参加してください")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Methods
    
    private func joinGroup(withCode code: String) {
        // QRコードからグループIDを抽出してグループに参加
        // TODO: 実装
        print("グループに参加: \(code)")
        HapticsManager.unlockSuccess()
    }
}

// MARK: - Group Card

struct GroupCard: View {
    let group: LaterGroup
    
    var body: some View {
        NavigationLink {
            // TODO: グループ詳細画面へ遷移
            Text("グループ詳細: \(group.name)")
        } label: {
            HStack(spacing: 16) {
                // グループアイコン
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.7),
                                    Color.blue.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "person.3.fill")
                        .font(.title3)
                        .foregroundStyle(Color.white)
                }
                
                // グループ情報
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.white)
                    
                    HStack(spacing: 12) {
                        // メンバー数
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                            Text("\(group.members.count)人")
                                .font(.caption)
                        }
                        
                        // 写真数
                        HStack(spacing: 4) {
                            Image(systemName: "photo.fill")
                                .font(.caption)
                            Text("\(group.photos.count)枚")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(Color.white.opacity(0.6))
                }
                
                Spacer()
                
                // 右矢印
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Create Group View (Circle Management)

struct CircleCreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var groupName: String = ""
    @State private var wordPass: String = ""
    @State private var showingSuccess = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var createdShareURL: URL?

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // アイコン
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.brandGreen)
                            .padding(.top, 20)
                        
                        VStack(spacing: 20) {
                            // グループ名入力
                            VStack(alignment: .leading, spacing: 8) {
                                Text("グループ名")
                                    .font(.headline)
                                    .foregroundStyle(Color.white)
                                
                                TextField("例: 親友グループ", text: $groupName)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                            
                            // 合言葉入力
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("合言葉（Word Pass）")
                                        .font(.headline)
                                        .foregroundStyle(Color.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(Color.brandGreen)
                                        .help("参加者はこの合言葉を入力してグループに参加します")
                                }
                                
                                TextField("例: sakura2026", text: $wordPass)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                
                                Text("※ 英数字のみ推奨")
                                    .font(.caption)
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                            
                            // 説明
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(Color.yellow)
                                    Text("合言葉のヒント")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(Color.white)
                                }
                                
                                Text("• 友達に教えやすい言葉にしましょう\n• 推測されにくい言葉を選びましょう\n• 大文字・小文字を区別します")
                                    .font(.caption)
                                    .foregroundStyle(Color.white.opacity(0.7))
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.yellow.opacity(0.1))
                            )
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 40)
                        
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }

                        // 作成ボタン
                        Button(action: {
                            Task { await createGroup() }
                        }) {
                            Text("グループを作成")
                                .font(.headline)
                                .foregroundStyle(Color.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color.brandGreen, Color.brandGreen.opacity(0.9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: Color.brandGreen.opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        .disabled(groupName.isEmpty || wordPass.isEmpty || isSaving)
                        .opacity((groupName.isEmpty || wordPass.isEmpty) ? 0.5 : 1.0)
                        .padding(.horizontal)
                    }
                }

                if isSaving {
                    ProgressView()
                }
            }
            .navigationTitle("グループ作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("キャンセル")
                            .foregroundStyle(Color.brandGreen)
                    }
                }
            }
            .alert("グループ作成完了", isPresented: $showingSuccess) {
                if let createdShareURL {
                    ShareLink(item: createdShareURL) {
                        Text("招待リンクを送る")
                    }
                }
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("グループ「\(groupName)」を作成しました。\n招待リンクまたは合言葉「\(wordPass)」を友達に共有してください。")
            }
        }
    }

    private func createGroup() async {
        guard let user = currentUser else { return }
        guard let cloudKitManager = CloudKitManager.current else {
            errorMessage = "iCloudへの接続が完了していません。しばらくしてから再度お試しください。"
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        // 新しいグループを作成
        let newGroup = LaterGroup(
            name: groupName,
            host: user,
            autoGenerateMission: false,
            isPrivate: true
        )

        // ホストとして自分を追加
        let _ = newGroup.addMember(user)

        // 合言葉を招待コードとして設定
        newGroup.inviteCode = wordPass

        // データベースに保存
        modelContext.insert(newGroup)

        let sharingService = GroupSharingService(container: cloudKitManager.container, modelContext: modelContext, cloudKitManager: cloudKitManager)
        do {
            try await sharingService.createGroup(newGroup, hostProfile: user)
        } catch {
            modelContext.delete(newGroup)
            errorMessage = error.localizedDescription
            return
        }

        if let shareURLString = newGroup.ckShareURL {
            createdShareURL = URL(string: shareURLString)
        }

        HapticsManager.unlockSuccess()
        showingSuccess = true

        print("✅ グループ作成: \(groupName), 合言葉: \(wordPass)")
    }
}

// MARK: - Join with Word Pass View

struct JoinWithWordPassView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var groups: [LaterGroup]
    @Query private var profiles: [UserProfile]
    
    @State private var wordPass: String = ""
    @State private var showingResult = false
    @State private var resultMessage: String = ""
    @State private var isSuccess: Bool = false
    @State private var isJoining = false

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // アイコン
                    Image(systemName: "key.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.brandGreen)
                        .padding(.top, 40)
                    
                    VStack(spacing: 16) {
                        Text("合言葉を入力")
                            .font(.title2.bold())
                            .foregroundStyle(Color.white)
                        
                        Text("グループホストから教えてもらった\n合言葉を入力してください")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    
                    // 合言葉入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Word Pass")
                            .font(.headline)
                            .foregroundStyle(Color.white)
                        
                        TextField("合言葉を入力", text: $wordPass)
                            .textFieldStyle(CustomTextFieldStyle())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // 参加ボタン
                    Button(action: {
                        Task { await joinGroupWithPass() }
                    }) {
                        Text("グループに参加")
                            .font(.headline)
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.brandGreen, Color.brandGreen.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.brandGreen.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .disabled(wordPass.isEmpty || isJoining)
                    .opacity(wordPass.isEmpty ? 0.5 : 1.0)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }

                if isJoining {
                    ProgressView()
                }
            }
            .navigationTitle("グループ参加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("キャンセル")
                            .foregroundStyle(Color.brandGreen)
                    }
                }
            }
            .alert(isSuccess ? "参加成功" : "参加失敗", isPresented: $showingResult) {
                Button("OK") {
                    if isSuccess {
                        dismiss()
                    }
                }
            } message: {
                Text(resultMessage)
            }
        }
    }
    
    private func joinGroupWithPass() async {
        guard let user = currentUser else {
            resultMessage = "ユーザー情報が見つかりません"
            isSuccess = false
            showingResult = true
            return
        }

        isJoining = true
        defer { isJoining = false }

        // まずローカルに既にあるかチェック(招待リンクを先にタップして
        // 既に同期済みだった場合など)。無ければCloudKit経由で解決する。
        if let matchingGroup = groups.first(where: { $0.inviteCode == wordPass }) {
            finishJoining(group: matchingGroup, user: user)
            return
        }

        guard let cloudKitManager = CloudKitManager.current else {
            resultMessage = "iCloudへの接続が完了していません。しばらくしてから再度お試しください。"
            isSuccess = false
            showingResult = true
            return
        }

        let sharingService = GroupSharingService(container: cloudKitManager.container, modelContext: modelContext, cloudKitManager: cloudKitManager)
        do {
            try await sharingService.joinGroup(wordPass: wordPass)
        } catch {
            HapticsManager.errorFeedback()
            resultMessage = error.localizedDescription
            isSuccess = false
            showingResult = true
            return
        }

        // Shared DBからの反映は非同期のため、短時間ポーリングしてローカルに現れるのを待つ
        for _ in 0..<10 {
            if let matchingGroup = (try? modelContext.fetch(FetchDescriptor<LaterGroup>()))?.first(where: { $0.inviteCode == wordPass }) {
                finishJoining(group: matchingGroup, user: user, sharingService: sharingService)
                return
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        HapticsManager.errorFeedback()
        resultMessage = "グループへの参加に時間がかかっています。少し待ってから確認してください。"
        isSuccess = false
        showingResult = true
    }

    private func finishJoining(group: LaterGroup, user: UserProfile, sharingService: GroupSharingService? = nil) {
        if group.isMember(userID: user.id) {
            resultMessage = "すでにこのグループに参加しています"
            isSuccess = false
            showingResult = true
            return
        }

        let added = group.addMember(user)

        if added {
            if let sharingService {
                sharingService.uploadOwnProfile(user, to: group)
            }
            HapticsManager.unlockSuccess()
            resultMessage = "グループ「\(group.name)」に参加しました！"
            isSuccess = true
            showingResult = true
        } else {
            HapticsManager.errorFeedback()
            resultMessage = "グループへの参加に失敗しました"
            isSuccess = false
            showingResult = true
        }
    }
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.brandGreen.opacity(0.3), lineWidth: 1.5)
            )
            .foregroundStyle(Color.white)
            .font(.system(size: 17, weight: .medium))
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: LaterGroup.self, UserProfile.self, LaterPhoto.self, 
        configurations: config
    )
    
    CircleManagementView()
        .modelContainer(container)
}
