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
    @State private var selectedColorHex: String = CircleCreateGroupView.colorOptions.first!.hex
    @FocusState private var isCaptionFocused: Bool
    /// CKError.quotaExceeded(iCloud容量不足)で画像を除いて再試行し、グループ自体は
    /// 作成できた場合に、成功シート(GroupCreatedShareView)内へ表示する注意文言。
    @State private var successWarningMessage: String?

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    // MARK: - チェキテーマ(2026/9 新デザイン仕様「グループ作成画面」)

    private static let cream = Color(hex: "F3ECD9")
    private static let handwriting = Color(hex: "3a2c14")
    private static let placeholderColor = Color(hex: "a9906a")
    private static let mustard = Color(hex: "EAB93E")
    private static let accent = Color.laterAccent
    /// カラーステッカー(色+貼り付け角度)。先頭のアクセント緑をデフォルト選択にする。
    private static let colorOptions: [(hex: String, rotation: Double)] = [
        ("22FF6E", -6), ("4FC3F7", 5), ("FF6A2B", -4), ("B388FF", 7), ("FFD166", -3), ("FF5C8A", 4)
    ]

    private var otherGroupCount: Int {
        currentUser?.groups.filter { !$0.isPersonalSpace }.count ?? 0
    }
    private var remainingSlots: Int { max(0, GroupMembershipPolicy.maxGroupsPerUser - otherGroupCount) }
    private var isNameValid: Bool { !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 26) {
                        header

                        chekiCardWithStickers
                            .id("card")
                            .padding(.top, 8)

                        Text("メンバー1人（あなた）から始まります")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color(hex: "8FB49B"))

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }

                        developButton
                            .padding(.horizontal, 24)

                        Text("あと\(remainingSlots)個作れます（\(otherGroupCount)/\(GroupMembershipPolicy.maxGroupsPerUser)）")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "7FA88E"))
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
                .onChange(of: isCaptionFocused) { _, focused in
                    guard focused else { return }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("card", anchor: .center)
                    }
                }
            }
            .background(Color.laterBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if isSaving {
                    developingOverlay
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

    // MARK: - ①ヘッダー

    private var header: some View {
        VStack(spacing: 6) {
            ZStack {
                Text("グループ作成")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.laterText)

                HStack {
                    Button("キャンセル") { dismiss() }
                        .font(.system(size: 15))
                        .foregroundStyle(Self.accent)
                    Spacer()
                }
            }
            Text("みんなの新しい一枚を、ここから始めよう")
                .font(.system(size: 11.5))
                .foregroundStyle(Color(hex: "7FA88E"))
        }
        .padding(.horizontal, 20)
    }

    // MARK: - ②チェキカード+③カラーステッカー

    private var chekiCardWithStickers: some View {
        ZStack(alignment: .bottomTrailing) {
            chekiCard
            stickerRow
                .offset(x: 14, y: 16)
        }
    }

    private var chekiCard: some View {
        VStack(spacing: 0) {
            photoArea
            captionStrip
        }
        .padding(14)
        .frame(width: 258)
        .background(Self.cream)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 12)
        .rotationEffect(.degrees(-2))
    }

    private var photoArea: some View {
        PhotosPicker(selection: $selectedIconItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: "d6c9a2"), Color(hex: "93815a"), Color(hex: "6f6045")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    filmGrainOverlay

                    if let iconImageData, let uiImage = UIImage(data: iconImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(Self.handwriting.opacity(0.65))
                            Text("タップして撮る・選ぶ")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Self.handwriting.opacity(0.65))
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))

                ZStack {
                    Circle().fill(Self.mustard).frame(width: 30, height: 30)
                    Circle().strokeBorder(Self.cream, lineWidth: 3).frame(width: 30, height: 30)
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Self.handwriting)
                }
                .offset(x: 6, y: 6)
            }
        }
        .buttonStyle(.plain)
        .onChange(of: selectedIconItem) { _, newItem in
            Task {
                guard let newItem, let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                iconImageData = data
            }
        }
    }

    /// 未現像のもやを表す、軽量な粒子ノイズ。
    private var filmGrainOverlay: some View {
        Canvas { context, size in
            for _ in 0..<260 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let opacity = Double.random(in: 0.02...0.08)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1.1, height: 1.1)),
                    with: .color(.black.opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
    }

    private var captionStrip: some View {
        VStack(spacing: 8) {
            ZStack {
                if groupName.isEmpty {
                    Text("グループ名を書く")
                        .font(.custom("Snell Roundhand", size: 21))
                        .foregroundStyle(Self.placeholderColor)
                }
                TextField("", text: $groupName)
                    .font(.custom("Snell Roundhand", size: 21))
                    .foregroundStyle(Self.handwriting)
                    .multilineTextAlignment(.center)
                    .focused($isCaptionFocused)
            }

            HStack(spacing: 3) {
                ForEach(0..<22, id: \.self) { _ in
                    Rectangle().fill(Self.placeholderColor.opacity(0.5)).frame(width: 4, height: 1)
                }
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 6)
        .frame(height: 74)
    }

    private var stickerRow: some View {
        HStack(spacing: -6) {
            ForEach(Self.colorOptions, id: \.hex) { option in
                stickerButton(option)
            }
        }
    }

    private func stickerButton(_ option: (hex: String, rotation: Double)) -> some View {
        let isSelected = selectedColorHex == option.hex
        return Button {
            HapticsManager.tick()
            selectedColorHex = option.hex
        } label: {
            ZStack {
                Circle().fill(Color(hex: option.hex)).frame(width: 22, height: 22)
                Circle().strokeBorder(.white, lineWidth: 2).frame(width: 22, height: 22)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)
            .rotationEffect(.degrees(option.rotation))
        }
        .buttonStyle(.plain)
    }

    // MARK: - ⑤CTA「現像する」

    private var developButton: some View {
        Button {
            Task { await createGroup() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("現像する")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(Color.laterBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(Self.accent))
            .shadow(color: Self.accent.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!isNameValid || isSaving || remainingSlots <= 0)
        .opacity((!isNameValid || remainingSlots <= 0) ? 0.5 : 1.0)
    }

    /// 「現像する」の比喩を完成させる、送信中のロード演出。
    private var developingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().tint(Self.accent)
                Text("現像中…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
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
        newGroup.accentColorHex = selectedColorHex

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
