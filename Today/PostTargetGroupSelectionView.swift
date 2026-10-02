import SwiftUI
import SwiftData

/// 撮影後の投稿準備画面。BeReal(即座に写真+キャプションを1画面で確認・投稿)と
/// setlog(1回の撮影を複数グループへ選択投稿)の要素を融合した構成:
/// チェキ風の「現像前」写真プレビュー → キャプション入力 → 投稿先グループの
/// 複数選択 → 投稿ボタン、を1本のスクロールにまとめている。
///
/// 「ME」(個人スペース)は投票フェーズや複数人での協調撮影という概念が無いため、
/// 常に自動選択(常時ON、外せない)で一覧の先頭に固定表示する。それ以外のグループは、
/// GroupStatusPresenter/GroupUnlockPolicyの既存ロジックで「今まさに撮影可能か」を
/// グループ単位で判定し、不可なものはチェックボックスを非活性にする。
///
/// 注意: 以前はキャプション入力を別画面(CaptionEntryPromptView)に分け、そちらでは
/// 「写真そのものは撮影者本人にも一切見せない」方針を明記していた。この画面では
/// ご指示に基づき、撮影直後の写真を(暗め・低彩度の「未現像」エフェクト越しに)
/// プレビュー表示する。はっきり見える解禁後の見た目とは明確に区別しているが、
/// 「本人にも見せない」という以前の前提からは踏み込んだ変更になっている点に留意。
struct PostTargetGroupSelectionView: View {
    let imageData: Data
    /// 撮影時点で取得できていた撮影地の地名(位置情報の許可が無い/取得失敗ならnil)。
    var locationName: String? = nil
    /// nilなら成功、値があれば失敗理由(呼び出し側が保存/破棄いずれの後始末をすべきか判断できるよう
    /// successフラグと合わせて渡す)。
    let onFinished: (_ success: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]

    @State private var caption: String

    /// 2026/9 新デザイン仕様「②キャプション入力画面」で、撮影の前にキャプションを
    /// 書くフローになったため、そちらで入力済みの文字列をここへ引き継ぐ
    /// (この画面で改めて入力し直す必要が無いよう、初期値として渡すだけ)。
    init(
        imageData: Data,
        locationName: String? = nil,
        initialCaption: String = "",
        onFinished: @escaping (_ success: Bool) -> Void
    ) {
        self.imageData = imageData
        self.locationName = locationName
        self.onFinished = onFinished
        _caption = State(initialValue: initialCaption)
    }
    /// キャプションのボタン/入力欄どちらを表示するか(表示分岐用)。isCaptionFocusedとは
    /// 意図的に分離している(理由はcaptionOverlay内のコメント参照)。
    @State private var isEditingCaption = false
    @FocusState private var isCaptionFocused: Bool
    @State private var selectedGroupIDs: Set<UUID> = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    /// 「送信先」ボタンから開く、投稿先選択専用画面(PostTargetSelectionSheet)の表示状態。
    @State private var isShowingDestinationPicker = false
    /// World Later(匿名グローバルフィード)へも同時に投稿するかどうか。Circle/MEへの
    /// 投稿とは完全に独立した経路(WorldLaterService)で、選ばなくてもCircle/ME側の
    /// 投稿には一切影響しない。
    @State private var postToWorldLater = false

    private static let chekiFrameColor = Color(red: 0.969, green: 0.961, blue: 0.933) // #f7f5ee

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    private var userGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }.meFirstOrdered()
    }

    private var meGroup: LaterGroup? {
        userGroups.first(where: \.isPersonalSpace)
    }

    private var otherGroups: [LaterGroup] {
        userGroups.filter { !$0.isPersonalSpace }
    }

    private var selectableOtherGroups: [LaterGroup] {
        otherGroups.filter(isSelectable)
    }

    var body: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
                // キャプション入力欄以外の余白をタップしたら入力を確定してキーボードを閉じる。
                // このonTapGestureは背景(この階層で一番奥)にしか付けていないため、キャプションの
                // ボタン/入力欄自身への通常のタップは(手前にある分)そちらが優先して受け取り、
                // ここには伝播しない。
                .onTapGesture { isCaptionFocused = false }

            VStack(spacing: 0) {
                header

                Divider().background(Color.white.opacity(0.08))

                ScrollView {
                    chekiPreview
                        .padding(.top, 24)
                        .padding(.bottom, 12)
                }
                .scrollDismissesKeyboard(.interactively)

                worldLaterToggleRow
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.red.opacity(0.85))
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                }

                submitButton
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            initializeSelectionIfNeeded()
        }
        .sheet(isPresented: $isShowingDestinationPicker) {
            PostTargetSelectionSheet(
                userGroups: userGroups,
                currentUser: currentUser,
                selectedGroupIDs: $selectedGroupIDs
            )
        }
    }

    // MARK: - ヘッダー

    private var header: some View {
        HStack {
            Button {
                onFinished(false)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }

            Spacer()

            Text("投稿")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            destinationButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// 「送信先」ボタン。緑ボーダー+薄い緑背景のピル型。タップで投稿先選択画面(sheet)を開く。
    private var destinationButton: some View {
        Button {
            isShowingDestinationPicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(selectedGroupIDs.count)件")
                    .font(.system(size: 15, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Self.captionAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(Self.captionAccent.opacity(0.12))
            )
            .overlay(
                Capsule().strokeBorder(Self.captionAccent, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// World Later(匿名グローバルフィード)への同時投稿トグル。Circle/MEへの投稿先
    /// 選択(selectedGroupIDs)とは独立した、単純なON/OFFのみ。
    private var worldLaterToggleRow: some View {
        Toggle(isOn: $postToWorldLater) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Text("World Laterにも投稿する(匿名)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .tint(Color.brandGreen)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - チェキ風「現像前」写真プレビュー(画面の主役として大きく表示)

    private var chekiPreview: some View {
        VStack(spacing: 0) {
            undevelopedPhotoArea
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .padding(14)

            // チェキ(インスタントフィルム)特有の、下側だけ広い白フチ。
            HStack {
                Image(systemName: "hourglass")
                    .font(.system(size: 12, weight: .medium))
                Text("現像中…")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(Color.black.opacity(0.35))
            .frame(height: 48)
        }
        .background(Self.chekiFrameColor)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 22, x: 0, y: 10)
        .padding(.horizontal, 8)
    }

    /// 撮影直後の写真を、まだ現像されていないことが一目で伝わる見た目(ほぼ真っ暗、
    /// 輪郭や色がほんの少ししか判別できないレベルの強い暗化)で描画する。解禁後に
    /// ChekiPhotoFrame/ChekiColorGradeが行う「発色を整えた」見せ方とは明確に区別している。
    /// 左上にBeReal風のキャプション入力(captionOverlay)を重ねる。写真自身への
    /// タップは(キャプションのボタン/入力欄より奥にあるため)キャプション以外の
    /// 領域をタップした場合にだけ届き、入力中ならフォーカスを外して確定させる。
    private var undevelopedPhotoArea: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .saturation(0.15)
                        .brightness(-0.5)
                        .contrast(0.75)
                        .overlay(Color.black.opacity(0.9))
                } else {
                    Color.black.opacity(0.92)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { isCaptionFocused = false }

            captionOverlay
                .padding(14)
        }
        .clipped()
    }

    // MARK: - キャプション入力(BeReal風。タップ前は控えめなボタン、タップ後は入力欄に切り替わる)

    private static let captionAccent = Color.brandGreen
    private static let captionPlaceholderColor = Color(hex: "d8d6cf")
    private static let captionTextColor = Color(hex: "f5f3ee")

    private var captionOverlay: some View {
        Group {
            if isEditingCaption {
                TextField("キャプションを入力", text: $caption)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Self.captionTextColor)
                    .tint(Self.captionAccent)
                    .focused($isCaptionFocused)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: 240, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.65))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Self.captionAccent, lineWidth: 1)
                    )
            } else {
                // タップ前(未入力なら「+ キャプション」、入力済みならテキストそのものを表示)。
                Button {
                    isEditingCaption = true
                    // isEditingCaptionをtrueにしたこの時点ではまだTextField自体が
                    // ツリーに存在しない(次の再描画で初めて生成される)ため、同じフレームで
                    // isCaptionFocused = trueにしても紐付かないことがある。1ティック
                    // 遅らせてTextFieldが実在してからフォーカスさせる。
                    DispatchQueue.main.async {
                        isCaptionFocused = true
                    }
                } label: {
                    HStack(spacing: 5) {
                        if caption.isEmpty {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(caption.isEmpty ? "キャプション" : caption)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Self.captionPlaceholderColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: 240, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.5))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        // キーボードが閉じられた(フォーカスが外れた)ら、表示もボタンへ戻す。
        .onChange(of: isCaptionFocused) { _, focused in
            if !focused {
                isEditingCaption = false
            }
        }
    }

    // MARK: - 送信ボタン

    /// 投稿先が1つも無い(グループ未選択かつWorld Laterもオフ)かどうか。submitPost()の
    /// ガード条件(!selectedGroupIDs.isEmpty || postToWorldLater)と必ず一致させること。
    /// 以前はここがselectedGroupIDs.isEmptyだけを見ており、「グループは選ばずWorld
    /// Laterだけに投稿したい」場合でもボタンが押せないままになる不具合があった。
    private var hasNoDestination: Bool {
        selectedGroupIDs.isEmpty && !postToWorldLater
    }

    private var submitButton: some View {
        Button(action: submitPost) {
            Group {
                if isSubmitting {
                    ProgressView().tint(.black)
                } else {
                    Text("送信する")
                }
            }
            .font(.headline)
            .foregroundStyle(hasNoDestination ? .white.opacity(0.4) : .black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(hasNoDestination ? Color.white.opacity(0.08) : Color.brandGreen)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(hasNoDestination || isSubmitting)
    }

    // MARK: - 選択状態の判定

    /// MEは常時ON扱いのため対象外。それ以外は、その時点で自分が撮ってよい上限
    /// (GroupUnlockPolicy.individualMaximumPhotoCount(for:))未満であること。
    /// 時間帯制限の撤廃に伴い、状態(.shooting/.unlocked)を問わずいつでも撮影できる。
    private func isSelectable(_ group: LaterGroup) -> Bool {
        todaysCount(in: group) < GroupUnlockPolicy.individualMaximumPhotoCount(for: group)
    }

    private func todaysCount(in group: LaterGroup) -> Int {
        guard let myID = currentUser?.id else { return 0 }
        // 動画も同じ枚数カウント対象にする(仕様変更)ため、写真+動画の合算を使う。
        return group.currentCycleContentCount(ownerID: myID)
    }

    /// デフォルトは「選択可能な全グループ」(全選択、MEも含む)。グループ詳細画面の
    /// 撮影ボタンから来た場合も、その特定のグループを含む全選択がそのまま
    /// 「そのグループにチェックが入った状態」を満たす。MEはあくまでデフォルトで
    /// 選択されているだけで、ユーザーが他のグループと同様に外すこともできる。
    private func initializeSelectionIfNeeded() {
        guard selectedGroupIDs.isEmpty else { return }
        var defaults = Set(selectableOtherGroups.map(\.id))
        if let meGroup, isSelectable(meGroup) {
            defaults.insert(meGroup.id)
        }
        selectedGroupIDs = defaults
    }

    // MARK: - 投稿処理

    private func submitPost() {
        guard let user = currentUser, !isSubmitting else { return }
        guard !selectedGroupIDs.isEmpty || postToWorldLater else { return }
        isSubmitting = true
        errorMessage = nil
        isCaptionFocused = false

        let now = Date()
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)

        // MEも他のグループと同じくユーザーが選択/解除できる対象のため、選ばれていなければ
        // 強制的には投稿しない(以前はここで無条件にMEを追加していた)。
        let targets = selectedGroupIDs.compactMap { id in userGroups.first(where: { $0.id == id }) }

        var inserted: [(photo: LaterPhoto, group: LaterGroup)] = []

        for group in targets {
            // 選択後、画面表示中に締切/上限を跨いだ可能性があるための最終チェック
            // (MEもisSelectable(_:)で同じ基準により判定する)。
            guard isSelectable(group) else { continue }

            // unlockDateは実際に解禁された瞬間にCloudKitManager.evaluateGroupUnlockConditionsが
            // 上書きする(LaterPhoto.imageCacheKey/LaterGroup.mostRecentCyclePhotos参照)。
            // 撮影直後はまだ解禁されていないため、ここでは単に現在時刻を入れておくだけでよい
            // (以前あった「1〜4日後のランダムな未来日時」という旧設計の計算値は、
            // 時間帯制限撤廃・全員撮影ゲート方式への移行で意味を持たなくなった)。
            let newPhoto = LaterPhoto(
                imageData: imageData,
                captureDate: now,
                unlockDate: now,
                owner: user,
                caption: trimmedCaption.isEmpty ? nil : trimmedCaption
            )
            newPhoto.authorCloudKitUserRecordName = CloudKitManager.current?.currentUserRecordName
            newPhoto.authorNameCache = user.name
            newPhoto.locationName = locationName
            newPhoto.groupID = group.id
            newPhoto.groupNameCache = group.name
            context.insert(newPhoto)
            group.photos.append(newPhoto)
            inserted.append((newPhoto, group))
        }

        guard !inserted.isEmpty || postToWorldLater else {
            isSubmitting = false
            errorMessage = "投稿できるグループがありませんでした。締切や上限をご確認ください。"
            return
        }

        if !inserted.isEmpty {
            do {
                try context.save()
            } catch {
                print("[PhotoSave Error] 一括投稿のローカル保存に失敗: \(error)")
                for (photo, _) in inserted { context.delete(photo) }
                isSubmitting = false
                errorMessage = "保存に失敗しました。もう一度お試しください。"
                return
            }
        }

        // World Laterへの投稿はCircle/MEへの投稿と完全に独立した経路(Public DB、
        // 撮影者情報を含めない)のため、Circle/ME側の成否と関係なく単独で送信する。
        if postToWorldLater {
            Task {
                do {
                    try await WorldLaterService.submitPost(
                        imageData: imageData,
                        captureDate: now,
                        locationRegion: locationName,
                        caption: trimmedCaption.isEmpty ? nil : trimmedCaption
                    )
                } catch {
                    print("[WorldLater] submitPost failed: \(error)")
                }
            }
        }

        // markForUploadはCKSyncEngineのキューに積むだけで送信自体は保証しないため、
        // グループ参加時の不具合(uploadOwnProfile)と同じ理由で、ここでも明示的に
        // 送信を強制する。投稿直後にアプリを閉じても、他メンバーへ確実に届くようにする。
        if let cloudKitManager = CloudKitManager.current {
            Task {
                for (photo, group) in inserted {
                    await cloudKitManager.markForUpload(photo: photo, in: group)
                    // ローカルへ新規写真を挿入しただけではCKSyncEngineの変更通知
                    // (apply(record:)経由)は発生しないため、evaluateGroupUnlockConditions
                    // 側のdirty判定に拾われるよう明示的にマークする(3秒ポーリング側の
                    // 「変化があったグループだけ処理する」最適化の対象から漏れないように)。
                    cloudKitManager.markGroupDirty(group.id)
                }
                await cloudKitManager.evaluateGroupUnlockConditions()
                await cloudKitManager.sendPendingChangesNow()
            }
        }

        isSubmitting = false
        HapticsManager.shutterClick()
        // 成功フィードバック(トースト)はTodayView.successMessageOverlayを呼び出し側で
        // 表示する(この画面自体は即座に閉じてメイン画面へ戻る)。
        onFinished(true)
    }
}
