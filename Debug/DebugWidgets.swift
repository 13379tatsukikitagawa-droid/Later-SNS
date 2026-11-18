#if DEBUG
import SwiftUI
import WidgetKit

/// DEBUG:ウィジェットを アプリの 中で 並べて 見る(`-debugRoute widgets -debugWShots 1 -debugWHour 22`)。
/// 実際の ウィジェットと 同じ View を 使う(画像は App Group の w/ に 書く)。
struct DebugWidgetsView: View {
    private let d = UserDefaults.standard
    var body: some View {
        let hour = d.object(forKey: "debugWHour") == nil ? 14 : d.integer(forKey: "debugWHour")
        let shots = d.integer(forKey: "debugWShots")
        let now = Calendar.current.date(bySettingHour: hour, minute: 40, second: 0, of: Date()) ?? Date()
        let snap = Self.snapshot(shots: shots, now: now)
        let m = WidgetModel.make(snap, now: now, filmShots: nil)
        let e = LattagEntry(date: now, model: m, hourIndex: d.integer(forKey: "debugWIndex"))
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("shots \(shots) ・ \(hour):40").font(.caption).foregroundStyle(.white)
                HStack(spacing: 14) {
                    box(158, 158, WColor.ground) { LattagLensView(model: m) }
                    box(158, 158, m.part == .evening ? WColor.ground : WColor.lime) { LattagUntil9View(model: m) }
                }
                HStack(spacing: 14) {
                    box(158, 158, WColor.ground) { LattagFriendView(entry: e) }
                    box(158, 158, WColor.ground) { LattagMondoView(model: m) }
                }
                ZStack {
                    LinearGradient(colors: [Color(hex6: 0x6B5A50), Color(hex6: 0x2A2326)], startPoint: .top, endPoint: .bottom)
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            LattagLockRingView(model: m).frame(width: 76, height: 76).clipShape(Circle())
                            LattagLockOpenView(model: m).frame(width: 76, height: 76).clipShape(Circle())
                        }
                        LattagLockRectView(model: m).frame(width: 172, height: 76).padding(8).background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                        LattagLockInlineView(model: m).font(.system(size: 15)).foregroundStyle(.white)
                    }.foregroundStyle(.white).padding(16)
                }.clipShape(RoundedRectangle(cornerRadius: 24))
            }.padding(16)
        }
        .background(Color(hex6: 0x1C1C1E).ignoresSafeArea())
    }

    private func box<V: View>(_ w: CGFloat, _ h: CGFloat, _ bg: Color, @ViewBuilder _ v: () -> V) -> some View {
        v().frame(width: w, height: h).background(bg).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    static func snapshot(shots: Int, now: Date) -> WidgetSnapshot {
        func save(_ key: String, _ name: String) -> String {
            if let img = SampleData.photo(key), let url = LattagShared.imageURL(name) {
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? img.jpegData(compressionQuality: 0.7)?.write(to: url)
            }
            return name
        }
        let a = save("a", "dbg_a.jpg"), b = save("b", "dbg_b.jpg"), c = save("c", "dbg_c.jpg")
        let friends = [("れな", "れ", "C8F25A", 3), ("あや", "あ", "9ED8FF", 2), ("そら", "そ", "EE5E9C", 0), ("かい", "か", "F4B942", 1)].map { n, i, col, s in
            FriendRing(uid: n, name: n, initial: i, colorHex: col, shotsToday: s, avatar: nil, knock: nil)
        }
        let cal = Calendar.current
        let key = LaterDay.key(for: now)
        return WidgetSnapshot(dayKey: key, writtenAt: now, shots: shots, limit: 3,
                              shotTimes: (0..<shots).map { cal.date(byAdding: .minute, value: -60 * ($0 + 1), to: now) ?? now },
                              shotBlurs: [a, b, c].prefix(shots).map { $0 },
                              friends: friends, today: nil,
                              yesterday: DaySummary(dayKey: key, people: 4, count: 11, tag: "夕焼け", names: ["れな", "あや", "そら", "かい"]),
                              yesterdayPhotos: shots > 0 ? [YPhoto(uid: "れな", name: "れな", time: "21:12", tag: "夕焼け", thumb: a), YPhoto(uid: "あや", name: "あや", time: "17:05", tag: "おやつ", thumb: b)] : [],
                              lockedPreviews: [c], mondoTag: "夕焼け", mondoCount: 1203, mondoCountries: 128, trip: nil, next: nil, myRecordName: nil, myName: "ゆい")
    }
}
#endif
