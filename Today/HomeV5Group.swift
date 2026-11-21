import ImageIO
import SwiftUI
import UIKit

// Home v5 の GROUP 画面。グループごとの大きなガラスの区画が縦に並び、昨日の写真のタイルが横に並ぶ。
// 解禁前のタイルは、ハッシュタグと撮った人のアイコンとモザイクだけが見える。

// MARK: - データ

/// 昨日の写真のタイル(1枚)
struct V5GroupTile: Identifiable, Equatable {
    let id: String
    let authorSeed: UUID
    let authorImage: Data?
    let tags: [String]
    let tiny: Data?
    /// 本物の写真。解禁前の表示には使わない
    let imageData: Data?
    let capturedAt: Date
    let isMine: Bool
    /// 灯の対象になる写真の名前(CloudKit の recordName。まだなければ端末の id)
    var photoRecordName: String? = nil
    /// チェキ フィードの頭:撮った人の名前・街
    var authorName: String? = nil
    var city: String? = nil
    /// 撮った人(通報・見えなくするの対象)
    var authorRecordName: String? = nil
}

/// 1グループぶんの区画
struct GroupSectionModel: Identifiable, Equatable {
    let id: UUID
    let name: String
    let iconData: Data?
    let auraIndex: Int
    let memberCount: Int
    /// 今日撮った人の数(ダイヤルの光る数)
    let shotToday: Int
    let tiles: [V5GroupTile]
    /// ひらいているタイルの id(自分の写真は常にひらいている)
    let unlockedIDs: Set<String>
    let locationMode: GroupLocationMode
}

enum GroupSections {
    /// 昨日の窓に届いた、投稿ずみの写真を、グループごとのタイルにする。
    /// 自分の写真はすでに見ているので、いつもひらいている。ほかの人の写真から、解禁の数(min)だけをランダムにひらく。
    static func build(
        groups: [LaterGroup],
        myProfileID: UUID?,
        myRecordName: String?,
        blocked: Set<String>,
        shotsToday: Int,
        now: Date,
        auraIndices: [UUID: Int]
    ) -> [GroupSectionModel] {
        let yesterday = DailyWindow.yesterday(for: now)
        let today = DailyWindow.latest(for: now)
        let dayKey = ExposureDayStore.dayKey(for: yesterday.open)
        return groups.map { group in
            var seen = Set<String>()
            var tiles: [V5GroupTile] = []
            for photo in group.photos.sorted(by: { $0.captureDate < $1.captureDate })
            where photo.isPosted && photo.captureDate >= yesterday.open && photo.captureDate < yesterday.close {
                if let author = photo.authorCloudKitUserRecordName, blocked.contains(author) { continue }
                let key = photo.dedupeKey
                guard seen.insert(key).inserted else { continue }
                let isMine = (myRecordName != nil && photo.authorCloudKitUserRecordName == myRecordName)
                    || (myProfileID != nil && photo.owner?.id == myProfileID)
                tiles.append(V5GroupTile(
                    id: key,
                    authorSeed: photo.owner?.id ?? photo.id,
                    authorImage: photo.owner?.profileImageData,
                    tags: photo.tags,
                    tiny: photo.mosaicTiny,
                    imageData: photo.imageData.isEmpty ? nil : photo.imageData,
                    capturedAt: photo.captureDate,
                    isMine: isMine,
                    photoRecordName: photo.ckRecordName ?? photo.id.uuidString,
                    authorName: photo.owner?.name,
                    city: photo.locationName,
                    authorRecordName: photo.authorCloudKitUserRecordName
                ))
            }
            let others = tiles.filter { !$0.isMine }.map(\.id)
            var unlocked = Set(UnlockPlan.unlockedKeys(keys: others, groupID: group.id, dayKey: dayKey, shotsToday: shotsToday))
            for tile in tiles where tile.isMine { unlocked.insert(tile.id) }
            let shotToday = Set(group.photos.filter { $0.captureDate >= today.open && $0.captureDate < today.close }.map(\.dedupeKey)).count
            return GroupSectionModel(
                id: group.id,
                name: group.name,
                iconData: group.iconImageData,
                auraIndex: auraIndices[group.id] ?? 0,
                memberCount: max(1, group.deduplicatedMemberIDs.count),
                shotToday: shotToday,
                tiles: tiles,
                unlockedIDs: unlocked,
                locationMode: LocationShareStore.mode(for: group.id)
            )
        }
    }

    /// 全体の「動きの印」:今日撮った人の数と、ひらいた数の合計(GROUP を開いたら見たことにする)
    static func activitySignature(_ sections: [GroupSectionModel]) -> Int {
        sections.reduce(0) { $0 + $1.shotToday * 100 + $1.unlockedIDs.count }
    }
}

// MARK: - v36 ヒーロー(Once ふう・見本:later_v36.html)

/// 角丸32・高さ約470の 大きなカード。きのうの写真4枚のモザイクを背景に、グループ名と3つの数字、
/// Create(白い丸)・参加する(ガラスの四角)。今日まだ撮っていないときは ぼかして ロックのピルを出す。
struct YesterdayOnceHero: View {
    let mosaic: [Data]
    let groupName: String?
    let dateLabel: String
    let groupsCount: Int
    let daysLeft: Int
    let friendsCount: Int
    let locked: Bool
    let hoursToOpen: Int
    let introToken: Int
    let onCreate: () -> Void
    let onJoin: () -> Void
    let onFriends: () -> Void
    var onOpenGroups: () -> Void = {}
    var onOpenToOpen: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .bottom) {
            mosaicBackground
            LinearGradient(colors: [.clear, .clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 16) {
                Text(verbatim: "GROUPS · \(dateLabel)")
                    .font(Typo.label(10, bold: true))
                    .tracking(2.6)
                    .foregroundStyle(.white.opacity(0.75))
                if locked {
                    Button {
                        Haptics.play(.tick)
                        CaptureRequestStore.shared.pendingRequestID = UUID()
                    } label: {
                        Label { Text(verbatim: "shoot today to open") } icon: { Image(systemName: "lock.fill") }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).frame(height: 38)
                            .laterGlass(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Text(verbatim: groupName ?? "Yesterday, together.")
                    .font(Typo.title(46))
                    .foregroundStyle(.white)
                    .tracking(-0.6)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 3)
                stats
                buttons
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .padding(.top, 150)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 470)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 16)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.96)
        .opacity(appeared || reduceMotion ? 1 : 0)
        .onAppear { reveal() }
        .onChange(of: introToken) { _, _ in
            var hide = Transaction(); hide.disablesAnimations = true
            withTransaction(hide) { appeared = false }
            DispatchQueue.main.async { reveal() }
        }
    }

    private func reveal() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.78)) { appeared = true }
    }

    private var mosaicBackground: some View {
        GeometryReader { proxy in
            let w = proxy.size.width / 2, h = proxy.size.height / 2
            Group {
                if mosaic.isEmpty {
                    LinearGradient(colors: [Color(hex: "2A2A2E"), Color(hex: "121214")], startPoint: .top, endPoint: .bottom)
                } else {
                    VStack(spacing: 3) {
                        HStack(spacing: 3) { mosaicTile(0, w: w, h: h); mosaicTile(1, w: w, h: h) }
                        HStack(spacing: 3) { mosaicTile(2, w: w, h: h); mosaicTile(3, w: w, h: h) }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .scaleEffect(locked ? 1.12 : 1)
            .blur(radius: locked ? 18 : 0)
            .saturation(locked ? 0.45 : 1)
            .brightness(locked ? 0.1 : 0)
        }
        .clipped()
        .allowsHitTesting(false)
    }

    private func mosaicTile(_ i: Int, w: CGFloat, h: CGFloat) -> some View {
        Group {
            if i < mosaic.count, let image = UIImage(data: mosaic[i]) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color(hex: "1C1C1F")
            }
        }
        .frame(width: w, height: h)
        .clipped()
    }

    private var stats: some View {
        HStack(spacing: 0) {
            Button(action: onOpenGroups) { stat(value: groupsCount, label: "Groups") }
                .buttonStyle(.plain)
                .accessibilityLabel("グループ、\(groupsCount)")
            if locked {
                Button(action: onOpenToOpen) { stat(value: hoursToOpen, label: "To open", suffix: "h") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("ひらくまで、\(hoursToOpen)時間")
            } else {
                stat(value: daysLeft, label: "Left", suffix: "d")
            }
            Button(action: onFriends) { stat(value: friendsCount, label: "Friends ›") }
                .buttonStyle(.plain)
                .accessibilityLabel("ともだち、\(friendsCount)人")
        }
    }

    private func stat(value: Int, label: String, suffix: String = "") -> some View {
        VStack(spacing: 3) {
            Text(verbatim: "\(appeared ? value : 0)\(suffix)")
                .font(Typo.title(31, italic: true))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text(verbatim: label)
                .font(Typo.ui(500, 13))
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: appeared)
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            Button(action: onCreate) {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 18, weight: .bold))
                    Text("Create").font(Typo.ui(800, 16))
                }
                .foregroundStyle(Color(hex: "111111"))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.white))
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
            .accessibilityLabel("グループをつくる")
            Button(action: onJoin) {
                Image(systemName: "qrcode").font(.system(size: 19, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .laterGlass(Circle())
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.92))
            .accessibilityLabel("グループに参加する")
        }
        .padding(.top, 4)
    }
}

// MARK: - 画面

struct HomeV5GroupPage: View {
    @Environment(\.palette) private var palette
    let sections: [GroupSectionModel]
    let isActive: Bool
    let haptics: ExposureHaptics
    /// 撮影のあと(解禁の動きを見せる合図。撮った瞬間に変わる)
    let shotEvent: ShotEvent?
    /// 見ている窓(見せたあとの解禁は、窓ごとに覚えて、くり返さない)
    let windowKey: String
    let topInset: CGFloat
    let canCreate: Bool
    let onOpenRoom: (UUID) -> Void
    let onOpenTile: (_ point: CGPoint, _ groupID: UUID, _ tileID: String) -> Void
    let onCycleLocation: (UUID) -> Void
    let onAdd: () -> Void
    /// 0 グループの画面(「あなた」の頭文字・つくる・参加する)
    var userName: String = ""
    var onCreateGroup: (String?) -> Void = { _ in }
    var onJoinGroup: () -> Void = {}
    /// v36:ヒーロー・ACTIVE(Home の暗室と同じたてカード)に使う
    var now: Date = Date()
    var sharedGroups: [LaterGroup] = []
    var me: String? = nil
    var blocked: Set<String> = []
    /// グループごとの、発表された一枚(なければタイルを出さない)
    var announced: [UUID: AnnouncedPick] = [:]
    /// 自分が灯をともしているタイルの id
    var litTileIDs: Set<String> = []
    var onOpenAnnounced: (_ point: CGPoint, _ groupID: UUID) -> Void = { _, _ in }
    /// 増えるたびに、いちばん上まで滑らかにもどる(選択ずみのタブをもう一度タップ)
    var scrollToTopToken = 0
    /// 今日を撮る前に昨日のホームをひらいた:昨日のタイルはぼかして、ロックする
    var locked = false
    /// v14 ②:上の「ともだち」と ME カード
    var friendsState: HomeState = .first
    var friendsData: HomeLayerData = .empty
    var friendsActions = HomeLayerActions()
    var onFriend: (HomeFriend) -> Void = { _ in }
    var onInviteFriend: () -> Void = {}
    var onOpenMe: () -> Void = {}
    /// v47:「To open」の数 → ライブパネル
    var onOpenToOpen: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// タイルごとのモザイクの段階
    @State private var levels: [String: MosaicLevel] = [:]
    @State private var scales: [String: CGFloat] = [:]
    @State private var bursts: [String: Double] = [:]
    @State private var shakes: [String: Int] = [:]
    @State private var glowGroups: [UUID: Date] = [:]
    @State private var popGroups: [UUID: Date] = [:]
    @State private var previousShot: [UUID: Int] = [:]
    @State private var hasSeeded = false
    @State private var played: Set<String> = []
    @State private var pendingIDs: [String] = []
    @State private var unlockTask: Task<Void, Never>?
    /// タブを開き直すたびに増やす(ブロックが、もう一度下から出てくる)
    @State private var revealToken = 0
    /// ヒーローの 出現の はじまり(タブを ひらくたび)
    @State private var introToken = 0

    private var targetIDs: [String] {
        sections.flatMap { section in section.tiles.map(\.id).filter(section.unlockedIDs.contains) }
    }

    var body: some View {
        ScrollViewReader { reader in
        ScrollView(.vertical) {
            // v36:ヒーロー(Once ふう)→ ACTIVE → ME → FRIENDS → グループ。
            // 画面に入ったら下から出てくる(タブを開き直すたびに、もう一度)
            VStack(spacing: 12) {
                YesterdayOnceHero(
                    mosaic: heroMosaic,
                    groupName: sections.first?.name,
                    dateLabel: Darkroom.dayLabel(DailyWindow.yesterday(for: now).open).uppercased(),
                    groupsCount: sections.count,
                    daysLeft: max(1, MERules.days - 1),
                    friendsCount: friendsData.friends.count,
                    locked: locked,
                    hoursToOpen: hoursToOpen,
                    introToken: introToken,
                    onCreate: { if canCreate { onCreateGroup(nil) } else { Haptics.play(.warn) } },
                    onJoin: onJoinGroup,
                    onFriends: onInviteFriend,
                    onOpenGroups: {
                        if sections.isEmpty {
                            if canCreate { onCreateGroup(nil) } else { Haptics.play(.warn) }
                        } else {
                            Haptics.play(.tick)
                            withAnimation(.easeInOut(duration: 0.45)) { reader.scrollTo("v5active", anchor: .top) }
                        }
                    },
                    onOpenToOpen: locked ? onOpenToOpen : {}
                )
                .padding(.top, 2)
                activeRow
                    .id("v5active")
                    .padding(.horizontal, -V5.edge)
                    .yesterdayRise(0.05, token: introToken)
                MECard(caption: "きのうの まい ・ 7日で きえる", film: friendsData.film, isActive: isActive, onTap: onOpenMe)
                    .padding(.top, 2)
                    .yesterdayRise(0.1, token: introToken)
                TodayFriendsSection(state: friendsState, data: friendsData, actions: friendsActions, onFriend: onFriend, onInvite: onInviteFriend)
                    .padding(.horizontal, -V5.edge)
                    .yesterdayRise(0.15, token: introToken)
                // v54:ヒーロー → ACTIVE → ME → Friend で終わり。古い「グループ」見出し・縦の一覧・ピン・
                // 1/1 の輪は、モックに無いので出さない(詳しくは SCREEN_MAP.md の Groups タブの項)。
            }
            .padding(.horizontal, V5.edge)
            .padding(.top, topInset + 52)
            // 中身の幅は、画面の幅と同じ1つだけ
            .containerRelativeFrame(.horizontal)
            .padding(.bottom, 130)
            .id("v5top")
        }
        .scrollIndicators(.hidden)
        .lgScrollEdgeSoft()
        .animation(.easeInOut(duration: 1.4), value: locked)
        .onChange(of: scrollToTopToken) { _, _ in
            withAnimation(.easeInOut(duration: 0.45)) { reader.scrollTo("v5top", anchor: .top) }
        }
        .onAppear {
            seed()
            if isActive { startIntro() }
        }
        .onChange(of: targetIDs) { _, _ in syncUnlocks() }
        .onChange(of: sections.map(\.shotToday)) { _, _ in noticeShots() }
        .onChange(of: shotEvent?.id) { _, _ in syncUnlocks() }
        .onChange(of: isActive) { _, active in
            if active {
                revealToken += 1
                startIntro()
            }
            if active, !pendingIDs.isEmpty { playPending() }
        }
        .onDisappear { unlockTask?.cancel() }
        }
    }

    // MARK: v36 ヒーロー・ACTIVE

    /// 開いた 瞬間の 出現:ヒーローが 0.96 → 1(onAppear 側)、ここでは バイブだけ
    private func startIntro() {
        introToken += 1
        let token = introToken
        func after(_ seconds: Double, _ work: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { if introToken == token { work() } }
        }
        guard !reduceMotion else { return }
        after(0.15) { Haptics.play(.soft) }
    }

    /// ヒーローの モザイク:ひらいている タイルの 写真を 4枚まで
    private var heroMosaic: [Data] {
        var result: [Data] = []
        for section in sections {
            for tile in section.tiles where section.unlockedIDs.contains(tile.id) {
                guard let data = tile.imageData else { continue }
                result.append(data)
                if result.count >= 4 { return result }
            }
        }
        return result
    }

    /// ロック中の「あと何時間」(今日の 消灯まで)
    private var hoursToOpen: Int {
        let close = DailyExposureRules.window(for: now).close
        return max(0, Int((close.timeIntervalSince(now) / 3600).rounded(.up)))
    }

    /// ACTIVE:Home の暗室と同じ たてカードを 横に(写真・グループ名・「あと2人」・吹き出し)
    private var activeRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(sharedGroups) { group in
                    ActiveGroupCard(group: group, hasUnread: GroupChatStore.shared.hasUnread(group.id, me: me, blocked: blocked),
                                     locked: locked, me: me, now: now, onOpenChat: onOpenRoom)
                }
                ActiveNewGroupCard(onCreateGroup: { onCreateGroup(nil) })
            }
            .padding(.horizontal, V5.edge)
            .padding(.bottom, 4)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
    }

    // MARK: 解禁の動き

    private var playedKey: String { "v5PlayedUnlocks.\(windowKey)" }

    private func markPlayed(_ ids: [String]) {
        played.formUnion(ids)
        UserDefaults.standard.set(Array(played), forKey: playedKey)
    }

    /// 最初に出たときは、見せたことのあるタイルはそのまま、まだのものは撮影のあとだけ動かす
    private func seed() {
        guard !hasSeeded else { return }
        hasSeeded = true
        played = Set(UserDefaults.standard.stringArray(forKey: playedKey) ?? [])
        for section in sections { previousShot[section.id] = section.shotToday }
        syncUnlocks()
    }

    private func syncUnlocks() {
        guard hasSeeded else { return }
        let target = Set(targetIDs)
        for section in sections {
            for tile in section.tiles where levels[tile.id] == nil {
                levels[tile.id] = (target.contains(tile.id) && played.contains(tile.id)) ? .l3 : .l0
            }
        }
        // ひらいていなくなったもの(ブロックなど)は、モザイクにもどす
        for (id, level) in levels where level != .l0 && !target.contains(id) { levels[id] = .l0 }
        let unplayed = targetIDs.filter { !played.contains($0) && !pendingIDs.contains($0) }
        guard !unplayed.isEmpty else { return }
        let isArmed = shotEvent.map { Date().timeIntervalSince($0.at) < 12 } ?? false
        if !isArmed {
            // 撮影のあとではない(同期で増えた・前に見た):そのままひらく
            for id in unplayed { levels[id] = .l3 }
            markPlayed(unplayed)
            return
        }
        pendingIDs.append(contentsOf: unplayed)
        if isActive { playPending() }
    }

    private func playPending() {
        let ids = pendingIDs
        pendingIDs = []
        unlockTask?.cancel()
        unlockTask = Task { @MainActor in
            // 撮影のあと 1.4秒後から、1枚ずつ 0.52秒ずらして順に開く
            let sinceShot = shotEvent.map { Date().timeIntervalSince($0.at) } ?? 0
            try? await Task.sleep(for: .seconds(max(0, UnlockTimeline.startDelay - sinceShot)))
            var children: [Task<Void, Never>] = []
            for (index, id) in ids.enumerated() {
                if Task.isCancelled { break }
                let child = Task { @MainActor in await runUnlock(id: id) }
                children.append(child)
                if index < ids.count - 1 { try? await Task.sleep(for: .seconds(UnlockTimeline.stagger)) }
            }
            for child in children { await child.value }
        }
    }

    /// 1枚の動き(約1.1秒):L0 → L1(0ms)→ L2(260ms)→ L3(520ms)。同時に scale .9 → 1.1 → 1、光の輪がふくらむ。
    private func runUnlock(id: String) async {
        haptics.playPattern(HomeHapticPattern.unlockTile, sharpness: 0.5)
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) { levels[id] = .l3 }
            markPlayed([id])
            return
        }
        scales[id] = 0.9
        bursts[id] = 0
        levels[id] = .l1
        withAnimation(.easeOut(duration: 0.7)) { bursts[id] = 1 }
        withAnimation(.easeOut(duration: 0.26)) { scales[id] = 1.1 }
        try? await Task.sleep(for: .seconds(UnlockTimeline.stageOffsets[1]))
        levels[id] = .l2
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { scales[id] = 1 }
        try? await Task.sleep(for: .seconds(UnlockTimeline.stageOffsets[2] - UnlockTimeline.stageOffsets[1]))
        withAnimation(.easeOut(duration: 0.3)) { levels[id] = .l3 }
        markPlayed([id])
        try? await Task.sleep(for: .seconds(0.6))
        bursts[id] = nil
        scales[id] = nil
    }

    /// だれかが撮ったとき:ダイヤルがぽんとふくらみ、区画のふちが色で光る(1.4秒)。触覚「ぽっ」
    private func noticeShots() {
        var increased = false
        for section in sections {
            let before = previousShot[section.id] ?? section.shotToday
            if section.shotToday > before {
                increased = true
                popGroups[section.id] = Date()
                glowGroups[section.id] = Date()
                let id = section.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if let at = glowGroups[id], Date().timeIntervalSince(at) >= 1.4 { glowGroups[id] = nil }
                    if let at = popGroups[id], Date().timeIntervalSince(at) >= 0.8 { popGroups[id] = nil }
                }
            }
            previousShot[section.id] = section.shotToday
        }
        if increased, isActive { haptics.playPattern(HomeHapticPattern.groupShot) }
    }
}

// MARK: - 区画

struct GroupSectionView: View {
    let section: GroupSectionModel
    let levels: [String: MosaicLevel]
    let scales: [String: CGFloat]
    let bursts: [String: Double]
    let shakes: [String: Int]
    let glow: Date?
    let pop: Date?
    let isActive: Bool
    let announced: AnnouncedPick?
    let litTileIDs: Set<String>
    let onOpenAnnounced: (CGPoint) -> Void
    let onOpenRoom: () -> Void
    let onOpenTile: (CGPoint, String) -> Void
    let onCycleLocation: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var palette: [Color] {
        GroupRingMath.auraPalettes[GroupPalette.isValid(section.auraIndex) ? section.auraIndex : 0]
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            tileRow
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 36, style: .continuous).fill(ChicColor.fill))
        .overlay {
            // だれかが撮ったとき、ふちがグループの色になる(1.4秒)
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .strokeBorder(palette[0], lineWidth: 2)
                .opacity(glow == nil ? 0 : 1)
                .animation(.easeInOut(duration: 0.5), value: glow)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: 上段(高さ54・タップでグループの部屋へ)

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                icon
                Text(section.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ChicColor.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                TapConsumption.mark()
                onOpenRoom()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("\(section.name)の部屋をひらく")

            LocationModeButton(mode: section.locationMode, action: onCycleLocation)
            DeliveryDial(
                memberCount: section.memberCount,
                lit: section.shotToday,
                color: palette[0],
                isPopping: pop != nil
            )
        }
        .frame(height: 54)
    }

    private var icon: some View {
        Group {
            if let data = section.iconData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(colors: [palette[0], palette[2]], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(String(section.name.trimmingCharacters(in: .whitespaces).prefix(1)))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(ChicColor.line, lineWidth: 1))
    }

    // MARK: 昨日の写真のタイル

    @ViewBuilder
    private var tileRow: some View {
        if section.tiles.isEmpty, announced == nil {
            Text("昨日は、まだ届いていません")
                .font(.system(size: 12.5))
                .foregroundStyle(ChicColor.sub)
                .frame(maxWidth: .infinity, minHeight: 60)
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    // いちばん左:発表された一枚
                    if let announced {
                        AnnouncedGroupTile(pick: announced, onTap: onOpenAnnounced)
                    }
                    ForEach(Array(section.tiles.enumerated()), id: \.element.id) { tileIndex, tile in
                        // ひらく動きが始まるまでは、鍵のまま
                        let level = levels[tile.id] ?? .l0
                        V5GroupTileView(
                            tile: tile,
                            isUnlocked: level != .l0,
                            level: level,
                            scale: scales[tile.id] ?? 1,
                            burst: bursts[tile.id],
                            shake: shakes[tile.id] ?? 0,
                            isActive: isActive,
                            onTap: { point in onOpenTile(point, tile.id) },
                            hasMyLamp: litTileIDs.contains(tile.id),
                            index: tileIndex + 1
                        )
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
            .frame(height: 182)
            // 区画の中で始めた横の動きは、Profile を開くスワイプにしない
            .background(GeometryReader { proxy in
                Color.clear.preference(key: HomeNoSwipeRegionKey.self, value: [proxy.frame(in: .global)])
            })
        }
    }
}

// MARK: - 位置のボタン(38pt)

struct LocationModeButton: View {
    let mode: GroupLocationMode
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fill)
                    .overlay(Circle().strokeBorder(stroke, lineWidth: 1))
                if mode == .now {
                    Circle()
                        .strokeBorder(ChicColor.accent.opacity(0.7), lineWidth: 1.5)
                        .scaleEffect(breathe ? 1.5 : 1)
                        .opacity(breathe ? 0 : 0.9)
                }
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(mode == .now ? Color.white : (mode == .shotPlace ? ChicColor.ink : ChicColor.sub))
            }
            .frame(width: 38, height: 38)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .consumesTap()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { breathe = true }
        }
        .accessibilityLabel("位置の共有")
        .accessibilityValue(mode.title)
        .accessibilityHint("押すと、切りかわります")
    }

    private var symbol: String {
        switch mode {
        case .off: return "location.slash"
        case .shotPlace: return "mappin"
        case .now: return "location.fill"
        }
    }

    private var fill: Color {
        switch mode {
        case .off: return ChicColor.paper
        case .shotPlace: return ChicColor.paper
        case .now: return ChicColor.ink
        }
    }

    private var stroke: Color {
        mode == .off ? ChicColor.line : ChicColor.ink
    }
}

// MARK: - 今日の届き具合のダイヤル(50pt)

/// メンバー数ぶんのすき間つきの輪。撮った人だけ点灯し、中に「2/3」。
struct DeliveryDial: View {
    let memberCount: Int
    let lit: Int
    let color: Color
    var isPopping = false

    var body: some View {
        let dots = GroupRingMath.dots(memberCount: memberCount, posted: lit)
        ZStack {
            ForEach(0..<dots.total, id: \.self) { index in
                let gap = 0.03
                let step = 1.0 / Double(dots.total)
                Circle()
                    .trim(from: Double(index) * step + gap / 2, to: Double(index + 1) * step - gap / 2)
                    .stroke(index < dots.lit ? color : ChicColor.ink.opacity(0.12), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Text("\(min(lit, memberCount))/\(memberCount)")
                .font(V5.mono(10.5, weight: .semibold))
                .foregroundStyle(ChicColor.ink)
        }
        .frame(width: 50, height: 50)
        .scaleEffect(isPopping ? 1.18 : 1)
        .animation(.spring(duration: 0.8, bounce: 0.5), value: isPopping)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日、\(memberCount)人のうち\(min(lit, memberCount))人が撮りました")
    }
}

// MARK: - タイル(122 × 170)

struct V5GroupTileView: View {
    let tile: V5GroupTile
    let isUnlocked: Bool
    let level: MosaicLevel
    let scale: CGFloat
    let burst: Double?
    let shake: Int
    let isActive: Bool
    let onTap: (CGPoint) -> Void
    /// 自分が灯をともした写真(右下に小さな点灯アイコン)
    var hasMyLamp = false
    /// 一列の中の位置(かたむきの交互)
    var index = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var photo: UIImage?
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            photoArea
                .frame(width: 108, height: 135)
                .clipped()
                .overlay {
                    // 光の輪がふくらむ
                    if let burst {
                        Rectangle()
                            .strokeBorder(ChicColor.accent, lineWidth: 3)
                            .scaleEffect(1 + 0.35 * burst)
                            .opacity(1 - burst)
                            .allowsHitTesting(false)
                    }
                }
            // 紙の下の厚いところ:ハッシュタグ(インク)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(tile.tags.prefix(2).enumerated()), id: \.offset) { tagIndex, tag in
                    Text("#\(tag)")
                        .font(V5.hand(tagIndex == 0 ? 12 : 10))
                        .foregroundStyle(tagIndex == 0 ? ChicColor.ink : ChicColor.sub)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(width: 108, height: 30, alignment: .leading)
            .padding(.leading, 1)
        }
        // 118 × 170(上と横 5、下 30)。ひらいたタイルだけ、少しかたむける
        .chicPrint(side: 5, bottom: 0, rotation: isUnlocked ? ChicTilt.degrees(index) : 0)
        .frame(width: 118, height: 170)
        .scaleEffect(scale)
        .rotationEffect(.degrees(scale == 1 ? 0 : Double(scale - 1) * 12))
        .offset(x: shakeOffset)
        .onSpatialTap { point in
            if !isUnlocked {
                // 解禁前:やわらかく2回(ビューア側)+ タイルが横にぷるっと震える
                nope()
            }
            onTap(point)
        }
        .task(id: level == .l3 ? tile.id : "") {
            guard level == .l3, let data = tile.imageData, photo == nil else { return }
            photo = await TileImageLoader.image(id: tile.id, data: data)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isUnlocked ? "昨日の写真。\(tile.tags.map { "#\($0)" }.joined(separator: " "))" : "まだひらいていない写真。\(tile.tags.map { "#\($0)" }.joined(separator: " "))")
        .accessibilityAddTraits(.isButton)
    }

    /// 写真の部分:モザイク → 本物の写真。作者の丸・鍵・灯の印は写真の上に残す。
    private var photoArea: some View {
        ZStack {
            // 絵:ひらくまでは、モザイク(補間しない)。本物の写真は L3 になってから使う
            MosaicView(tiny: tile.tiny, key: tile.id, level: level)
            if level == .l3, let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
            if !isUnlocked || level != .l3 { shimmer }

            VStack {
                HStack(alignment: .top) {
                    AuthorDot(seed: tile.authorSeed, imageData: tile.authorImage)
                        .frame(width: 28, height: 28)
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.black.opacity(0.35)))
                        .scaleEffect(isUnlocked ? 1.8 : 1)
                        .opacity(isUnlocked ? 0 : 1)
                        .animation(.easeOut(duration: 0.4), value: isUnlocked)
                }
                Spacer()
            }
            .padding(6)
            .allowsHitTesting(false)

            if hasMyLamp {
                LampTileMark()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
    }

    /// ゆっくり光の筋が横切る(3.6秒、overlay)
    private var shimmer: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !isActive || reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.6) / 3.6
            GeometryReader { proxy in
                LinearGradient(colors: [.clear, .white.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: proxy.size.width * 0.5)
                    .rotationEffect(.degrees(18))
                    .offset(x: -proxy.size.width * 0.5 + (proxy.size.width * 1.6) * t)
                    .blendMode(.overlay)
            }
        }
        .allowsHitTesting(false)
    }

    private func nope() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 0.05)) { shakeOffset = -5 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.linear(duration: 0.07)) { shakeOffset = 5 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(duration: 0.25, bounce: 0.5)) { shakeOffset = 0 }
        }
    }
}

/// タイル用に小さくした写真(読みこみは1回だけ)
enum TileImageLoader {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(id: String, data: Data) async -> UIImage? {
        if let hit = cache.object(forKey: id as NSString) { return hit }
        let decoded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: 480,
            ]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map { UIImage(cgImage: $0) }
        }.value
        if let decoded { cache.setObject(decoded, forKey: id as NSString) }
        return decoded
    }
}

// MARK: - スクロールで出てくる(v14:下から 34pt + 0.96倍 → spring 0.55 / 0.7。出るたび pop)

struct ScrollReveal: ViewModifier {
    /// 同時に出るものは 70ms ずつずらす
    var index: Int = 0
    /// これが変わると、もう一度出る(タブを開き直したとき)
    var token: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        let visible = shown || reduceMotion
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 34)
            .scaleEffect(visible ? 1 : 0.96)
            .onScrollVisibilityChange(threshold: 0.18) { isVisible in
                guard isVisible, !shown else { return }
                let delay = Double(index % 4) * 0.07
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    guard !shown else { return }
                    Haptics.play(.pop)
                    if reduceMotion { shown = true } else { withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { shown = true } }
                }
            }
            .onChange(of: token) { _, _ in shown = false }
    }
}

extension View {
    func scrollReveal(_ index: Int = 0, token: Int = 0) -> some View { modifier(ScrollReveal(index: index, token: token)) }
}


// MARK: - 今日のみんな(リング)

struct TodayFriendsSection: View {
    let state: HomeState
    let data: HomeLayerData
    let actions: HomeLayerActions
    let onFriend: (HomeFriend) -> Void
    let onInvite: () -> Void

    @Environment(\.palette) private var palette
    @State private var focusedID: String?
    @State private var tick = ScrollTickHaptics()

    private var shotCount: Int { data.friends.filter { $0.hasShot }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Friend").font(.custom("InstrumentSerif-Regular", size: 34)).foregroundStyle(palette.ink)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(verbatim: "\(data.friends.count)").font(.custom("InstrumentSerif-Regular", size: 20)).foregroundStyle(palette.ink)
                    Text(verbatim: "/\(FriendRules.maxFriends)").font(.custom("InstrumentSerif-Italic", size: 14)).foregroundStyle(palette.sub)
                }
                if shotCount > 0 {
                    HStack(spacing: 4) {
                        Circle().fill(Darkroom.orange).frame(width: 5, height: 5)
                        Text(verbatim: "\(shotCount)").font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(Darkroom.orange)
                    .padding(.horizontal, 8).frame(height: 20)
                    .background(Capsule().fill(Darkroom.orange.opacity(0.14)))
                }
                Spacer()
                Button(action: onInvite) {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(palette.ink)
                        .frame(width: 30, height: 30).background(Circle().fill(palette.fill))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Friend 画面を ひらく")
            }
            .padding(.horizontal, 22)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    Button {
                        Haptics.play(.pop)
                        onInvite()
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(Darkroom.orange)
                                .overlay(Image(systemName: "plus").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white))
                                .frame(width: 64, height: 64)
                            Text(verbatim: "Add").font(.custom("InstrumentSerif-Italic", size: 14)).foregroundStyle(palette.ink)
                            Color.clear.frame(height: 24)
                        }
                        .frame(width: 76)
                    }
                    .buttonStyle(SquishButtonStyle())
                    .accessibilityLabel("ともだちを呼ぶ")
                    ForEach(data.friends) { friend in
                        TodayFriendRing(
                            friend: friend,
                            status: HomeLayerRules.friendStatus(state: state, friend: friend),
                            onOpen: { onFriend(friend) }
                        )
                        .id(friend.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focusedID, anchor: .leading)
            .padding(.vertical, -12)
            .onChange(of: focusedID) { _, id in tick.step(id) }
        }
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(palette.fill))
        // mock .yf0:まだ ともだちが いない とき、カードの 右上に 1人の キャラ(浮かせず・はみ出し気味に 重ねる)
        .overlay(alignment: .topTrailing) {
            if data.friends.isEmpty {
                FriendMascot(color: LayerAvatar.colors(UUID()).first ?? Darkroom.orange, armsUp: true, size: 92)
                    .rotationEffect(.degrees(8))
                    .offset(x: 14, y: -10)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// 1人ぶん:撮った人は朝焼けリング +「撮った」、まだの人は点線 +「まだ」
private struct TodayFriendRing: View {
    let friend: HomeFriend
    let status: HomeLayerRules.FriendStatus
    let onOpen: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 6) {
            Button(action: onOpen) {
                ZStack {
                    if status == .shot {
                        Circle().fill(AngularGradient(colors: [Color(hex: "FFD60A"), Color(hex: "FF6A1A"), Color(hex: "FF7AB6"), Color(hex: "FFD60A")], center: .center, startAngle: .degrees(200), endAngle: .degrees(560)))
                    } else {
                        Circle().strokeBorder(Color(hex: "A9A9B3"), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    }
                    LayerAvatar(data: friend.avatarData, seed: friend.seed, name: friend.name)
                        .frame(width: 56, height: 56)
                        .saturation(status == .shot ? 1 : 0.55)
                        .overlay(Circle().strokeBorder(palette.bg, lineWidth: 3))
                }
                .frame(width: 64, height: 64)
                .overlay(alignment: .topTrailing) {
                    if status == .shot {
                        Circle().fill(Color(hex: "FF6A1A")).frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(palette.bg, lineWidth: 2))
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(SquishButtonStyle())
            .accessibilityLabel(friend.name + (status == .shot ? "、撮った" : "、まだ"))

            Text(friend.name)
                .font(.custom("InstrumentSerif-Italic", size: 15))
                .foregroundStyle(palette.ink)
                .lineLimit(1)
            Group {
                switch status {
                case .shot:
                    HStack(spacing: 5) {
                        Circle().fill(LinearGradient(colors: GroupAddColors.sunset, startPoint: .leading, endPoint: .trailing)).frame(width: 6, height: 6)
                        Text("撮った")
                    }
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(LayerFriendColors.shotText(night: palette.isNight))
                case .notYet:
                    Text("まだ").font(.system(size: 10.5, weight: .bold)).foregroundStyle(palette.groupAdd.note)
                case .resting:
                    Text("おやすみ").font(.system(size: 10.5, weight: .bold)).foregroundStyle(palette.groupAdd.note)
                }
            }
            .frame(height: 24)
        }
        .frame(width: 76)
    }
}

// MARK: - ME カード

/// 黒地に巨大な「ME」+ フィルム3枚がふわふわ浮く。タップで ME 画面(円形に広がる)。
/// ME 画面が広がりはじめる位置(最後に押した ME カードの中心。nil ならアバターのあたり)
@MainActor
enum MERevealOrigin {
    static var point: CGPoint?
}

struct MECard: View {
    @State private var frameCenter: CGPoint = .zero
    let caption: String
    let film: [HomeFilmDay]
    let isActive: Bool
    let onTap: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 浮かせる3枚(仕上がった写真だけ。なければ色の札)
    private var thumbs: [Data?] {
        let photos: [Data?] = film.compactMap { day in
            if case .photo(let data) = day.kind { return data }
            return nil
        }
        return Array((photos + [nil, nil, nil]).prefix(3))
    }

    var body: some View {
        Button {
            Haptics.play(.pop)
            MERevealOrigin.point = frameCenter
            onTap()
        } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 32, style: .continuous).fill(palette.ink)
                Text("ME")
                    .font(.system(size: 64, weight: .heavy))
                    .tracking(-0.07 * 64)
                    .foregroundStyle(palette.bg)
                    .padding(.leading, 22)
                    .padding(.top, 12)
                Text(caption)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(0.14 * 11)
                    .foregroundStyle(palette.bg.opacity(0.75))
                    .padding(.leading, 24)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 20)
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || !isActive)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in
                            let phase = reduceMotion ? 0 : sin((t + Double(i) * 1.5) / 4.5 * 2 * .pi)
                            METhumb(data: thumbs[i], index: i)
                                .frame(width: 66, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .shadow(color: .black.opacity(0.5), radius: 8, y: 6)
                                .offset(y: [0, 14, 4][i] - 3 * phase)
                                .rotationEffect(.degrees(phase))
                        }
                    }
                    .rotationEffect(.degrees(-7))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 18)
                .offset(x: 10)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(palette.bg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(18)
            }
            .frame(height: 168)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 20, y: 14)
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
        .onGeometryChange(for: CGPoint.self) { proxy in
            let f = proxy.frame(in: .global)
            return CGPoint(x: f.midX, y: f.midY)
        } action: { frameCenter = $0 }
        .accessibilityLabel("ME。\(caption)")
        .accessibilityHint("自分の画面をひらく")
    }
}

private struct METhumb: View {
    let data: Data?
    let index: Int

    var body: some View {
        if let data, let image = LayerImageCache.avatar(data, key: "me-card-\(index)-\(data.count)") {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            LinearGradient(colors: ChekiFrameColors.placeholder(index), startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

enum ChekiFrameColors {
    static func placeholder(_ index: Int) -> [Color] {
        let sets: [[String]] = [["FFB27A", "FF6A8A", "6C5BA8"], ["9AD0E8", "E9F1E4", "F2B56B"], ["2C3E6B", "E6709A", "FFC27A"]]
        return sets[index % sets.count].map { Color(hex: $0) }
    }
}

// MARK: - ともだちの決まり

enum FriendRules {
    /// 友達の上限(v14 確定)
    static let maxFriends = 12
    static let fullMessage = "ともだちは \(maxFriends)人まで"

    /// つながれるか(自分・相手の、どちらかが 12人なら、つながれない)
    static func canConnect(myCount: Int, theirCount: Int) -> Bool {
        myCount < maxFriends && theirCount < maxFriends
    }
}
