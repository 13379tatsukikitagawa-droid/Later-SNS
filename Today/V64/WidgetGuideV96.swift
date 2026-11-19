import SwiftUI

// P39-D:設定 › ウィジェット の 案内(3ステップ + 見本)。はじめての 説明(v95)の さいごに 1回 だけ(スキップ できる)。
// 見本は 実際の ウィジェットと 同じ View(拡張と 共有)を 見本の データで 並べる。

enum WidgetGuideV96 {
    static let seenKey = "widgetGuideV96.seen"
    static var seen: Bool { UserDefaults.standard.bool(forKey: seenKey) }
    static func markSeen() { UserDefaults.standard.set(true, forKey: seenKey) }

    /// 見本の データ(画像なし。写真は 灰色の 台紙)
    static func sample(now: Date = Date()) -> WidgetModel {
        let key = LaterDay.key(for: now)
        let friends = [("れな", "れ", "C8F25A", 3), ("あや", "あ", "9ED8FF", 2), ("そら", "そ", "EE5E9C", 0), ("かい", "か", "F4B942", 1)].map { n, i, c, s in
            FriendRing(uid: n, name: n, initial: i, colorHex: c, shotsToday: s, avatar: nil)
        }
        let snap = WidgetSnapshot(dayKey: key, writtenAt: now, shots: 1, limit: 3, shotTimes: [now.addingTimeInterval(-3600)], shotBlurs: [], friends: friends, today: nil,
                                  yesterday: DaySummary(dayKey: key, people: 4, count: 11, tag: "夕焼け", names: ["れな", "あや", "そら", "かい"]),
                                  yesterdayPhotos: [], lockedPreviews: [], mondoTag: "夕焼け", mondoCount: 1203, mondoCountries: 128,
                                  trip: TripSnap(id: "sample", title: "京都 2泊3日", sub: "11/19 THU ・ 3人", day: 2, count: 12, total: 23, passNo: 4065, filled: Array(0..<12), cover: nil),
                                  next: nil, myRecordName: nil, myName: "")
        return WidgetModel.make(snap, now: now)
    }
}

struct WidgetGuideV96Sheet: View {
    var onClose: () -> Void
    @State private var step = 0
    private let steps: [(String, String, String)] = [
        ("ホーム画面を 長押しする", "アイコンの ない 所を 1秒 ほど。アイコンが ゆれたら できている。", "hand.tap"),
        ("左上の「＋」を 押す", "iOS 18 では「編集」→「ウィジェットを 追加」。", "plus.circle"),
        ("「Lattag」を さがして 追加", "検索欄に Lattag。小 ・ 中 ・ 大から えらんで 追加。", "square.grid.2x2"),
    ]

    var body: some View {
        let m = WidgetGuideV96.sample()
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("ウィジェット").font(LF.inter(900, 26)).foregroundStyle(.white)
                    Spacer()
                    Button { Haptics.play(.tick); onClose() } label: { Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44).background(.white.opacity(0.1), in: Circle()) }.buttonStyle(.plain).accessibilityLabel("とじる")
                }
                Text("ホーム画面 ・ ロック画面に 置けます。\n撮りたくなる ・ 待ちたくなる ・ 見たくなる。").font(LF.inter(600, 13)).foregroundStyle(.white.opacity(0.6)).fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 10) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                        HStack(spacing: 14) {
                            Text("\(i + 1)").font(LF.mono(14, bold: true)).foregroundStyle(HV.ink).frame(width: 30, height: 30).background(HV.lime, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.0).font(LF.inter(800, 15)).foregroundStyle(.white)
                                Text(s.1).font(LF.inter(500, 12)).foregroundStyle(.white.opacity(0.6)).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: s.2).font(.system(size: 20)).foregroundStyle(HV.lime.opacity(0.9))
                        }
                        .padding(14).background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
                Text("見本").font(LF.mono(10)).tracking(2).foregroundStyle(HV.lime).padding(.top, 6)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        item("レンズ", "押すと すぐ 撮れる", 158, 158, WColor.ground) { LattagLensView(model: m) }
                        item("9:00 まで", "現像が ひらくまで", 158, 158, WColor.lime) { LattagUntil9View(model: m) }
                        item("Mondo", "世界の きのうの お題", 158, 158, WColor.ground) { LattagMondoView(model: m) }
                        item("Friends", "今日 だれが 撮った?", 338, 158, WColor.ground) { LattagFriendsView(model: m) }
                        item("Trip", "みんなの 枚数", 338, 158, WColor.ground) { if let t = m.trip { LattagTripView(trip: t) } }
                    }.padding(.horizontal, 1)
                }
            }.padding(20)
        }
        .background(Color(hex: "141516").ignoresSafeArea())
        .presentationDetents([.large])
    }

    private func item<V: View>(_ name: String, _ desc: String, _ w: CGFloat, _ h: CGFloat, _ bg: Color, @ViewBuilder _ v: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            v().frame(width: w, height: h).background(bg).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text(name).font(LF.inter(800, 13)).foregroundStyle(.white)
            Text(desc).font(LF.inter(500, 11)).foregroundStyle(.white.opacity(0.55))
        }
    }
}
