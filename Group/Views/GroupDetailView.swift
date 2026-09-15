import SwiftUI
import SwiftData
import CloudKit

/// グループ詳細画面。メンバー一覧と招待リンク発行を担当する。招待リンクの発行は
/// ホスト・非ホスト問わず全メンバーが行える(GroupSharingService.fetchOrCreateShareURL
/// 参照)。招待リンクはCKShare標準のURL(https://www.icloud.com/share/...)で、
/// 受け取った側がタップするとAppDelegate.userDidAcceptCloudKitShareWith経由で
/// 直接参加確認〜受け入れまで進む(GroupSharingService.acceptShare参照)。
struct GroupDetailView: View {
    let group: LaterGroup
    /// 脱退に成功した時、この画面自身のdismiss()に加えて追加で呼ぶコールバック。
    /// GroupHomeDetailViewからsheetとして開いている場合、GroupHomeDetailView自身も
    /// 一緒にdismissしてもらうことで、脱退後にいちいち手動で戻らなくても
    /// そのままHomeのグループ一覧まで戻れるようにする(呼び出し元を問わない他の
    /// 経路(CircleManagementView等)ではnilのままでよい)。
    var onLeaveSuccess: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @State private var shareURL: URL?
    @State private var isPreparingLink = false
    @State private var errorMessage: String?
    @State private var showingLeaveConfirmation = false
    @State private var isLeaving = false
    @State private var leaveErrorMessage: String?
    @State private var showingEditGroup = false
    @State private var reportTargetMember: UserProfile?
    @State private var blockTargetMember: UserProfile?
    @State private var isBlocking = false

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    /// ownerCloudKitUserRecordName(CKRecordとして同期される)基準の判定。ホスト脱退時の
    /// 引き継ぎ後も全メンバーの端末で正しく最新のホストを反映できる。
    private var isHost: Bool {
        group.isHost(cloudKitUserRecordName: currentUser?.cloudKitUserRecordName)
    }

    private var willTransferHost: Bool {
        isHost && group.members.contains(where: { $0.id != currentUser?.id })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                inviteSection

                membersSection

                if !group.isPersonalSpace {
                    dangerZoneSection
                }
            }
            .padding(20)
        }
        .background(Color.brandBlack.ignoresSafeArea())
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: group.id) {
            // 招待リンク発行後、ホストがこの画面を開いたまま参加を待つケースを想定し、
            // 開いている間はプッシュ通知の到達を待たず定期的に最新メンバーを取りに行く
            // (GroupHomeDetailView.taskと同じ方針)。
            while !Task.isCancelled {
                await refreshMembers()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
        .alert("グループから脱退しますか?", isPresented: $showingLeaveConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("脱退する", role: .destructive) {
                Task { await leaveGroup() }
            }
        } message: {
            Text(leaveConfirmationMessage)
        }
        .sheet(isPresented: $showingEditGroup) {
            EditGroupView(group: group)
        }
        .sheet(item: $reportTargetMember) { member in
            ReportSheet(targetType: .user, targetID: member.cloudKitUserRecordName ?? member.id.uuidString)
        }
        .alert("ブロックしますか?", isPresented: Binding(
            get: { blockTargetMember != nil },
            set: { if !$0 { blockTargetMember = nil } }
        )) {
            Button("キャンセル", role: .cancel) { blockTargetMember = nil }
            Button("ブロックする", role: .destructive) {
                if let member = blockTargetMember { Task { await block(member) } }
            }
        } message: {
            Text("ブロックすると、今後このユーザーの投稿があなたの画面に表示されなくなります。")
        }
    }

    private func block(_ member: UserProfile) async {
        guard let recordName = member.cloudKitUserRecordName else {
            blockTargetMember = nil
            return
        }
        isBlocking = true
        defer { isBlocking = false; blockTargetMember = nil }
        try? await ModerationService.blockUser(cloudKitUserRecordName: recordName, modelContext: modelContext)
    }

    private var leaveConfirmationMessage: String {
        if willTransferHost {
            return "「\(group.name)」から脱退します。ホスト権限は自動的に他のメンバーへ引き継がれます。"
        }
        if isHost {
            return "あなたが最後のメンバーです。脱退すると「\(group.name)」は完全に削除され、この操作は取り消せません。"
        }
        return "「\(group.name)」から脱退します。このグループの記録にはもうアクセスできなくなります。"
    }

    // MARK: - ヘッダー

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            GroupIconView(iconImageData: group.iconImageData, groupName: group.name, size: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(group.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    Label("\(group.members.count)/\(GroupMembershipPolicy.maxMembersPerGroup)人", systemImage: "person.2.fill")
                    Label("\(group.photos.count + group.videos.count)枚", systemImage: "photo.fill")
                }
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 0)

            // グループ名・アイコンの編集はオーナーに限らず全メンバーが行える
            // (招待リンク発行等のホスト限定操作とは異なる)。
            Button {
                showingEditGroup = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
        }
    }

    // MARK: - 招待リンク(全メンバー)

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("招待リンク")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.red.opacity(0.85))
            }

            if let shareURL {
                // 標準のhttps://www.icloud.com/share/...のままタップすると、iOS側の判断で
                // アプリではなくSafari(iCloudのWebページ)が開いてしまい参加処理に進めない
                // ことがある。一方later://join?shareUrl=...のカスタムスキームはタップされれば
                // 確実にこのアプリが直接開く(OS判断のゆらぎが無い)。ただしURLオブジェクトの
                // ままShareLinkへ渡すと、LINE等一部アプリの共有シートで
                // 「Cannot issue sandbox extension」エラーになり共有自体が失敗することがあった
                // ため、プレーンなテキスト(String)として共有することでその問題を回避する。
                let joinLinkText = (GroupJoinLink.buildURL(shareURL: shareURL) ?? shareURL).absoluteString
                ShareLink(item: "laterで一緒に写真を撮ろう!グループ参加リンクはこちら: \(joinLinkText)") {
                    inviteButtonLabel(title: "招待リンクを送る", systemImage: "square.and.arrow.up")
                }
            } else {
                Button {
                    Task { await prepareShareURL() }
                } label: {
                    inviteButtonLabel(
                        title: isPreparingLink ? "準備中…" : "招待リンクを作成",
                        systemImage: "link.badge.plus"
                    )
                }
                .disabled(isPreparingLink)
            }
        }
    }

    private func inviteButtonLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            if isPreparingLink {
                ProgressView()
                    .tint(.black)
            } else {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.brandGreen)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func prepareShareURL() async {
        guard let cloudKitManager = CloudKitManager.current else {
            errorMessage = "iCloudへの接続が完了していません。しばらくしてから再度お試しください。"
            return
        }

        isPreparingLink = true
        errorMessage = nil
        defer { isPreparingLink = false }

        let sharingService = GroupSharingService(container: cloudKitManager.container, modelContext: modelContext, cloudKitManager: cloudKitManager)
        do {
            shareURL = try await sharingService.fetchOrCreateShareURL(for: group)
        } catch {
            errorMessage = error.loggedDescription(context: "GroupDetailView.prepareShareURL")
        }
    }

    // MARK: - メンバー一覧

    /// 画面表示時に、このグループのゾーンを直接フェッチして最新のメンバー構成を取り込む。
    /// 招待直後などCKSyncEngineの自律的な同期がまだ追いついていないタイミングでこの画面を
    /// 開いても、アプリの再起動やプルリフレッシュを挟まずに最新のメンバー一覧が反映される
    /// (CloudKitManager.fetchAndApplyZoneImmediately — CKShare受諾直後の即時反映と同じ経路)。
    private func refreshMembers() async {
        print("[GroupSync] GroupDetailView.refresh開始: group=\(group.name)")
        guard let cloudKitManager = CloudKitManager.current, let zoneID = group.cachedZoneID else {
            print("[GroupSync] GroupDetailView.refresh中断: cloudKitManagerまたはzoneIDが未確定")
            return
        }
        await cloudKitManager.fetchAndApplyZoneImmediately(zoneID: zoneID)
        await ensureOwnMembershipIsSynced(cloudKitManager: cloudKitManager)
        print("[GroupSync] GroupDetailView.refresh完了: group=\(group.name)")
    }

    /// 自分自身のUserProfileレコードが本当にこのグループの共有ゾーンに存在するかを
    /// 都度確認し、無ければ再送信する自己修復処理。古いビルドで作成されたグループでは、
    /// グループ本体/共有リンクの作成自体は成功していても、ホスト自身のプロフィール
    /// レコードの保存だけが検知されずに欠落したまま残っているケースがあった
    /// (欠落したままだと、いくら受信側のロジックを直しても「存在しないデータ」なので
    /// 永久に他メンバーへ反映されない)。ここで開くたびに再送することで、
    /// 過去に壊れたグループも次に開いた時点で自動的に直る。
    private func ensureOwnMembershipIsSynced(cloudKitManager: CloudKitManager) async {
        guard let currentUser else { return }
        if !group.isMember(currentUser) {
            _ = group.addMember(currentUser)
        }
        let sharingService = GroupSharingService(container: cloudKitManager.container, modelContext: modelContext, cloudKitManager: cloudKitManager)
        await sharingService.uploadOwnProfile(currentUser, to: group)
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("メンバー")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            VStack(spacing: 0) {
                ForEach(group.members, id: \.id) { member in
                    memberRow(member)
                    if member.id != group.members.last?.id {
                        Divider().overlay(Color.white.opacity(0.08))
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
        }
    }

    private func memberRow(_ member: UserProfile) -> some View {
        HStack(spacing: 12) {
            CachedPhotoImage(imageData: member.profileImageData, cacheKey: "avatar_\(member.id.uuidString)") { uiImage in
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(member.name.prefix(1))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                    )
            }

            Text(member.name)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            if group.isHost(cloudKitUserRecordName: member.cloudKitUserRecordName) {
                Text("ホスト")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.brandGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.brandGreen.opacity(0.15)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu {
            if member.id != currentUser?.id {
                Button {
                    reportTargetMember = member
                } label: {
                    Label("報告する", systemImage: "flag")
                }
                Button(role: .destructive) {
                    blockTargetMember = member
                } label: {
                    Label("ブロックする", systemImage: "hand.raised.fill")
                }
            }
        }
    }

    // MARK: - 脱退

    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let leaveErrorMessage {
                Text(leaveErrorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.red.opacity(0.85))
            }

            Button {
                showingLeaveConfirmation = true
            } label: {
                HStack(spacing: 8) {
                    if isLeaving {
                        ProgressView().tint(.red)
                    } else {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    Text("グループから脱退")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.red.opacity(0.4), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.red.opacity(0.08))
                        )
                )
            }
            .disabled(isLeaving)
        }
        .padding(.top, 8)
    }

    /// 自分がホストで他にメンバーが残っている場合は、ホスト権限(招待リンク発行など)を
    /// 自動的に他の1人へ引き継いでから脱退する。自分が最後の1人だった場合のみ
    /// グループごと削除する(GroupSharingService.leaveGroup参照)。
    /// ローカルのLaterGroupはこの呼び出し元で削除する(photosはcascadeで一緒に消える)。
    private func leaveGroup() async {
        guard let cloudKitManager = CloudKitManager.current, let currentUser else {
            leaveErrorMessage = "iCloudへの接続が完了していません。しばらくしてから再度お試しください。"
            return
        }

        isLeaving = true
        leaveErrorMessage = nil

        let sharingService = GroupSharingService(container: cloudKitManager.container, modelContext: modelContext, cloudKitManager: cloudKitManager)
        do {
            try await sharingService.leaveGroup(group, currentUser: currentUser, isHost: isHost)
        } catch {
            isLeaving = false
            leaveErrorMessage = error.loggedDescription(context: "GroupDetailView.leaveGroup")
            return
        }

        modelContext.delete(group)
        try? modelContext.save()
        isLeaving = false
        dismiss()
        onLeaveSuccess?()
    }
}
