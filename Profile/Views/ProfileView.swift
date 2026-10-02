import SwiftUI
import SwiftData
import PhotosUI

/// プロフィール画面(2026/9 新デザイン仕様「⑩プロフィール画面(ブラッシュアップ版)」)。
/// 印画紙(チェキ)風のProfileChekiCardにプロフィール情報を集約し、QR/シェア/編集は
/// カード外の専用アクション行にまとめる。旧デザインにあった+/人物/グリッド/
/// チャット/ハンバーガーの5アイコン列は廃止し、ヘッダーはグリッド(Personalへの導線)+
/// 歯車(設定)の2つだけにする。
struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]

    @State private var isShowingSetup = false
    @State private var isShowingSettingsMenu = false
    @State private var isShowingPinPicker = false

    private static let accent = Color.laterAccent
    /// プロフィールが1件も無い状態(オンボーディング未完了など)でも、この定数を
    /// 光のにじみの種として使うことでチェキカード自体は必ず描画できる。
    private static let fallbackSeed = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var currentProfile: UserProfile? {
        UserProfile.current(from: profiles)
    }

    /// Pinsエリアに表示する、ピン留め順のLaterPhoto一覧。pinnedPhotoIDsに残っていても
    /// 実体が消えている(端末に無い等)IDはcompactMapで自然に読み飛ばす。
    private var pinnedPhotos: [LaterPhoto] {
        guard let profile = currentProfile else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: profile.photos.map { ($0.id, $0) })
        return profile.pinnedPhotoIDs.compactMap { byID[$0] }
    }

    /// ピン留め候補(解禁済みの自分の写真、新しい順)。
    private var unlockedPhotosForPinning: [LaterPhoto] {
        (currentProfile?.photos ?? [])
            .filter(\.isUnlocked)
            .sorted { $0.captureDate > $1.captureDate }
    }

    private var remainingPinSlots: Int {
        max(0, UserProfile.maxPinnedPhotos - (currentProfile?.pinnedPhotoIDs.count ?? 0))
    }

    private func addPins(_ newIDs: [UUID]) {
        guard let profile = currentProfile else { return }
        var ids = profile.pinnedPhotoIDs
        for id in newIDs where !ids.contains(id) {
            ids.append(id)
        }
        profile.pinnedPhotoIDs = Array(ids.prefix(UserProfile.maxPinnedPhotos))
        try? context.save()
    }

    private func removePin(_ id: UUID) {
        guard let profile = currentProfile else { return }
        profile.pinnedPhotoIDs.removeAll { $0 == id }
        try? context.save()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    // プロフィールが1件も無くても、フォールバック値でカード自体は必ず描画する
                    // (以前はif let currentProfileで丸ごと非表示にしており、それが不具合の原因だった)。
                    ProfileChekiCard(
                        name: (currentProfile?.name).flatMap { $0.isEmpty ? nil : $0 } ?? "ゲスト",
                        username: (currentProfile?.username).flatMap { $0.isEmpty ? nil : $0 } ?? "guest",
                        bio: currentProfile?.bio ?? "",
                        profileImageData: currentProfile?.profileImageData,
                        updatedAt: currentProfile?.profileUpdatedAt,
                        seed: currentProfile?.id ?? Self.fallbackSeed,
                        isEditable: true,
                        onEdit: { isShowingSetup = true }
                    )
                    .padding(.horizontal, 20)

                    if let selfTags = currentProfile?.selfTags, !selfTags.isEmpty {
                        selfTagsRow(selfTags)
                            .padding(.horizontal, 20)
                    }

                    pinsSection
                        .padding(.top, 2)
                }
                .padding(.top, 8)
                .padding(.bottom, 90)
            }
            .scrollIndicators(.hidden)
            .background(Color.laterBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $isShowingSetup) {
                ProfileEditView()
            }
            .fullScreenCover(isPresented: $isShowingSettingsMenu) {
                SettingsMenuView(isShowing: $isShowingSettingsMenu)
                    .transition(.move(edge: .trailing))
            }
            .sheet(isPresented: $isShowingPinPicker) {
                PinPhotoPickerView(
                    photos: unlockedPhotosForPinning,
                    alreadyPinnedIDs: Set(currentProfile?.pinnedPhotoIDs ?? []),
                    remainingSlots: remainingPinSlots,
                    onConfirm: { newIDs in addPins(newIDs) }
                )
            }
        }
    }

    /// 初回設定で選んだ「自分を表すタグ」(撮影時のハッシュタグとは別物)。
    private func selfTagsRow(_ tags: [String]) -> some View {
        HStack(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text("#\(tag)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(hex: "1C1C1E")))
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("自分を表すタグ:\(tags.joined(separator: "、"))")
    }

    // MARK: - ①ヘッダー(左右両端にアイコン1つずつ。ロゴは廃止)

    private var header: some View {
        HStack {
            Spacer()

            headerButton(icon: "gearshape.fill") {
                isShowingSettingsMenu = true
            }
        }
        .padding(.horizontal, 20)
    }

    private func headerButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.laterText)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Color.laterCard))
        }
        .buttonStyle(.plain)
    }


    // MARK: - ④ピン留めセクション

    private var pinsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ピン留め")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.laterTextMuted)

                Spacer()

                if !pinnedPhotos.isEmpty && remainingPinSlots > 0 {
                    Button {
                        isShowingPinPicker = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Self.accent.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 24)

            if pinnedPhotos.isEmpty {
                Button {
                    isShowingPinPicker = true
                } label: {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .foregroundStyle(Color.white.opacity(0.22))
                        .frame(height: 100)
                        .overlay(
                            VStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .medium))
                                Text("追加")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(Color.laterTextMuted)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(pinnedPhotos, id: \.id) { photo in
                            pinnedPhotoCard(photo)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }

    /// ピン留め済み写真1枚のカード。右上の×ボタン、または長押しのどちらでも解除できる。
    private func pinnedPhotoCard(_ photo: LaterPhoto) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.white.opacity(0.05)
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .onLongPressGesture {
                HapticsManager.tick()
                removePin(photo.id)
            }

            Button {
                removePin(photo.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.black.opacity(0.65)))
            }
            .offset(x: 6, y: -6)
        }
    }

}

// MARK: - 🎯 プロフィール編集画面（@AppStorageと完全同期）
struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    // 🎯 オンボーディングと共通の@AppStorageキー
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("userBio") private var userBio: String = ""
    @AppStorageData("profileImageData") private var profileImageData: Data?

    // 編集用の一時State
    @State private var inputName: String = ""
    @State private var inputUserID: String = ""
    @State private var inputBio: String = ""
    @State private var inputImageData: Data?
    @State private var selectedItem: PhotosPickerItem?
    @State private var pendingCropImage: UIImage?
    @State private var showingCropEditor = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // プロフィール画像セクション
                        profileImageSection

                        // フォームセクション
                        formSection
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveProfile()
                    }
                    .foregroundStyle(Color.brandGreen)
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
                }
            }
            .onAppear {
                // 実際のUserProfile(SwiftData)から読み込む。以前は@AppStorageから
                // 読み込んでおり、オンボーディングを経由していない環境(デバッグ注入等)では
                // AppStorageが空のままUserProfileとズレて、保存ボタンが常時disabledに
                // なる/保存内容が食い違う原因になっていた。無ければAppStorage→空文字の順で
                // フォールバックする。
                if let user = UserProfile.current(from: profiles) {
                    inputName = user.name
                    inputUserID = user.username
                    inputBio = user.bio
                    inputImageData = user.profileImageData
                } else {
                    inputName = userName
                    inputUserID = userID
                    inputBio = userBio
                    inputImageData = profileImageData
                }
            }
            .onChange(of: selectedItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        // 選び直した写真はまず正方形クロップ編集を挟む(SquareImageCropView)。
                        // チェキ加工の焼き込みはクロップ確定後に行う。
                        pendingCropImage = uiImage
                        showingCropEditor = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCropEditor) {
                if let image = pendingCropImage {
                    SquareImageCropView(sourceImage: image) { croppedData in
                        showingCropEditor = false
                        Task {
                            // プロフィール画像は「解禁時に一度だけ焼き込む」写真とは異なり、
                            // 本人が選び直した瞬間にだけ発生する一回きりの操作のため、
                            // ここで焼き込んでおく(表示のたびに毎回加工していた以前の設計を
                            // 統一する)。
                            inputImageData = await ChekiColorGrade.bakedData(from: croppedData) ?? croppedData
                        }
                    } onCancel: {
                        showingCropEditor = false
                        pendingCropImage = nil
                        selectedItem = nil
                    }
                }
            }
        }
    }

    // MARK: - サブビュー

    /// チェキ(ProfileChekiCard/ChekiPhotoFrame)と全く同じ白フレーム色・比率でプレビューする。
    /// 編集時に見えていた構図とチェキの実際の表示結果がズレないよう、円形マスクはやめ、
    /// チェキ本体と同じ正方形(1:1)+7px内側パディング+角丸2pxの構造をそのまま踏襲する。
    private let chekiFrameColor = Color(red: 0.969, green: 0.961, blue: 0.933) // #f7f5ee

    /// 正方形プレビューの一辺の長さ(固定値なのでGeometryReader不要)。
    private static let previewPhotoSize: CGFloat = 126

    private var profileImageSection: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    photoPreviewArea
                        .padding(7)
                        .background(chekiFrameColor)
                        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)

                    editBadge
                        .offset(x: 8, y: 8)
                }
            }

            Text("写真をタップして変更(チェキと同じ比率で表示されます)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    /// .aspectRatio(1, .fit)だけに頼ると、高さが不定な文脈で縦長画像の
    /// 理想サイズが外側へ漏れて正方形化が崩れることがあるため、
    /// 幅・高さを両方明示した.frame(width:height:)を必ず併用する。
    @ViewBuilder
    private var photoPreviewArea: some View {
        ZStack {
            if let imageData = inputImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.white.opacity(0.08)
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .frame(width: Self.previewPhotoSize, height: Self.previewPhotoSize)
        .clipped()
    }

    private var editBadge: some View {
        ZStack {
            Circle()
                .fill(Color.brandGreen)
                .frame(width: 32, height: 32)
                .shadow(color: Color.brandGreen.opacity(0.5), radius: 8, x: 0, y: 4)

            Image(systemName: "camera.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var formSection: some View {
        VStack(spacing: 20) {
            // 名前（表示名）
            FormField(
                label: "名前（表示名）",
                icon: "person.circle.fill",
                text: $inputName,
                placeholder: "例: 山田太郎"
            )

            // ユーザーID（@ID）
            FormField(
                label: "ユーザーID（@ID）",
                icon: "at",
                text: $inputUserID,
                placeholder: "例: yamada_taro",
                prefix: "@"
            )

            // 一言バイオ（自己紹介）
            FormFieldMultiline(
                label: "一言バイオ（自己紹介）",
                icon: "text.quote",
                text: $inputBio,
                placeholder: "今の気分は？"
            )
        }
    }

    // MARK: - バリデーション

    private var isFormValid: Bool {
        !inputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !inputUserID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        inputUserID.count >= 3
    }

    // MARK: - 保存処理

    private func saveProfile() {
        // 🎯 @AppStorageに保存（オンボーディングと自動同期）
        userName = inputName
        userID = inputUserID
        userBio = inputBio
        profileImageData = inputImageData

        // 実際のUserProfile(SwiftData)にも反映し、参加中の全グループへ再同期する。
        // 1件も存在しない場合(オンボーディング未完了など)はここで新規作成する —
        // でないと「編集」から保存しても何も永続化されず、フォールバック表示のままになる。
        let user: UserProfile
        if let existing = UserProfile.current(from: profiles) {
            user = existing
        } else {
            user = UserProfile(name: inputName, username: inputUserID)
            modelContext.insert(user)
        }

        user.name = inputName
        user.username = inputUserID
        user.bio = inputBio
        user.profileImageData = inputImageData
        user.profileUpdatedAt = Date()
        try? modelContext.save()

        if let cloudKitManager = CloudKitManager.current {
            for group in user.groups {
                cloudKitManager.markForUpload(userProfile: user, in: group)
            }
        }

        // 公開ディレクトリ(laterapp://リンク/QRで共有した相手が引く用)も最新化する。
        Task { await UserDirectoryService.publish(user) }

        // 成功のHaptic
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)

        dismiss()
    }
}

// MARK: - フォームフィールドコンポーネント
struct FormField: View {
    let label: String
    let icon: String
    @Binding var text: String
    let placeholder: String
    var prefix: String? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(label)
            } icon: {
                Image(systemName: icon)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(0.8))

            HStack(spacing: 12) {
                if let prefix = prefix {
                    Text(prefix)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.brandGreen)
                }

                TextField(text: $text) {
                    Text(placeholder)
                }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .focused($isFocused)
                    .textInputAutocapitalization(prefix != nil ? .never : .words)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isFocused ? Color.brandGreen.opacity(0.5) : Color.white.opacity(0.1),
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 複数行フォームフィールド
struct FormFieldMultiline: View {
    let label: String
    let icon: String
    @Binding var text: String
    let placeholder: String

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(label)
            } icon: {
                Image(systemName: icon)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(0.8))

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.brandGreen)
                    .padding(.top, 2)

                TextField(text: $text, axis: .vertical) {
                    Text(placeholder)
                }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(3...5)
                    .focused($isFocused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isFocused ? Color.brandGreen.opacity(0.5) : Color.white.opacity(0.1),
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .padding(.horizontal, 20)
    }
}
