import SwiftUI
import SwiftData
import ImageIO
import UserNotifications

// P29:MEV86View に 本物の データ(自分の 写真 + Recap)を つなぐ。アプリを ひらいた 時 / 前に 来た 時に「作る べき Recap」を 作る(本命)。
// 写真は 小さな サムネイルを 新しい 順に 少しずつ 読む(フル解像度を 一覧に 使わない)。

struct MEV86Host: View {
    let onBack: () -> Void
    let onShoot: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    @State private var data = MEV86Data()
    @State private var loading: Task<Void, Never>?

    private var me: UserProfile? { UserProfile.current(from: profiles) }

    var body: some View {
        MEV86View(data: data, onBack: onBack, onShoot: onShoot, onKeep: toggleKeep, onSeen: { id in RecapStore.shared.markSeen(id); data.recaps = RecapStore.shared.items })
            .task { reload() }
            .onChange(of: scenePhase) { _, p in if p == .active { reload() } }
            .onDisappear { loading?.cancel() }
    }

    private func reload() {
        guard let me else { return }
        loading?.cancel()
        let kept = Set(me.pinnedPhotoIDs)
        let photos = me.photos.sorted { $0.captureDate > $1.captureDate }
        var shots = photos.map { MEV86Shot(id: $0.id.uuidString, date: $0.captureDate, tag: $0.tags.first, kept: kept.contains($0.id), image: nil) }
        let now = Date()
        RecapStore.shared.refresh(now: now, shots: shots.map { RecapShot(id: $0.id, date: $0.date, tag: $0.tag, kept: $0.kept) })
        RecapNotifier.scheduleWeekly()
        data = MEV86Data(shots: shots, recaps: RecapStore.shared.items, now: now)
        // サムネイルを 新しい 順に 少しずつ(Recap に 使う 写真を 先に)
        let first = Set(RecapStore.shared.items.flatMap(\.photoIDs))
        let order = photos.enumerated().sorted { (first.contains($0.element.id.uuidString) ? 0 : 1, $0.offset) < (first.contains($1.element.id.uuidString) ? 0 : 1, $1.offset) }.map(\.element)
        loading = Task { @MainActor in
            for p in order {
                if Task.isCancelled { return }
                let id = p.id.uuidString
                let bytes = p.imageData
                let img = await Task.detached(priority: .utility) { MEV86Host.thumb(bytes, 640) }.value
                if let i = shots.firstIndex(where: { $0.id == id }) { shots[i].image = img; data.shots = shots }
            }
        }
    }

    nonisolated static func thumb(_ d: Data, _ max: CGFloat) -> UIImage? {
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceShouldCacheImmediately: true, kCGImageSourceThumbnailMaxPixelSize: max]
        guard let src = CGImageSourceCreateWithData(d as CFData, nil), let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    private func toggleKeep(_ id: String) {
        guard let me, let uuid = UUID(uuidString: id) else { return }
        if let i = me.pinnedPhotoIDs.firstIndex(of: uuid) { me.pinnedPhotoIDs.remove(at: i) } else { me.pinnedPhotoIDs.append(uuid) }
        try? modelContext.save()
        if let i = data.shots.firstIndex(where: { $0.id == id }) { data.shots[i].kept.toggle() }
    }
}

/// 毎週 月曜 9:00 の ローカル通知(「先週の Recap が できました」)。許可が ある 時だけ。押すと ME へ(アプリを ひらく)
enum RecapNotifier {
    static func setEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: "notify.recap")
        if on { scheduleWeekly() } else { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["recap.weekly"]) }
    }

    static func scheduleWeekly() {
        if UserDefaults.standard.object(forKey: "notify.recap") as? Bool == false { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { s in
            guard s.authorizationStatus == .authorized || s.authorizationStatus == .provisional else { return }
            let c = UNMutableNotificationContent()
            c.title = "Lattag"
            c.body = "先週の Recap が できました"
            c.sound = .default
            var comps = DateComponents(); comps.weekday = 2; comps.hour = 9; comps.minute = 0
            let req = UNNotificationRequest(identifier: "recap.weekly", content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
            center.add(req)
        }
    }
}
