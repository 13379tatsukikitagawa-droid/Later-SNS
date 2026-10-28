import CloudKit
import Network
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

extension Notification.Name {
    /// 参加していたグループが終わった(共有ゾーンが消えた)
    static let groupEnded = Notification.Name("groupEnded")
}

// MARK: - 端末に持つ記録

/// 「抜けている最中」(PendingLeave)。アプリが落ちても、次の起動で続きから実行する。
enum PendingLeaveStore {
    private static let key = "pendingGroupLeaves"

    static var all: [String: Date] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: Date]) ?? [:]
    }

    static func contains(_ groupID: UUID) -> Bool { all[groupID.uuidString] != nil }

    static func begin(_ groupID: UUID, at date: Date = Date()) {
        var value = all
        value[groupID.uuidString] = date
        UserDefaults.standard.set(value, forKey: key)
    }

    static func finish(_ groupID: UUID) {
        var value = all
        value[groupID.uuidString] = nil
        UserDefaults.standard.set(value, forKey: key)
    }
}

/// 抜けたグループのゾーン。オーナー(作った人)は共有から外れられないので、同期で届いても取りこまない。
enum LeftGroupsStore {
    private static let key = "leftGroupZones"

    static func key(for zoneID: CKRecordZone.ID) -> String { "\(zoneID.ownerName)|\(zoneID.zoneName)" }

    static func contains(_ zoneID: CKRecordZone.ID) -> Bool {
        (UserDefaults.standard.stringArray(forKey: key) ?? []).contains(key(for: zoneID))
    }

    static func add(_ zoneID: CKRecordZone.ID) {
        var list = UserDefaults.standard.stringArray(forKey: key) ?? []
        let value = key(for: zoneID)
        if !list.contains(value) { list.append(value) }
        UserDefaults.standard.set(list, forKey: key)
    }
}

/// 終わったグループ(共有ゾーンが消えた)。次に開いたとき、その1回だけ「終わりました」を出す。
enum EndedGroupsStore {
    struct Ended: Codable, Equatable {
        let groupID: UUID
        let name: String
        let colorIndex: Int
    }

    private static let key = "endedGroupsToShow"

    static var pending: [Ended] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Ended].self, from: data)) ?? []
    }

    static func add(_ ended: Ended) {
        var list = pending
        guard !list.contains(where: { $0.groupID == ended.groupID }) else { return }
        list.append(ended)
        save(list)
    }

    static func popFirst() -> Ended? {
        var list = pending
        guard !list.isEmpty else { return nil }
        let first = list.removeFirst()
        save(list)
        return first
    }

    private static func save(_ list: [Ended]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(list), forKey: key)
    }
}

/// 「〇〇さんが、抜けました。」の記録(MemberEvent)を、端末に写して持つ。寿命は7日。一度見たら出さない。
enum MemberEventStore {
    struct Event: Codable, Equatable, Identifiable {
        let id: String
        let groupID: UUID
        let memberName: String
        let eventAt: Date
    }

    static let lifetime: TimeInterval = 7 * 86_400
    private static let eventsKey = "memberEvents"
    private static let seenKey = "seenMemberEventIDs"

    static var all: [Event] {
        guard let data = UserDefaults.standard.data(forKey: eventsKey) else { return [] }
        return (try? JSONDecoder().decode([Event].self, from: data)) ?? []
    }

    static func add(_ event: Event) {
        var list = all.filter { $0.id != event.id }
        list.append(event)
        save(list)
    }

    static func remove(id: String) {
        save(all.filter { $0.id != id })
    }

    /// まだ見ていない・7日以内のお知らせ(新しい順)
    static func unseen(groupID: UUID, now: Date = Date(), seen: Set<String>? = nil) -> [Event] {
        let seenIDs = seen ?? Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? [])
        return all
            .filter { $0.groupID == groupID && !seenIDs.contains($0.id) && now.timeIntervalSince($0.eventAt) < lifetime }
            .sorted { $0.eventAt > $1.eventAt }
    }

    static func markSeen(_ ids: [String]) {
        var seen = UserDefaults.standard.stringArray(forKey: seenKey) ?? []
        for id in ids where !seen.contains(id) { seen.append(id) }
        UserDefaults.standard.set(seen, forKey: seenKey)
    }

    /// 7日より古いもの(端末の写し)。サーバー側の削除に使う
    static func expired(now: Date = Date()) -> [Event] {
        all.filter { now.timeIntervalSince($0.eventAt) >= lifetime }
    }

    private static func save(_ list: [Event]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(list), forKey: eventsKey)
    }

    /// 受けとった MemberEvent のレコード → 写し
    static func event(from record: CKRecord, groupID: UUID) -> Event? {
        guard record["eventType"] as? String == "left",
              let name = record["memberName"] as? String,
              let at = record["eventAt"] as? Date else { return nil }
        return Event(id: record.recordID.recordName, groupID: groupID, memberName: name, eventAt: at)
    }
}

/// つながっているか(抜ける前に確かめる。オフラインでは抜けない)
final class ConnectivityMonitor: @unchecked Sendable {
    static let shared = ConnectivityMonitor()
    private let monitor = NWPathMonitor()
    private(set) var isOnline = true

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in self?.isOnline = path.status == .satisfied }
        monitor.start(queue: DispatchQueue(label: "later.connectivity"))
    }
}

// MARK: - 名前・写真を変える(保存)

enum GroupEditRules {
    /// 「保存」を出すか:名前・写真(大きさ・色あい・位置を含む)・色の、どれかが元と違う。名前が空なら出さない
    static func canSave(originalName: String, name: String, photoChanged: Bool, colorChanged: Bool) -> Bool {
        let final = GroupNameRules.finalize(name)
        guard !final.isEmpty else { return false }
        return final != originalName || photoChanged || colorChanged
    }
}

@MainActor
enum GroupSettingsService {
    enum SaveError: Error { case offline, notReady }

    /// 名前と顔を保存する。メンバー全員が書ける(共有は readWrite)。競合は同期の仕組みが、あとの保存を勝ちにして送りなおす。
    /// 送信はデリゲートのコールバックの外で(sendPendingChangesNow)。
    static func save(group: LaterGroup, name: String, iconData: Data??, colorIndex: Int?, context: ModelContext) async throws {
        guard ConnectivityMonitor.shared.isOnline else { throw SaveError.offline }
        guard let cloudKitManager = CloudKitManager.current else { throw SaveError.notReady }
        group.name = GroupNameRules.finalize(name)
        if let iconData { group.iconImageData = iconData }
        if let colorIndex { group.colorIndex = colorIndex }
        try? context.save()
        cloudKitManager.markForUpload(group: group)
        await cloudKitManager.sendPendingChangesNow()
    }
}

// MARK: - 抜ける

@MainActor
enum GroupLeaveService {
    enum Kind: Equatable {
        /// 通常のメンバー(ホストの場合は、ホスト役を次の人へ渡してグループは続く)
        case member
        /// 最後の1人:グループが消える
        case lastOne
    }

    enum LeaveError: Error, Equatable {
        case offline
        case notReady
        case failed
    }

    static func kind(for group: LaterGroup, user: UserProfile) -> Kind {
        group.members.contains { $0.id != user.id } ? .member : .lastOne
    }

    /// 抜ける。この順で実行し、途中で失敗したら PendingLeave を残して、次の起動で続きから実行する。
    /// 1 PendingLeave → 2 自分の投稿を消す → 3「抜けた」記録 → 4 自分のプロフィール(+ホスト役を渡す)
    /// → 5 共有から外れる → 6 端末の片づけ → 7 PendingLeave を消す
    static func leave(_ group: LaterGroup, user: UserProfile, context: ModelContext) async throws {
        guard ConnectivityMonitor.shared.isOnline else { throw LeaveError.offline }
        guard let cloudKitManager = CloudKitManager.current else { throw LeaveError.notReady }
        let sharing = GroupSharingService(container: cloudKitManager.container, modelContext: context, cloudKitManager: cloudKitManager)
        let isHost = group.ownerCloudKitUserRecordName != nil && group.ownerCloudKitUserRecordName == user.cloudKitUserRecordName
        let kind = kind(for: group, user: user)
        let zoneID = group.cachedZoneID
        let isZoneOwner = zoneID?.ownerName == cloudKitManager.currentUserRecordName

        PendingLeaveStore.begin(group.id)
        do {
            if (kind == .lastOne && isZoneOwner) || zoneID == nil {
                // 最後の1人:ゾーンごと消える(投稿も一緒に消える)
                try await sharing.leaveGroup(group, currentUser: user, isHost: isHost)
            } else if let zoneID {
                let isOwner = zoneID.ownerName == cloudKitManager.currentUserRecordName
                let database = isOwner ? cloudKitManager.container.privateCloudDatabase : cloudKitManager.container.sharedCloudDatabase
                try await deleteOwnPosts(in: group, user: user, zoneID: zoneID, database: database, context: context)
                try await writeLeftEvent(group: group, user: user, zoneID: zoneID, database: database)
                // 自分のプロフィールを消す(ホストならホスト役を次の人へ渡して、送る)
                try await sharing.leaveGroup(group, currentUser: user, isHost: isHost)
                if isHost { await cloudKitManager.sendPendingChangesNow() }
                if isOwner {
                    // 作った人は共有から外れられない(ゾーンは残る)。同期で届いても取りこまない
                    LeftGroupsStore.add(zoneID)
                } else {
                    // 参加者は、shared DB からゾーンを消すと、共有から外れる
                    do {
                        _ = try await cloudKitManager.container.sharedCloudDatabase.modifyRecordZones(saving: [], deleting: [zoneID])
                    } catch let error as CKError where error.code == .zoneNotFound || error.code == .unknownItem {
                        // すでに外れている
                    }
                    LeftGroupsStore.add(zoneID)
                }
            }
        } catch {
            print("[GroupLeave] 抜ける途中で失敗(次の起動で続きから): \(error)")
            throw LeaveError.failed
        }
        // 端末の片づけ(写真は cascade で消える)
        context.delete(group)
        try? context.save()
        PendingLeaveStore.finish(group.id)
    }

    /// 自分の投稿を、このグループの共有ゾーンから消す(7日で消すときと同じ範囲:写真本体・タグ・場所・参照)
    private static func deleteOwnPosts(in group: LaterGroup, user: UserProfile, zoneID: CKRecordZone.ID, database: CKDatabase, context: ModelContext) async throws {
        let myRecordName = CloudKitManager.current?.currentUserRecordName
        let mine = group.photos.filter { photo in
            photo.owner?.id == user.id || (myRecordName != nil && photo.authorCloudKitUserRecordName == myRecordName)
        }
        let ids = mine.compactMap { $0.ckRecordName }.map { CKRecord.ID(recordName: $0, zoneID: zoneID) }
        if !ids.isEmpty {
            let (_, results) = try await database.modifyRecords(saving: [], deleting: ids)
            for (_, result) in results {
                if case .failure(let error) = result, let ck = error as? CKError, ck.code != .unknownItem { throw error }
            }
        }
        for photo in mine { context.delete(photo) }
        try? context.save()
    }

    /// 「抜けた」記録(MemberEvent)を1件。共有から外れる前に書く(外れたあとは書けない)
    private static func writeLeftEvent(group: LaterGroup, user: UserProfile, zoneID: CKRecordZone.ID, database: CKDatabase) async throws {
        let record = CKRecord(recordType: AppRecordType.memberEvent, recordID: CKRecord.ID(recordName: "memberevent_\(UUID().uuidString)", zoneID: zoneID))
        record["eventType"] = "left"
        record["memberId"] = user.id.uuidString
        record["memberName"] = String(user.name.prefix(24))
        record["eventAt"] = Date()
        if let groupRecordName = group.ckRecordName {
            record["groupRef"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: groupRecordName, zoneID: zoneID), action: .none)
        }
        _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
    }

    /// 起動のとき:抜けている最中で止まったものを、続きから(二重には実行しない)
    static func resumePending(context: ModelContext) async {
        guard let user = UserProfile.current(from: (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []) else { return }
        for (idString, _) in PendingLeaveStore.all {
            guard let id = UUID(uuidString: idString) else { continue }
            guard let group = (try? context.fetch(FetchDescriptor<LaterGroup>()))?.first(where: { $0.id == id }) else {
                PendingLeaveStore.finish(id)
                continue
            }
            try? await leave(group, user: user, context: context)
        }
    }

    /// 7日より古い「抜けた」記録を消す(だれかの端末が行えばよい。競合は無視)
    static func pruneMemberEvents(context: ModelContext) async {
        guard let cloudKitManager = CloudKitManager.current else { return }
        let groups = (try? context.fetch(FetchDescriptor<LaterGroup>())) ?? []
        for event in MemberEventStore.expired() {
            MemberEventStore.remove(id: event.id)
            guard let zoneID = groups.first(where: { $0.id == event.groupID })?.cachedZoneID else { continue }
            let isOwner = zoneID.ownerName == cloudKitManager.currentUserRecordName
            let database = isOwner ? cloudKitManager.container.privateCloudDatabase : cloudKitManager.container.sharedCloudDatabase
            _ = try? await database.deleteRecord(withID: CKRecord.ID(recordName: event.id, zoneID: zoneID))
        }
    }
}

// MARK: - 設定画面

/// グループの設定。見た目(円・名前)→ 招待 → メンバー → 抜ける、の順。「保存」は変更があるときだけ出る。
struct GroupSettingsView: View {
    let group: LaterGroup
    let haptics: ExposureHaptics
    let onBack: () -> Void
    /// 「抜ける」を押した(確認から先は、呼び出し側が画面いっぱいに出す)
    let onLeave: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]

    @State private var name: String
    @FocusState private var isNameFocused: Bool
    @State private var discBump = false
    // 写真
    @State private var isEditingPhoto = false
    @State private var recent = RecentPhotos()
    @State private var sourceImage: UIImage?
    @State private var selectedRecentID: String?
    @State private var faceScale: CGFloat = 1
    @State private var faceOffset: CGSize = .zero
    @State private var dragBase: CGSize?
    @State private var tone: FaceTone = .original
    @State private var preview: UIImage?
    @State private var develop: Double = 1
    /// 「色だけ」にした(写真を外した)
    @State private var removedPhoto = false
    @State private var chosenColor: Int?
    @State private var isPickingAlbum = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    // 保存・その他
    @State private var isSaving = false
    @State private var toast: String?
    @State private var confirmingBack = false
    @State private var shareText: String?
    @State private var passphrase: String?
    @State private var copied = false

    init(group: LaterGroup, haptics: ExposureHaptics, onBack: @escaping () -> Void, onLeave: @escaping () -> Void) {
        self.group = group
        self.haptics = haptics
        self.onBack = onBack
        self.onLeave = onLeave
        _name = State(initialValue: group.name)
    }

    private var me: UserProfile? { UserProfile.current(from: profiles) }
    private var colorIndex: Int { chosenColor ?? (GroupPalette.isValid(group.colorIndex) ? group.colorIndex : GroupPalette.index(forName: group.name)) }
    private var photoChanged: Bool { sourceImage != nil || removedPhoto }
    private var canSave: Bool {
        GroupEditRules.canSave(originalName: group.name, name: name, photoChanged: photoChanged, colorChanged: chosenColor != nil && chosenColor != group.colorIndex)
    }
    private var shownImage: UIImage? {
        if let preview { return preview }
        if removedPhoto { return nil }
        return group.iconImageData.flatMap(UIImage.init(data:))
    }
    private var limit: Int { GroupPalette.clampLimit(group.memberLimit) }
    private var memberCount: Int { max(1, group.members.count) }
    private var leaveKind: GroupLeaveService.Kind {
        me.map { GroupLeaveService.kind(for: group, user: $0) } ?? .member
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 0) {
                        hero.padding(.top, 8)
                        nameField.padding(.top, 22)
                        Text("名前と写真は、メンバー全員にすぐ反映されます。")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "6B6B70"))
                            .padding(.top, 10)
                        inviteSection.padding(.top, 30)
                        membersSection.padding(.top, 26)
                        leaveSection.padding(.top, 34)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            if isEditingPhoto {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { closePhotoSheet() }
                    .transition(.opacity)
                photoSheet
                    .transition(.move(edge: .bottom))
            }

            if let toast {
                Text(toast)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                    .padding(.bottom, 40)
                    .transition(.opacity)
            }
        }
        .photosPicker(isPresented: $isPickingAlbum, selection: $pickerItem, matching: .images, photoLibrary: .shared())
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { choose(image) }
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CircleCameraView(haptics: haptics) { image in
                isShowingCamera = false
                choose(image)
            } onClose: { isShowingCamera = false }
        }
        .sheet(isPresented: Binding(get: { shareText != nil }, set: { if !$0 { shareText = nil } })) {
            ShareSheet(activityItems: [shareText ?? ""]) { _ in shareText = nil }
        }
        .alert("変更を保存せずに、もどりますか?", isPresented: $confirmingBack) {
            Button("もどる", role: .destructive, action: onBack)
            Button("つづける", role: .cancel) {}
        }
        .task { passphrase = try? await GroupInviteService.passphrase(for: group, context: modelContext) }
    }

    // MARK: ヘッダー(固定)

    private var header: some View {
        ZStack {
            Text("グループの設定")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            HStack {
                Button {
                    if canSave { confirmingBack = true } else { onBack() }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("グループの画面にもどる")
                Spacer()
                if canSave {
                    Button(action: save) {
                        Group {
                            if isSaving { ProgressView().tint(.black) } else { Text("保存") }
                        }
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background(Capsule().fill(.white))
                    }
                    .buttonStyle(PressScaleStyle())
                    .disabled(isSaving)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: canSave)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    // MARK: ヒーロー(円+カメラのバッジ)

    private var hero: some View {
        GroupCircle(image: shownImage, initial: GroupNameRules.initial(of: name), colorIndex: colorIndex,
                    memberLimit: limit, litCount: memberCount, diameter: 176,
                    discScale: discBump ? 1.04 : 1, develop: develop)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(.white))
                    .overlay(Circle().strokeBorder(Color(hex: "141417"), lineWidth: 4))
                    .offset(x: -6, y: -6)
                    .accessibilityHidden(true)
            }
            .contentShape(Circle())
            .onTapGesture { openPhotoSheet() }
            .gesture(sourceImage == nil || !isEditingPhoto ? nil : dragGesture)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("グループの写真を変える")
            .accessibilityAction { openPhotoSheet() }
    }

    // MARK: 名前

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("グループの名前")
                Spacer()
                Text("\(GroupNameRules.finalize(name).count) / \(GroupNameRules.maxLength)").monospacedDigit()
            }
            .font(.system(size: 10.5, design: .monospaced))
            .foregroundStyle(Color(hex: "8E8E93"))
            TextField("", text: $name)
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(.white)
                .tint(.white)
                .focused($isNameFocused)
                .submitLabel(.done)
                .onChange(of: name) { _, value in
                    let clean = GroupNameRules.sanitizeInput(value)
                    if clean != value { name = clean }
                    bumpDisc()
                }
                .accessibilityLabel("グループの名前")
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 68)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(isNameFocused ? 0.55 : 0.1), lineWidth: 1))
    }

    // MARK: 招待

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("招待")
            VStack(spacing: 0) {
                row {
                    Task {
                        if let url = try? await GroupInviteService.link(for: group, context: modelContext) {
                            shareText = InviteConfig.shareMessage(groupName: group.name, url: url)
                        }
                    }
                } content: {
                    Text("招待リンクをおくる").foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Color(hex: "8E8E93"))
                }
                Divider().overlay(.white.opacity(0.06)).padding(.leading, 16)
                row(action: copyPassphrase) {
                    Text("合言葉").foregroundStyle(.white)
                    Text(passphrase ?? "…").font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
                    Spacer()
                    Text(copied ? "コピーしました" : "コピー")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(copied ? Color(hex: "B8F5D2") : Color(hex: "BCBBC0"))
                }
            }
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.055)))
        }
    }

    // MARK: メンバー

    private var membersSection: some View {
        let ownerRecord = group.ownerCloudKitUserRecordName
        let sorted = group.members.sorted { $0.name < $1.name }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("メンバー")
                Spacer()
                Text("\(memberCount) / \(limit)人").font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Color(hex: "8E8E93"))
            }
            VStack(spacing: 0) {
                ForEach(sorted) { member in
                    HStack(spacing: 12) {
                        PersonaIcon(seed: member.id).frame(width: 36, height: 36).clipShape(Circle())
                        Text(member.name).font(.system(size: 14.5)).foregroundStyle(.white).lineLimit(1)
                        Spacer()
                        if ownerRecord != nil && member.cloudKitUserRecordName == ownerRecord { chip("ホスト") }
                        if member.id == me?.id { chip("あなた") }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 54)
                    .accessibilityElement(children: .combine)
                }
            }
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.055)))
        }
    }

    // MARK: 抜ける(いちばん下に、ひとつだけ。塗りつぶしの赤にしない)

    private var leaveSection: some View {
        VStack(spacing: 10) {
            Button(action: onLeave) {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text(leaveKind == .lastOne ? "グループを消す" : "グループから抜ける")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "FF7A85"))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(hex: "FF7A85").opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color(hex: "FF7A85").opacity(0.28), lineWidth: 1))
            }
            .buttonStyle(PressScaleStyle(scale: 0.97))
            .accessibilityHint("確認のあと、長押しで抜けます")
            VStack(spacing: 2) {
                if leaveKind == .lastOne {
                    Text("あなたが最後の1人です。抜けると、グループは消えます。")
                    Text("消えたグループは、もどせません。")
                } else {
                    Text("抜けると、あなたの写真はこのグループから消えます。")
                    Text("もう一度入るには、新しい招待が必要です。")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(Color(hex: "6B6B70"))
            .multilineTextAlignment(.center)
        }
    }

    // MARK: 写真を変える(小さなシート)

    private var photoSheet: some View {
        VStack(spacing: 14) {
            Capsule().fill(.white.opacity(0.25)).frame(width: 40, height: 5).padding(.top, 10)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    sourceTile("アルバム", "photo.on.rectangle") {
                        Task { await recent.requestIfNeeded(); isPickingAlbum = true }
                    }
                    sourceTile("カメラ", "camera") { isShowingCamera = true }
                    sourceTile("色だけ", "circle.lefthalf.filled") {
                        // 押すたびに、色が変わる(写真は外れる)
                        haptics.playTransient(intensity: 0.25, sharpness: 0.4)
                        chosenColor = (colorIndex + 1) % GroupPalette.count
                        removedPhoto = group.iconImageData != nil
                        sourceImage = nil
                        preview = nil
                        selectedRecentID = nil
                        bumpDisc()
                    }
                    if recent.access == .granted {
                        ForEach(recent.thumbnails, id: \.id) { item in
                            Button {
                                haptics.playTransient(intensity: 0.25, sharpness: 0.4)
                                selectedRecentID = item.id
                                choose(item.image)
                                Task { if let full = await recent.fullImage(id: item.id) { sourceImage = full; renderPreview() } }
                            } label: {
                                Image(uiImage: item.image).resizable().aspectRatio(contentMode: .fill)
                                    .frame(width: 74, height: 92)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white, lineWidth: selectedRecentID == item.id ? 2.5 : 0))
                            }
                            .buttonStyle(PressScaleStyle())
                            .accessibilityLabel("最近の写真")
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            if sourceImage != nil {
                HStack(spacing: 12) {
                    Text("大きさ").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(.white)
                    Slider(value: $faceScale, in: FaceImageRenderer.scaleRange).tint(.white)
                        .onChange(of: faceScale) { _, _ in
                            faceOffset = FaceImageRenderer.clampOffset(faceOffset, scale: faceScale)
                            renderPreview()
                        }
                }
                .padding(.horizontal, 20)
                HStack(spacing: 8) {
                    ForEach(FaceTone.allCases) { value in
                        Button {
                            haptics.playTransient(intensity: 0.25, sharpness: 0.4)
                            tone = value
                            renderPreview()
                        } label: {
                            Text(value.label)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(tone == value ? .black : .white)
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .background(Capsule().fill(tone == value ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.white.opacity(0.08))))
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
            Spacer(minLength: 0)
            Button {
                haptics.playTransient(intensity: 0.25, sharpness: 0.4)
                closePhotoSheet()
            } label: {
                Text("この写真にする")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(PressScaleStyle(scale: 0.97))
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(height: 390)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "1D1D21"), Color(hex: "101012")], startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()
        )
    }

    private func sourceTile(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 20))
                Text(title).font(.system(size: 11.5, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(width: 74, height: 92)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
    }

    // MARK: 部品

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.16 * 11)
            .foregroundStyle(Color(hex: "8E8E93"))
            .accessibilityAddTraits(.isHeader)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(Color(hex: "BCBBC0"))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(.white.opacity(0.08)))
    }

    private func row<Content: View>(action: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        Button(action: action) {
            HStack(spacing: 10) { content() }
                .font(.system(size: 14.5))
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 54)
                .contentShape(Rectangle())
        }
        .buttonStyle(RowHighlightStyle())
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragBase == nil { dragBase = faceOffset }
                guard let base = dragBase else { return }
                let disc = 176 * 0.74 * faceScale
                faceOffset = FaceImageRenderer.clampOffset(
                    CGSize(width: base.width + value.translation.width / disc, height: base.height + value.translation.height / disc),
                    scale: faceScale)
                renderPreview()
            }
            .onEnded { _ in dragBase = nil }
    }

    // MARK: 動き

    private func bumpDisc() {
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.12)) { discBump = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { withAnimation(.easeIn(duration: 0.12)) { discBump = false } }
    }

    private func openPhotoSheet() {
        isNameFocused = false
        withAnimation(.timingCurve(0.22, 0.8, 0.24, 1, duration: 0.45)) { isEditingPhoto = true }
    }

    private func closePhotoSheet() {
        withAnimation(.easeOut(duration: 0.3)) { isEditingPhoto = false }
    }

    /// 写真を選んだ直後:1.5秒で現像
    private func choose(_ image: UIImage) {
        sourceImage = image
        removedPhoto = false
        faceScale = 1
        faceOffset = .zero
        tone = .original
        renderPreview()
        guard !reduceMotion else { return }
        develop = 0
        withAnimation(.easeOut(duration: 1.5)) { develop = 1 }
        bumpDisc()
    }

    private func renderPreview() {
        guard let sourceImage else { preview = nil; return }
        preview = FaceImageRenderer.render(sourceImage, scale: faceScale, offset: faceOffset, tone: tone, side: 512)
    }

    private func copyPassphrase() {
        guard let passphrase else { return }
        UIPasteboard.general.string = passphrase
        haptics.playTransient(intensity: 0.25, sharpness: 0.4)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { copied = false }
    }

    /// 保存:ごく軽く1回 →「保存しました ・ メンバー全員に反映されます」。失敗しても入力は保つ
    private func save() {
        guard canSave, !isSaving else { return }
        isSaving = true
        haptics.playTransient(intensity: 0.25, sharpness: 0.4)
        let iconData: Data?? = {
            if let sourceImage { return .some(FaceImageRenderer.render(sourceImage, scale: faceScale, offset: faceOffset, tone: tone)?.jpegData(compressionQuality: 0.85)) }
            if removedPhoto { return .some(nil) }
            return nil
        }()
        Task {
            defer { isSaving = false }
            do {
                try await GroupSettingsService.save(group: group, name: name, iconData: iconData, colorIndex: chosenColor, context: modelContext)
                sourceImage = nil
                preview = nil
                removedPhoto = false
                chosenColor = nil
                name = group.name
                show("保存しました ・ メンバー全員に反映されます")
            } catch {
                show("保存できませんでした。もういちど")
            }
        }
    }

    private func show(_ text: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.2)) { if toast == text { toast = nil } }
        }
    }
}

/// 押している間、行が薄く光る
private struct RowHighlightStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.white.opacity(configuration.isPressed ? 0.06 : 0))
    }
}
