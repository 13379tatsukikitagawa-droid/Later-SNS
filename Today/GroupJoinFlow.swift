import AVFoundation
import CloudKit
import SwiftData
import SwiftUI
import UIKit

// MARK: - 文言(法務の都合で変える可能性があるので、ここにまとめる)

enum JoinNotice {
    /// 入る前の説明(3行固定)
    static let lines = [
        "あなたの名前とアイコン(Later内のもの)が、メンバーに見えます。",
        "撮ると、このグループの昨日もひらけます。",
        "いつでも抜けられます。",
    ]
}

extension Notification.Name {
    /// 入るための画面(QR・合言葉)をひらく。object: JoinFlowStart
    static let joinFlowRequested = Notification.Name("joinFlowRequested")
    /// グループに入った(object: UUID)。Home の列に「ぽんと入る」+ お知らせ
    static let groupJoined = Notification.Name("groupJoined")
    /// Home に小さなお知らせ(object: String)
    static let homeToastRequested = Notification.Name("homeToastRequested")
}

/// 入るための画面の、はじまり
enum JoinFlowStart: Equatable {
    case scan
    case passphrase
    /// 招待リンク(later://join)・QR・合言葉から取り出した CKShare の URL
    case link(URL)
}

// MARK: - 入るためのデータ

/// 招待を受ける画面に出すもの(投稿の中身・位置・他のグループ名は持たない)
struct PreparedInvitation {
    let invitation: GroupInviteService.Invitation
    let metadata: CKShare.Metadata
    /// いまの人数(参加ずみ)
    let memberCount: Int
    /// 参加している人の識別子(顔の並びの種。名前は入る前には見えない)
    let participantKeys: [String]
    let check: JoinCheck
    /// すでに入っているとき、そのグループ
    let existingGroupID: UUID?

    var memberLimit: Int { invitation.memberLimit }
    /// あなたの席 = 次に光る点(12時から時計まわりに、光る点の次)
    var seatIndex: Int { min(memberCount, memberLimit - 1) }
}

@MainActor
enum GroupJoinService {
    enum Failure: Error, Equatable {
        case check(JoinCheck)
        case network
    }

    /// CKShare の URL → 招待の中身(グループのレコードの名前・上限・色・顔)・入れるかどうか
    static func prepare(shareURL: URL, context: ModelContext) async -> Result<PreparedInvitation, Failure> {
        guard let cloudKitManager = CloudKitManager.current else { return .failure(.network) }
        let metadata: CKShare.Metadata
        do {
            metadata = try await fetchMetadata(shareURL: shareURL, container: cloudKitManager.container)
        } catch let error as CKError where [.networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited].contains(error.code) {
            return .failure(.network)
        } catch {
            // 共有が取り消されている(作った人が止めた・グループが消えた)
            return .failure(.check(.unavailable))
        }
        let root = metadata.rootRecord
        let name = root?["name"] as? String ?? (metadata.share[CKShare.SystemFieldKey.title] as? String) ?? "グループ"
        let limit = GroupPalette.clampLimit(root?["memberLimit"] as? Int ?? GroupMembershipPolicy.maxMembersPerGroup)
        let color = root?["colorIndex"] as? Int ?? -1
        let iconData = (root?["icon"] as? CKAsset)?.fileURL.flatMap { try? Data(contentsOf: $0) }
        let invitation = GroupInviteService.Invitation(
            shareURL: shareURL,
            groupName: name,
            memberLimit: limit,
            colorIndex: GroupPalette.isValid(color) ? color : GroupPalette.index(forName: name),
            iconData: iconData
        )

        let accepted = metadata.share.participants.filter { $0.acceptanceStatus == .accepted }
        let user = UserProfile.current(from: (try? context.fetch(FetchDescriptor<UserProfile>())) ?? [])
        let rootName = metadata.hierarchicalRootRecordID?.recordName
        let existing = rootName.flatMap { name in
            (try? context.fetch(FetchDescriptor<LaterGroup>()))?.first { $0.ckRecordName == name }
        }
        let isMember = existing.map { group in user.map(group.isMember) ?? false } ?? false
        let joinedCount = user?.groups.filter { !$0.isPersonalSpace }.count ?? 0

        let check = JoinCheck.evaluate(
            isAlreadyMember: isMember,
            memberCount: accepted.count,
            memberLimit: limit,
            joinedGroupCount: joinedCount,
            expiresAt: nil,
            revoked: false,
            now: Date()
        )
        return .success(PreparedInvitation(
            invitation: invitation,
            metadata: metadata,
            memberCount: accepted.count,
            participantKeys: accepted.map { $0.userIdentity.userRecordID?.recordName ?? UUID().uuidString },
            check: check,
            existingGroupID: isMember ? existing?.id : nil
        ))
    }

    /// CKShare の情報と、グループのレコード(名前・上限・色・顔だけ)を読む
    private static func fetchMetadata(shareURL: URL, container: CKContainer) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareMetadataOperation(shareURLs: [shareURL])
            operation.shouldFetchRootRecord = true
            operation.rootRecordDesiredKeys = ["name", "memberLimit", "colorIndex", "icon"]
            var result: Result<CKShare.Metadata, Error>?
            operation.perShareMetadataResultBlock = { _, value in result = value }
            operation.fetchShareMetadataResultBlock = { final in
                switch (result, final) {
                case (.success(let metadata)?, _): continuation.resume(returning: metadata)
                case (.failure(let error)?, _): continuation.resume(throwing: error)
                case (nil, .failure(let error)): continuation.resume(throwing: error)
                case (nil, .success): continuation.resume(throwing: GroupInviteService.InviteError.notFound)
                }
            }
            container.add(operation)
        }
    }

    /// 入る:条件をもう一度たしかめ → CKShare に参加 → メンバーに追加 → 参加の直後に人数を数えなおす。
    /// 上限をこえていたら(同時に最後の1席に入った)、あとから入った自分が静かに抜けて「いっぱいです」。
    static func join(_ prepared: PreparedInvitation, context: ModelContext) async -> Result<LaterGroup, Failure> {
        guard let cloudKitManager = CloudKitManager.current,
              let user = UserProfile.current(from: (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []) else {
            return .failure(.network)
        }
        // 長押しのあいだに変わっていないか、もう一度
        if case .success(let fresh) = await prepare(shareURL: prepared.invitation.shareURL, context: context), fresh.check != .ok {
            return .failure(.check(fresh.check))
        }
        let sharing = GroupSharingService(container: cloudKitManager.container, modelContext: context, cloudKitManager: cloudKitManager)
        do {
            try await sharing.acceptShare(metadata: prepared.metadata)
        } catch GroupSharingError.groupFull {
            return .failure(.check(.full))
        } catch GroupSharingError.tooManyGroups {
            return .failure(.check(.tooManyGroups))
        } catch {
            return .failure(.network)
        }
        let rootName = prepared.metadata.hierarchicalRootRecordID?.recordName
        guard let group = (try? context.fetch(FetchDescriptor<LaterGroup>()))?.first(where: { $0.ckRecordName == rootName }) else {
            return .failure(.network)
        }
        if !group.isMember(user) { _ = group.addMember(user) }
        group.joinedAt = Date()
        try? context.save()

        // 参加の直後:人数を数えなおす(CKShare への参加はサーバーで止められないため)
        if let share = try? await cloudKitManager.container.sharedCloudDatabase.record(for: prepared.metadata.share.recordID) as? CKShare {
            let accepted = share.participants.filter { $0.acceptanceStatus == .accepted }.count
            if JoinCheck.isOverCapacity(acceptedCount: accepted, memberLimit: prepared.memberLimit) {
                try? await sharing.leaveGroup(group, currentUser: user, isHost: false)
                context.delete(group)
                try? context.save()
                return .failure(.check(.full))
            }
        }
        await sharing.uploadOwnProfile(user, to: group)
        GroupSelectionStore.shared.selectedGroupID = group.id
        return .success(group)
    }
}

// MARK: - 入るための画面(入り口 → 招待を受ける → 加入アニメ / エラー)

struct JoinFlowView: View {
    let start: JoinFlowStart
    let onFinish: () -> Void

    private enum Phase {
        case scan
        case passphrase
        case loading
        case invitation(PreparedInvitation)
        case failure(GroupJoinService.Failure, PreparedInvitation?)
    }

    @Environment(\.modelContext) private var modelContext
    @State private var phase: Phase = .loading
    @State private var haptics = ExposureHaptics()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .scan, .passphrase:
                // 読みとれたら、窓が丸になって招待の円につながる(中身はこの画面の中で取りに行く)
                QRScanView(
                    haptics: haptics,
                    startsWithPassphrase: isPassphrase,
                    prepare: { url in await GroupJoinService.prepare(shareURL: url, context: modelContext) },
                    onResolved: { result in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            switch result {
                            case .success(let prepared):
                                phase = prepared.check == .ok ? .invitation(prepared) : .failure(.check(prepared.check), prepared)
                            case .failure(let failure):
                                phase = .failure(failure, nil)
                            }
                        }
                    },
                    onClose: onFinish
                )
                .transition(.opacity)
            case .loading:
                ProgressView().tint(.white)
            case .invitation(let prepared):
                InvitationView(prepared: prepared, haptics: haptics, onFailure: { failure in
                    withAnimation(.easeInOut(duration: 0.4)) { phase = .failure(failure, prepared) }
                }, onDecline: {
                    NotificationCenter.default.post(name: .homeToastRequested, object: "入りませんでした")
                    onFinish()
                }, onHome: { group in
                    NotificationCenter.default.post(name: .groupJoined, object: group.id)
                    NotificationCenter.default.post(name: .homeToastRequested, object: "\(group.name) に入りました")
                    onFinish()
                })
                .transition(.opacity)
            case .failure(let failure, let prepared):
                JoinErrorView(failure: failure, prepared: prepared, onHome: onFinish, onPassphrase: {
                    withAnimation(.easeInOut(duration: 0.4)) { phase = .passphrase }
                }, onOpenGroup: {
                    if let id = prepared?.existingGroupID {
                        NotificationCenter.default.post(name: .openGroupRequested, object: id)
                    }
                    onFinish()
                }, onRetry: {
                    if let url = prepared?.invitation.shareURL { load(url) } else { onFinish() }
                })
                .transition(.opacity)
            }
        }
        .onAppear {
            haptics.prepare()
            switch start {
            case .scan: phase = .scan
            case .passphrase: phase = .passphrase
            case .link(let url): load(url)
            }
        }
        .onDisappear { haptics.tearDown() }
    }

    private var isPassphrase: Bool {
        if case .passphrase = phase { return true }
        return false
    }

    private func load(_ shareURL: URL) {
        withAnimation(.easeInOut(duration: 0.4)) { phase = .loading }
        Task {
            let result = await GroupJoinService.prepare(shareURL: shareURL, context: modelContext)
            withAnimation(.easeInOut(duration: 0.4)) {
                switch result {
                case .success(let prepared):
                    phase = prepared.check == .ok ? .invitation(prepared) : .failure(.check(prepared.check), prepared)
                case .failure(let failure):
                    phase = .failure(failure, nil)
                }
            }
        }
    }
}

// MARK: - 合言葉(シートの中身)

/// 合言葉の入力(QRを読む画面の「合言葉」シートの中身)。見つかったら onLink に CKShare の URL を渡す。
/// 判定・失敗・回数の制限は 5-3 / 6-2 のまま。
struct PassphraseEntryView: View {
    let haptics: ExposureHaptics
    let onLink: (URL) -> Void

    @State private var input = ""
    @State private var isChecking = false
    @State private var passphraseFeedback: PassphraseFeedback = .none
    @State private var lockUntil: Date?
    @State private var shakes: CGFloat = 0
    @FocusState private var focused: Bool

    var body: some View { passphraseView }

    // MARK: 合言葉

    private var passphraseView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 10) {
                        Text("合言葉を、\n入れてください。")
                            .font(.system(size: 27, weight: .bold))
                            .foregroundStyle(.white)
                        Text("教えてもらった言葉を、そのまま。")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "BCBBC0"))
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 34)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    passphraseField
                        .padding(.top, 28)

                    Text(passphraseNote)
                        .font(.system(size: 12.5))
                        .lineSpacing(3)
                        .foregroundStyle(passphraseFeedback == .notFound ? Color(hex: "FF9D92") : Color(hex: "8E8E93"))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                        .contentTransition(.opacity)
                }
                .padding(.horizontal, 22)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.never)

            // キーボードの上(キーボードに追従して、8〜10pt上)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                searchButton(now: context.date)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 10)
        }
        .onAppear {
            lockUntil = PassphraseAttempts.lockUntil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { if !isLocked { focused = true } }
        }
    }

    private var passphraseField: some View {
        let border: Color = passphraseFeedback == .notFound ? Color(hex: "FF7A6E") : .white.opacity(0.5)
        return VStack(alignment: .leading, spacing: 2) {
            Text("合言葉")
                .font(.system(size: 10.5))
                .foregroundStyle(Color(hex: "8E8E93"))
                .accessibilityHidden(true)
            TextField("", text: $input, prompt: Text("例:hikari-2741").foregroundStyle(Color(hex: "4A4A50")))
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.04 * 30)
                .foregroundStyle(.white)
                .tint(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($focused)
                .onSubmit(search)
                .disabled(isChecking || isLocked)
                .padding(.trailing, input.isEmpty ? 96 : 38)
                .onChange(of: input) { _, _ in
                    // 直しはじめたら、赤い枠をもとにもどす(入力は消さない)
                    if passphraseFeedback != .none, !isLocked { passphraseFeedback = .none }
                }
                .accessibilityLabel("合言葉、入力欄")
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.10), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(border, lineWidth: 1.5))
        .overlay(alignment: .bottomTrailing) { fieldAccessory.padding(12) }
        .opacity(isLocked ? 0.4 : 1)
        .modifier(ShakeEffect(animatableData: shakes))
        .animation(.easeOut(duration: 0.2), value: passphraseFeedback)
    }

    /// 空のとき「貼り付け」/ 入力があるとき「×」
    @ViewBuilder
    private var fieldAccessory: some View {
        if isChecking || isLocked {
            EmptyView()
        } else if input.isEmpty {
            // システムの PasteButton:ペーストの許可バナーが出ない
            PasteButton(payloadType: String.self) { strings in
                guard let text = strings.first?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
                haptics.playTransient(intensity: 0.3, sharpness: 0.5)
                // 招待リンクを貼ったときは、そのまま招待へ
                if let url = URL(string: text), let shareURL = InviteConfig.shareURL(from: url) {
                    onLink(shareURL)
                } else {
                    input = text
                }
            }
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .tint(.white.opacity(0.12))
            .labelStyle(.titleAndIcon)
            .frame(height: 32)
        } else {
            Button {
                input = ""
                passphraseFeedback = .none
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.white.opacity(0.18)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("消す")
        }
    }

    private func searchButton(now: Date) -> some View {
        let remaining = lockUntil.map { max(0, Int(ceil($0.timeIntervalSince(now)))) } ?? 0
        let locked = remaining > 0
        let enabled = canSearch && !locked
        let title: String = {
            if locked { return String(format: "%d:%02d 後に、もう一度", remaining / 60, remaining % 60) }
            return isChecking ? "さがしています…" : "グループをさがす"
        }()
        return Button(action: search) {
            HStack(spacing: 8) {
                if isChecking { ProgressView().tint(.black).controlSize(.small) }
                Text(title).monospacedDigit()
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(enabled || isChecking ? Color.black : Color(hex: "5D5D63"))
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Capsule().fill(enabled || isChecking ? Color.white : Color.white.opacity(0.08)))
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
        .disabled(!enabled)
        .onChange(of: locked) { wasLocked, isNowLocked in
            // 1分たった:もう一度入れられる
            if wasLocked, !isNowLocked {
                lockUntil = nil
                passphraseFeedback = .none
                PassphraseAttempts.unlock()
            }
        }
    }

    private var passphraseNote: String {
        switch passphraseFeedback {
        case .none: return "ひらがなでも、カタカナでも大丈夫です。"
        case .notFound: return "その合言葉は、見つかりません。\nもう一度、確かめてください。"
        case .network: return "通信できませんでした。もう一度お試しください。"
        case .locked: return "続けて見つからなかったので、\n少し待ってから、もう一度お試しください。"
        }
    }

    private var isLocked: Bool { lockUntil.map { $0 > Date() } ?? false }

    private var canSearch: Bool {
        !isChecking && !isLocked && GroupInviteService.normalizePassphrase(input).count >= 2
    }

    private func search() {
        guard canSearch else { return }
        haptics.playTransient(intensity: 0.3, sharpness: 0.5)
        isChecking = true
        passphraseFeedback = .none
        Task {
            defer { isChecking = false }
            do {
                let url = try await GroupInviteService.resolve(passphrase: input, timeout: 10)
                PassphraseAttempts.reset()
                // 見つかった:強く1回(QRを読みとれたときと同じ)
                haptics.playTransient(intensity: 1.0, sharpness: 0.7)
                focused = false
                onLink(url)
            } catch GroupInviteService.InviteError.notFound {
                // どのグループがあるかは教えない(近い言葉も出さない)
                if let until = PassphraseAttempts.recordFailure() {
                    lockUntil = until
                    passphraseFeedback = .locked
                    focused = false
                } else {
                    passphraseFeedback = .notFound
                }
                withAnimation(.linear(duration: 0.4)) { shakes += 1 }
                UIAccessibility.post(notification: .announcement, argument: passphraseNote)
            } catch {
                passphraseFeedback = .network
                UIAccessibility.post(notification: .announcement, argument: passphraseNote)
            }
        }
    }
}

/// 合言葉の失敗の回数(アプリ側の制限:5回続けて見つからない → 1分待つ)。
/// 画面を閉じてもリセットされないよう、端末に保存する。
/// ※ アプリを入れ直す・別の端末を使うと回避できる(サーバー側の制限はない)。
enum PassphraseAttempts {
    static let maxFailures = 5
    static let lockSeconds: TimeInterval = 60
    private static let countKey = "passphraseFailureCount"
    private static let lockKey = "passphraseLockUntil"

    static var lockUntil: Date? {
        guard let date = UserDefaults.standard.object(forKey: lockKey) as? Date, date > Date() else { return nil }
        return date
    }

    /// 失敗を1回記録する。5回目なら、待つ期限を返す
    static func recordFailure(now: Date = Date()) -> Date? {
        let count = UserDefaults.standard.integer(forKey: countKey) + 1
        guard count >= maxFailures else {
            UserDefaults.standard.set(count, forKey: countKey)
            return nil
        }
        let until = now.addingTimeInterval(lockSeconds)
        UserDefaults.standard.set(0, forKey: countKey)
        UserDefaults.standard.set(until, forKey: lockKey)
        return until
    }

    static func reset() {
        UserDefaults.standard.set(0, forKey: countKey)
        UserDefaults.standard.removeObject(forKey: lockKey)
    }

    static func unlock() {
        UserDefaults.standard.removeObject(forKey: lockKey)
    }
}

enum PassphraseFeedback: Equatable {
    case none, notFound, network, locked
}

// MARK: - 招待を受ける(長押しで入る)+ 加入アニメ

/// 招待を受ける画面。長押し(0.9秒)で入る。入る瞬間は、自分の光が空席に飛び込む(約3.6秒・画面は切りかえない)。
/// 「入りました。」は、サーバーの成功を確かめてから出す(遅いときは、光が席の上で呼吸して待つ。最大8秒)。
struct InvitationView: View {
    let prepared: PreparedInvitation
    let haptics: ExposureHaptics
    let onFailure: (GroupJoinService.Failure) -> Void
    let onDecline: () -> Void
    let onHome: (LaterGroup) -> Void

    private static let holdDuration: TimeInterval = 0.9
    private static let circleDiameter: CGFloat = 264
    private static let orange = Color(hex: "FFB078")
    private static let maxWait: TimeInterval = 8

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var pressStart: Date?
    @State private var joinStart: Date?
    /// サーバーの成功を確かめた時刻(加入アニメの時計 t)
    @State private var successAt: Double?
    @State private var joinedGroup: LaterGroup?
    @State private var circleCenter: CGPoint = .zero
    @State private var buttonCenter: CGPoint = .zero
    @State private var shimmerStart = Date()
    @State private var confirmingVoiceOver = false
    @State private var arrivalHapticFired = false

    private var invitation: GroupInviteService.Invitation { prepared.invitation }
    private var colors: [Color] { GroupRingMath.auraPalettes[GroupPalette.isValid(invitation.colorIndex) ? invitation.colorIndex : 0] }

    var body: some View {
        TimelineView(.animation(paused: pressStart == nil && joinStart == nil)) { context in
            let t = joinStart.map { context.date.timeIntervalSince($0) }
            let arrival = arrivalTime
            ZStack {
                background(t: t, arrival: arrival)
                content(t: t, arrival: arrival, now: context.date)
                if let t, !reduceMotion { orb(t: t, arrival: arrival) }
            }
            .coordinateSpace(name: "invite")
            .onChange(of: context.date) { _, date in tick(date) }
        }
        .alert("このグループに入りますか?", isPresented: $confirmingVoiceOver) {
            Button("入る") { startJoin() }
            Button("入らない", role: .cancel) {}
        }
        .onChange(of: scenePhase) { _, phase in
            // アニメの途中で背面に行った:戻ったら、終わった状態を出す
            if phase == .active, successAt != nil, let joinStart, Date().timeIntervalSince(joinStart) < 3.6 {
                self.joinStart = Date().addingTimeInterval(-(arrivalTime + 2.3))
            }
        }
    }

    /// 到着の時刻:1.35秒。サーバーの成功がそれより遅ければ、成功の時刻まで待つ
    private var arrivalTime: Double {
        max(1.35, successAt ?? .infinity)
    }

    // MARK: 背景

    private func background(t: Double?, arrival: Double) -> some View {
        let boost: Double = {
            guard let t, t >= arrival else { return 0 }
            return max(0, 1 - (t - arrival) / 0.8)
        }()
        return ZStack {
            Color.black
            RadialGradient(colors: [colors[0].opacity(0.3 + 0.25 * boost), colors[1].opacity(0.12), .clear],
                           center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }

    // MARK: 中身

    private func content(t: Double?, arrival: Double, now: Date) -> some View {
        // 0〜0.45:下の説明・顔・ボタン・「入らない」・✕ が、下へ14ptずれながら消える
        let fadeOut = t.map { min(1, max(0, $0 / 0.45)) } ?? 0
        let joined = t.map { $0 >= arrival } ?? false
        let local = t.map { $0 - arrival } ?? -1
        let seatArrival: Double? = joined ? min(1, local / (reduceMotion ? 0.3 : 0.5)) : nil
        let litCount = prepared.memberCount + (joined && local > 0.3 ? 1 : 0)

        return VStack(spacing: 0) {
            HStack {
                Button(action: onDecline) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("入らない")
                .opacity(1 - fadeOut)
                .disabled(joinStart != nil)
                Spacer()
            }
            .padding(.horizontal, 20)

            Text("INVITATION")
                .font(.system(size: 10, design: .monospaced))
                .tracking(0.26 * 10)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.top, 2)

            GroupCircle(
                image: invitation.iconData.flatMap(UIImage.init(data:)),
                initial: GroupNameRules.initial(of: invitation.groupName),
                colorIndex: invitation.colorIndex,
                memberLimit: invitation.memberLimit,
                litCount: litCount,
                diameter: Self.circleDiameter,
                seatIndex: joined && local > 0.3 ? nil : prepared.seatIndex,
                arrival: seatArrival,
                sparkleTime: joined && !reduceMotion ? local - 0.1 : nil,
                discScale: joined && !reduceMotion && local < 0.4 ? 1.045 : 1
            )
            .overlay { if let t, !reduceMotion { ripple(t: t, arrival: arrival) } }
            .onGeometryChange(for: CGPoint.self, of: { proxy in
                let f = proxy.frame(in: .named("invite"))
                return CGPoint(x: f.midX, y: f.midY)
            }) { circleCenter = $0 }
            .padding(.top, 14)

            ZStack {
                // 1.3〜1.6:「〇〇 に、招待されました。」がうすれる
                VStack(spacing: 6) {
                    Text(invitation.groupName)
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-0.03 * 34)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("に、招待されました。").font(.system(size: 15))
                    Text(metaLine).font(.system(size: 12.5)).foregroundStyle(Color(hex: "BCBBC0"))
                }
                .opacity(t.map { 1 - min(1, max(0, ($0 - (arrival - 0.05)) / 0.3)) } ?? 1)

                if let t, joined {
                    joinedText(local: t - arrival)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.top, 18)

            Spacer(minLength: 12)

            VStack(spacing: 14) {
                faces
                notice
                holdButton(now: now)
                Button(action: onDecline) {
                    Text("入らない")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "8E8E93"))
                        .frame(minHeight: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .opacity(1 - fadeOut)
            .offset(y: 14 * fadeOut)
            .allowsHitTesting(joinStart == nil)
            .overlay(alignment: .bottom) {
                if let t, joined { homeButton(local: t - arrival) }
            }
            .padding(.bottom, 16)
        }
    }

    private var metaLine: String {
        "\(prepared.memberCount) / \(invitation.memberLimit)人"
    }

    /// メンバーの顔(最大4つ)。名前は、入る前には見えないので出さない
    private var faces: some View {
        HStack(spacing: 10) {
            HStack(spacing: -10) {
                ForEach(Array(prepared.participantKeys.prefix(4).enumerated()), id: \.offset) { _, key in
                    PersonaIcon(seed: Self.seed(key))
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.black, lineWidth: 2))
                }
            }
            .accessibilityHidden(true)
            Text("メンバー \(prepared.memberCount)人")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "BCBBC0"))
        }
    }

    private var notice: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(JoinNotice.lines, id: \.self) { line in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("・")
                    Text(line).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.system(size: 11.5))
        .foregroundStyle(Color(hex: "BCBBC0"))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.05)))
        .accessibilityElement(children: .combine)
    }

    // MARK: 長押しボタン

    private func holdButton(now: Date) -> some View {
        let progress = pressStart.map { min(1, now.timeIntervalSince($0) / Self.holdDuration) } ?? 0
        let shape = Capsule()
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                shape.fill(.white.opacity(0.1))
                LinearGradient(colors: [Color(hex: "FFC56B"), Self.orange, Color(hex: "FF8FA0")], startPoint: .leading, endPoint: .trailing)
                    .frame(width: proxy.size.width * progress)
                    .clipShape(shape)
                if pressStart == nil, !reduceMotion {
                    ButtonShimmerBand(start: shimmerStart).clipShape(shape)
                }
                shape.strokeBorder(Self.orange.opacity(0.6), lineWidth: 1)
                Text(pressStart == nil ? "長押しで、入る" : "そのまま、押し続けて")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 62)
        .scaleEffect(pressStart == nil ? 1 : 0.98)
        .animation(.easeOut(duration: 0.15), value: pressStart == nil)
        .contentShape(shape)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard pressStart == nil, joinStart == nil else { return }
                    pressStart = Date()
                    haptics.beginHold(duration: Self.holdDuration)
                }
                .onEnded { _ in
                    guard joinStart == nil else { return }
                    pressStart = nil
                    haptics.cancelHold()
                }
        )
        .onGeometryChange(for: CGPoint.self, of: { proxy in
            let f = proxy.frame(in: .named("invite"))
            return CGPoint(x: f.midX, y: f.midY)
        }) { buttonCenter = $0 }
        .accessibilityElement()
        .accessibilityLabel("入る。長押しします")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { confirmingVoiceOver = true }
    }

    private func tick(_ date: Date) {
        if let pressStart, joinStart == nil, date.timeIntervalSince(pressStart) >= Self.holdDuration {
            startJoin()
        }
        guard let joinStart else { return }
        let t = date.timeIntervalSince(joinStart)
        // 到着:強く1回(入った)
        if !arrivalHapticFired, successAt != nil, t >= arrivalTime {
            arrivalHapticFired = true
            haptics.playTransient(intensity: 1.0, sharpness: 0.7)
        }
        // 通信が遅い:到着のところで最大8秒待って、だめなら「つながりませんでした」
        if successAt == nil, t > 1.35 + Self.maxWait {
            self.joinStart = nil
            onFailure(.network)
        }
    }

    private func startJoin() {
        pressStart = nil
        haptics.cancelHold()
        joinStart = Date()
        Task {
            let result = await GroupJoinService.join(prepared, context: modelContext)
            guard let joinStart else { return }
            switch result {
            case .success(let group):
                joinedGroup = group
                successAt = Date().timeIntervalSince(joinStart)
            case .failure(let failure):
                // アニメを途中で止めて、エラーへ
                self.joinStart = nil
                onFailure(failure)
            }
        }
    }

    // MARK: 光の玉・尾・波紋

    /// 0〜0.3:ボタンの位置に光の玉(60pt)。0.3〜到着:二次ベジェで席へ(1.0 → 0.1倍)。うしろに6つの尾
    private func orb(t: Double, arrival: Double) -> some View {
        let seat = CGPoint(
            x: circleCenter.x + GroupCircle.seatOffset(index: prepared.seatIndex, memberLimit: invitation.memberLimit, diameter: Self.circleDiameter).width,
            y: circleCenter.y + GroupCircle.seatOffset(index: prepared.seatIndex, memberLimit: invitation.memberLimit, diameter: Self.circleDiameter).height
        )
        let start = buttonCenter
        let control = CGPoint(x: start.x + 150, y: start.y - 158)
        return ZStack {
            ForEach(0..<7, id: \.self) { i in
                let lag = Double(i) * 0.045
                let (point, scale, opacity) = orbState(t: t - lag, arrival: arrival, start: start, control: control, end: seat)
                let shrink = 1 - Double(i) * 0.12
                Circle()
                    .fill(LinearGradient(colors: [Self.orange, Color(hex: "FF8FA0"), Color(hex: "3A1E4A")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                    .shadow(color: Self.orange.opacity(0.8), radius: 18)
                    .scaleEffect(scale * shrink)
                    .opacity(opacity * (i == 0 ? 1 : 0.5 * shrink))
                    .position(point)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func orbState(t: Double, arrival: Double, start: CGPoint, control: CGPoint, end: CGPoint) -> (CGPoint, CGFloat, Double) {
        guard t > 0 else { return (start, 0, 0) }
        if t < 0.3 { return (start, CGFloat(t / 0.3), t / 0.3) }
        let flight = 1.05 // 0.3〜1.35
        if t < 0.3 + flight {
            let u = (t - 0.3) / flight
            let e = u < 0.5 ? 2 * u * u : 1 - pow(-2 * u + 2, 2) / 2 // ease-in-out
            let a = 1 - e
            let p = CGPoint(x: a * a * start.x + 2 * a * e * control.x + e * e * end.x,
                            y: a * a * start.y + 2 * a * e * control.y + e * e * end.y)
            return (p, CGFloat(1 - 0.9 * e), 1)
        }
        // 到着を待つあいだは、席の上でゆっくり呼吸する
        if t < arrival {
            let breath = 0.1 + 0.04 * sin((t - 1.35) * 2 * .pi / 1.6)
            return (end, CGFloat(breath), 1)
        }
        return (end, 0.1, max(0, 1 - (t - arrival) / 0.15))
    }

    /// 席から波紋(20pt → 7倍、1.1秒、不透明度 .8 → 0)
    private func ripple(t: Double, arrival: Double) -> some View {
        let u = (t - arrival) / 1.1
        let offset = GroupCircle.seatOffset(index: prepared.seatIndex, memberLimit: invitation.memberLimit, diameter: Self.circleDiameter)
        return Circle()
            .stroke(Self.orange, lineWidth: 1.5)
            .frame(width: 20, height: 20)
            .scaleEffect(1 + 6 * CGFloat(max(0, min(1, u))))
            .opacity(u >= 0 && u < 1 ? 0.8 * (1 - u) : 0)
            .offset(offset)
            .allowsHitTesting(false)
    }

    // MARK: 入りました

    private func joinedText(local: Double) -> some View {
        // 到着の0.25秒後(=1.6秒)から「入りました。」、0.75秒後から人数、1.35秒後からボタン
        let p1 = reduceMotion ? min(1, max(0, (local - 0.25) / 0.3)) : HomeMotion.ease(min(1, max(0, (local - 0.25) / 0.7)))
        let p2 = reduceMotion ? min(1, max(0, (local - 0.75) / 0.3)) : HomeMotion.ease(min(1, max(0, (local - 0.75) / 0.6)))
        return VStack(spacing: 8) {
            Text("入りました。")
                .font(.system(size: 30, weight: .bold))
                .entrance(p1, blur: reduceMotion ? 0 : 12, dy: reduceMotion ? 0 : 12)
            Text(invitation.groupName)
                .font(.system(size: 15, weight: .semibold))
                .entrance(p1, blur: 0, dy: reduceMotion ? 0 : 12)
            (Text("\(prepared.memberCount + 1)").bold() + Text(" / \(invitation.memberLimit)人 ・ 撮ると、このグループの昨日も、一緒にひらきます"))
                .font(.system(size: 12.5))
                .foregroundStyle(Color(hex: "BCBBC0"))
                .multilineTextAlignment(.center)
                .entrance(p2, blur: 0, dy: reduceMotion ? 0 : 8)
        }
        .accessibilityElement(children: .combine)
    }

    private func homeButton(local: Double) -> some View {
        let p = reduceMotion ? min(1, max(0, (local - 1.35) / 0.3)) : HomeMotion.ease(min(1, max(0, (local - 1.35) / 0.7)))
        let enabled = local >= 1.95
        return Button {
            if let joinedGroup { onHome(joinedGroup) }
        } label: {
            Text("ホームで、見る")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Capsule().fill(.white))
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
        .disabled(!enabled)
        .entrance(p, dy: reduceMotion ? 0 : 16)
        .padding(.horizontal, 24)
    }

    private static func seed(_ name: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        for (i, b) in name.utf8.enumerated() { bytes[i % 16] = bytes[i % 16] &* 31 &+ b }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

/// 長押しボタンの光の帯(5秒ごと)
private struct ButtonShimmerBand: View {
    let start: Date
    var body: some View {
        TimelineView(.animation) { context in
            GeometryReader { proxy in
                let elapsed = context.date.timeIntervalSince(start) - 1.6
                let phase = elapsed < 0 ? -1 : elapsed.truncatingRemainder(dividingBy: 5)
                if phase >= 0, phase < 0.9 {
                    let w = proxy.size.width * 0.3
                    LinearGradient(colors: [.clear, .white.opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: w)
                        .offset(x: -w + (proxy.size.width + w) * HomeMotion.ease(phase / 0.9))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 入れないとき(エラー4種+つながらない)

struct JoinErrorView: View {
    let failure: GroupJoinService.Failure
    let prepared: PreparedInvitation?
    let onHome: () -> Void
    let onPassphrase: () -> Void
    let onOpenGroup: () -> Void
    let onRetry: () -> Void

    private var limit: Int { prepared?.memberLimit ?? GroupMembershipPolicy.maxMembersPerGroup }

    private var texts: (String, String) {
        switch failure {
        case .check(.full): return ("このグループは、\nいっぱいです。", "\(limit)人のメンバーがそろっています。だれかが抜けると、また入れます。")
        case .check(.unavailable): return ("この招待は、\nもう使えません。", "リンクが古くなったか、作った人が止めました。新しいリンクを、送ってもらってください。")
        case .check(.alreadyMember): return ("もう、\n入っています。", "このグループには、すでに参加しています。")
        case .check(.tooManyGroups): return ("グループは、\n10個までです。", "いまのグループを1つ抜けると、新しく入れます。")
        default: return ("つながりませんでした。", "電波のよいところで、もういちど。")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            if let prepared {
                let lit: Int = {
                    switch failure {
                    case .check(.full): return prepared.memberLimit
                    default: return prepared.memberCount
                    }
                }()
                GroupCircle(
                    image: prepared.invitation.iconData.flatMap(UIImage.init(data:)),
                    initial: GroupNameRules.initial(of: prepared.invitation.groupName),
                    colorIndex: prepared.invitation.colorIndex,
                    memberLimit: prepared.memberLimit,
                    litCount: lit,
                    diameter: 200,
                    rotates: false,
                    faded: failure != .check(.alreadyMember)
                )
            }
            Text(texts.0)
                .font(.system(size: 27, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.top, 26)
            Text(texts.1)
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hex: "BCBBC0"))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .padding(.horizontal, 12)
            Spacer()
            VStack(spacing: 10) {
                switch failure {
                case .check(.unavailable):
                    secondary("合言葉で入る", action: onPassphrase)
                    primary("Home にもどる", action: onHome)
                case .check(.alreadyMember):
                    primary("グループをひらく", action: onOpenGroup)
                case .check(.tooManyGroups):
                    primary("グループの一覧へ", action: onHome)
                case .network:
                    primary("もういちど", action: onRetry)
                    secondary("Home にもどる", action: onHome)
                default:
                    primary("Home にもどる", action: onHome)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(.white))
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
    }

    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50).background(Capsule().fill(.white.opacity(0.1)))
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
    }
}

/// 入るための画面を出す要求
struct JoinFlowRequest: Identifiable {
    let id = UUID()
    let start: JoinFlowStart
}

// MARK: - 「続きから」:コピーした招待リンクを貼りつける

/// アプリを入れる前にひらいた招待ページで、リンクをコピーしてから来た人のために、初回設定のあと一度だけ出す。
/// OS の「ペースト」ボタンなので、許可のアラートは出ない。外部のサービスは使わない。
struct InvitePasteSheet: View {
    let onLink: (URL) -> Void
    let onDismiss: () -> Void

    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(.white.opacity(0.25)).frame(width: 40, height: 5).padding(.top, 10)
            Text("招待されて、来ましたか?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 26)
            Text("招待のリンクをコピーしてから来た人は、ここに貼りつけると、そのまま続きから入れます。")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "BCBBC0"))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
            if let message {
                Text(message).font(.system(size: 12.5)).foregroundStyle(Color(hex: "FFB078")).padding(.top, 10)
            }
            Spacer(minLength: 20)
            PasteButton(payloadType: URL.self) { urls in
                if let shareURL = urls.lazy.compactMap(InviteConfig.shareURL(from:)).first {
                    onLink(shareURL)
                } else {
                    message = "Later の招待ではありません"
                }
            }
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(.white)
            Button(action: onDismiss) {
                Text("ちがいます")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "16161A").ignoresSafeArea())
        .presentationDetents([.medium])
    }
}
