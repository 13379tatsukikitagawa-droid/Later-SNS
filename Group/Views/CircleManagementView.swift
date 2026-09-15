import SwiftUI
import SwiftData
import CloudKit
import PhotosUI

/// Circle管理画面 - グループの作成・管理を行うサブ画面。参加は共有リンク(later://join?shareUrl=...)
/// を受け取ってタップするのみで、この画面から能動的に「参加する」操作はしない
/// (合言葉/QRコードでの参加は廃止した)。
struct CircleManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var groups: [LaterGroup]
    @Query private var profiles: [UserProfile]

    @State private var showingCreateGroup = false

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
                
                Text("招待リンクからグループに参加")
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
                        
                        Text("新しいグループを作成")
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
                
                Text("上のボタンからグループを作成するか、\n招待リンクを受け取って参加してください")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Group Card

struct GroupCard: View {
    let group: LaterGroup
    
    var body: some View {
        NavigationLink {
            GroupDetailView(group: group)
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
                            Text("\(group.photos.count + group.videos.count)枚")
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
    @State private var showingSuccess = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var createdShareURL: URL?
    @State private var selectedIconItem: PhotosPickerItem?
    @State private var iconImageData: Data?
    /// CKError.quotaExceeded(iCloud容量不足)で画像を除いて再試行し、グループ自体は
    /// 作成できた場合に、成功シート(GroupCreatedShareView)内へ表示する注意文言。
    @State private var successWarningMessage: String?

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // アイコン(タップして写真を選択)
                        PhotosPicker(selection: $selectedIconItem, matching: .images) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandGreen.opacity(0.12))
                                    .frame(width: 88, height: 88)

                                if let iconImageData, let uiImage = UIImage(data: iconImageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 88, height: 88)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 26))
                                        .foregroundStyle(Color.brandGreen)
                                }

                                Circle()
                                    .strokeBorder(Color.brandGreen.opacity(0.4), lineWidth: 1.5)
                                    .frame(width: 88, height: 88)
                            }
                        }
                        .padding(.top, 20)
                        .onChange(of: selectedIconItem) { _, newItem in
                            Task {
                                guard let newItem, let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                                iconImageData = data
                            }
                        }

                        VStack(spacing: 20) {
                            // グループ名入力
                            VStack(alignment: .leading, spacing: 8) {
                                Text("グループ名")
                                    .font(.headline)
                                    .foregroundStyle(Color.white)
                                
                                TextField("例: 親友グループ", text: $groupName)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                            
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
                        .disabled(groupName.isEmpty || isSaving)
                        .opacity(groupName.isEmpty ? 0.5 : 1.0)
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
            // ネイティブ.alert()はカスタムデザイン(ダーク背景・角丸カード・コピー導線)を
            // 持てないため、ブランドトーンのカードUIを持つ専用シートに置き換えている。
            // シートを閉じる操作(ボタン/スワイプ)は一つに絞り、onDismissでこの作成画面自体も
            // 一緒に閉じることで、画面遷移導線がバッティングしないようにしている。
            .sheet(isPresented: $showingSuccess, onDismiss: { dismiss() }) {
                GroupCreatedShareView(groupName: groupName, shareURL: createdShareURL, warningMessage: successWarningMessage)
            }
        }
    }

    private func createGroup() async {
        guard let user = currentUser else { return }
        guard let cloudKitManager = CloudKitManager.current else {
            errorMessage = "iCloudへの接続が完了していません。しばらくしてから再度お試しください。"
            return
        }

        // 所属グループ数の上限チェック(個人用「ME」は数えない)。newGroupを作る/
        // addMemberする前に確認することで、上限超過時にローカルへ何も残さず
        // 即座にエラー表示だけで済ませる。
        let joinedGroupCount = user.groups.filter { !$0.isPersonalSpace }.count
        guard joinedGroupCount < GroupMembershipPolicy.maxGroupsPerUser else {
            errorMessage = GroupSharingError.tooManyGroups.errorDescription
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
        newGroup.iconImageData = iconImageData

        // ホストとして自分を追加
        let _ = newGroup.addMember(user)

        // データベースに保存
        modelContext.insert(newGroup)

        let sharingService = GroupSharingService(container: cloudKitManager.container, modelContext: modelContext, cloudKitManager: cloudKitManager)
        do {
            try await sharingService.createGroup(newGroup, hostProfile: user)
        } catch GroupSharingError.quotaExceeded(groupCreatedWithoutImages: true) {
            // iCloudの容量不足で画像だけ除いて再試行し、グループ自体(名前・共有リンク含む)は
            // 既に作成できている。newGroupを削除せず、通常の成功フローへ進みつつ
            // 成功シート内に注意文言を表示する(名前等まで道連れで失敗させないための対応)。
            successWarningMessage = GroupSharingError.quotaExceeded(groupCreatedWithoutImages: true).errorDescription
        } catch {
            modelContext.delete(newGroup)
            // グループ本体の保存自体が失敗したのか、共有リンクの発行だけが失敗したのかを
            // メッセージ・ログの両方で切り分けられるようにする。
            switch error {
            case GroupSharingError.groupCreationFailed(let underlying, let detail):
                _ = underlying.loggedDescription(context: "CircleCreateGroupView.createGroup(グループ本体の保存)")
                // underlying単体は「巻き添え」のCKError 22(Atomic failure)なだけで詳細が無いことが
                // 多いため、detail(atomicバッチ内の本当の原因レコード)が取れていればそちらを
                // 画面に表示する。TestFlightなどXcodeコンソールを見られない環境向けの対応。
                errorMessage = GroupSharingError.groupCreationFailed(underlying: underlying, detail: detail).errorDescription
            case GroupSharingError.shareCreationFailed(let underlying, let detail):
                _ = underlying.loggedDescription(context: "CircleCreateGroupView.createGroup(グループ本体は保存できたが共有リンクの発行)")
                errorMessage = GroupSharingError.shareCreationFailed(underlying: underlying, detail: detail).errorDescription
            case GroupSharingError.quotaExceeded:
                // groupCreatedWithoutImages: falseのケース(画像を除いても容量超過だった等)。
                errorMessage = (error as? GroupSharingError)?.errorDescription
            default:
                errorMessage = error.loggedDescription(context: "CircleCreateGroupView.createGroup")
            }
            return
        }

        if let shareURLString = newGroup.ckShareURL {
            createdShareURL = URL(string: shareURLString)
        }

        HapticsManager.unlockSuccess()
        showingSuccess = true

        print("✅ グループ作成: \(groupName)")
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
