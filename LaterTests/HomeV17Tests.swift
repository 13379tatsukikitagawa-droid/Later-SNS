import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// v17「下までスクロールできる Home」の決めごと
@MainActor
struct HomeV17Tests {
    private func at(hour: Int, minute: Int = 0, dayOffset: Int = 0) -> Date {
        let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: Calendar.current.startOfDay(for: Date()))!
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    @Test func 区画の並びは状態ごとに表のとおり() {
        #expect(HomeV17Rules.order(.first) == [.film, .develop, .day, .words, .friends, .promises])
        #expect(HomeV17Rules.order(.dawn) == [.film, .words, .friends, .day, .develop])
        #expect(HomeV17Rules.order(.night) == [.film, .day, .develop, .friends, .words])
        #expect(HomeV17Rules.order(.rest) == [.film, .day, .develop, .friends, .words])
        let shot = at(hour: 10)
        for state in [HomeState.deciding(shotAt: shot), .ready(shotAt: shot), .opened(shotAt: shot), .more(shotAt: shot, remaining: 2)] {
            #expect(HomeV17Rules.order(state) == [.film, .words, .friends, .day])
        }
        // やくそくは初日だけ
        #expect(!HomeV17Rules.order(.dawn).contains(.promises))
    }

    @Test func スクロールの数字() {
        #expect(HomeV17Rules.parallax(100) == 22)
        #expect(HomeV17Rules.parallax(2000) == 700 * 0.22)
        #expect(HomeV17Rules.parallax(-50) == 0)
        #expect(abs(HomeV17Rules.ringTurn(100) - 9) < 0.0001)
        #expect(HomeV17Rules.headerGlass(8) == 0)
        #expect(HomeV17Rules.headerGlass(54) == 1)
        #expect(HomeV17Rules.moonFade(0) == 0)
        #expect(HomeV17Rules.moonFade(36) == 1)
        #expect(HomeV17Rules.cue(0) == 1)
        #expect(HomeV17Rules.cue(30) == 0)
        #expect(HomeV17Rules.bottomSpace == 240)
    }

    @Test func 揺れは強さに合わせて04から3pt() {
        #expect(HomeV17Rules.rattleAmplitude(0) == 0)
        #expect(HomeV17Rules.rattleAmplitude(0.04) == 0)
        #expect(abs(HomeV17Rules.rattleAmplitude(1) - 3) < 0.0001)
        #expect(HomeV17Rules.rattleAmplitude(0.5) > 0.4 && HomeV17Rules.rattleAmplitude(0.5) < 3)
    }

    @Test func 一日のピル() {
        #expect(HomeV17Rules.phase(hour: 3) == .sleep)
        #expect(HomeV17Rules.phase(hour: 9.1) == .open)
        #expect(HomeV17Rules.phase(hour: 9.5) == .shoot)
        #expect(HomeV17Rules.phase(hour: 20.9) == .shoot)
        #expect(HomeV17Rules.phase(hour: 21) == .evening)
        #expect(HomeV17Rules.phase(hour: 24) == .lightsOut)
        #expect(HomeV17Rules.clockText(9.1167) == "09:07")
        #expect(HomeV17Rules.clockText(0) == "00:00")
    }

    @Test func つまみの触覚() {
        #expect(HomeV17Rules.dragHaptic(from: 8.9, to: 9.1) == .thud)
        #expect(HomeV17Rules.dragHaptic(from: 9.1, to: 8.9) == .thud)
        #expect(HomeV17Rules.dragHaptic(from: 20.9, to: 21.1) == .click)
        #expect(HomeV17Rules.dragHaptic(from: 12.9, to: 13.1) == .tick)
        #expect(HomeV17Rules.dragHaptic(from: 12.1, to: 12.5) == nil)
        #expect(HomeV17Rules.dragHaptic(from: 23.5, to: 24) == .heart)
    }

    @Test func フィルムの3こま() {
        let a = at(hour: 10), b = at(hour: 13)
        #expect(HomeV17Rules.filmFrames(shots: [], state: .dawn) == [.next(index: 0), .later(index: 1), .later(index: 2)])
        #expect(HomeV17Rules.filmFrames(shots: [b, a], state: .more(shotAt: b, remaining: 1)) == [.shot(index: 0, takenAt: a), .shot(index: 1, takenAt: b), .next(index: 2)])
        // 夜は、撮れなかったこまが ななめのしま
        #expect(HomeV17Rules.filmFrames(shots: [a, b], state: .night) == [.shot(index: 0, takenAt: a), .shot(index: 1, takenAt: b), .rest(index: 2)])
        // 撮ったあと(つぎが撮れない状態)は「あとで」
        #expect(HomeV17Rules.filmFrames(shots: [a], state: .ready(shotAt: a)) == [.shot(index: 0, takenAt: a), .later(index: 1), .later(index: 2)])
    }

    @Test func ことばの鍵() {
        #expect(HomeV17Rules.wordsMode(state: .first, shotsToday: 0) == .empty)
        #expect(HomeV17Rules.wordsMode(state: .dawn, shotsToday: 0) == .locked)
        #expect(HomeV17Rules.wordsMode(state: .ready(shotAt: Date()), shotsToday: 1) == .open)
        #expect(HomeV17Rules.wordsMode(state: .rest, shotsToday: 0) == .locked)
    }

    @Test func ともだちはグループとふった人をまとめて12人まで() {
        let group = (0..<3).map { i in
            HomeFriend(id: "g\(i)", name: "g\(i)", avatarData: nil, seed: UUID(), hasShot: false, city: nil, mosaicTiny: nil, mosaicKey: "g\(i)", tag: nil, knockOff: false, isMe: false, groupIDs: [UUID()])
        }
        let bump = [BumpFriend(id: "g1", name: "おなじ人"), BumpFriend(id: "b1", name: "ゆい"), BumpFriend(id: "me", name: "わたし")]
        let list = HomeV17Rules.friends(group: group, bump: bump, counts: ["g0": 2, "b1": 1], myID: "me")
        #expect(list.map(\.id) == ["g0", "g1", "g2", "b1"])
        #expect(list[0].shotsToday == 2)
        #expect(list[0].canKnock)
        // ふって つながっただけの人は、つつけない(同じグループがない)
        #expect(!list[3].canKnock)
        let many = (0..<20).map { BumpFriend(id: "x\($0)", name: "x") }
        #expect(HomeV17Rules.friends(group: [], bump: many, counts: [:], myID: nil).count == FriendRules.maxFriends)
        // 色の丸の種は、同じ id なら同じ
        #expect(HomeV17Rules.seed(for: "abc") == HomeV17Rules.seed(for: "abc"))
    }

    @Test func バイブの設定は3段() {
        let saved = UserDefaults.standard.string(forKey: AppHapticsSetting.levelDefaultsKey)
        let savedOld = UserDefaults.standard.object(forKey: ExposureHaptics.enabledDefaultsKey)
        defer {
            if let saved { UserDefaults.standard.set(saved, forKey: AppHapticsSetting.levelDefaultsKey) } else { UserDefaults.standard.removeObject(forKey: AppHapticsSetting.levelDefaultsKey) }
            if let savedOld { UserDefaults.standard.set(savedOld, forKey: ExposureHaptics.enabledDefaultsKey) } else { UserDefaults.standard.removeObject(forKey: ExposureHaptics.enabledDefaultsKey) }
        }
        // 古い設定で OFF の人は、オフのまま
        UserDefaults.standard.removeObject(forKey: AppHapticsSetting.levelDefaultsKey)
        UserDefaults.standard.set(false, forKey: ExposureHaptics.enabledDefaultsKey)
        #expect(AppHapticsSetting.level == .off)
        UserDefaults.standard.removeObject(forKey: ExposureHaptics.enabledDefaultsKey)
        #expect(AppHapticsSetting.level == .strong)
        AppHapticsSetting.level = .normal
        #expect(AppHapticsSetting.isEnabled)
        #expect(AppHapticsSetting.scale == 0.65)
        AppHapticsSetting.level = .off
        #expect(!AppHapticsSetting.isEnabled)
        #expect(UserDefaults.standard.object(forKey: ExposureHaptics.enabledDefaultsKey) as? Bool == false)
    }

    /// HAPTICS.md(モック v64)の 表に そろえた 値
    @Test func バイブの表() {
        #expect(Haptics.Tuning.beats(.tick).first?.intensity == 0.35 && Haptics.Tuning.beats(.tick).first?.sharpness == 0.6)
        #expect(Haptics.Tuning.beats(.detent).first?.intensity == 0.6)
        #expect(Haptics.Tuning.beats(.pop).first?.intensity == 0.70)
        #expect(Haptics.Tuning.beats(.click).first?.intensity == 0.65)
        #expect(Haptics.Tuning.beats(.thud).first?.intensity == 1.0 && Haptics.Tuning.beats(.thud).first?.sharpness == 0.3)
        #expect(Haptics.Tuning.beats(.soft).first?.intensity == 0.30)
        #expect(Haptics.Tuning.beats(.double).map(\.time) == [0, 0.07])
        #expect(Haptics.Tuning.beats(.heart).map(\.intensity) == [0.9, 0.55])
        #expect(Haptics.Tuning.beats(.burst).last?.time == 0.3)
        #expect(Haptics.Tuning.beats(.success).map(\.intensity) == [0.9, 0.9, 0.9])
    }

    @Test func 日付の文字() {
        var c = DateComponents()
        c.year = 2026; c.month = 10; c.day = 27; c.hour = 9
        let d = Calendar.current.date(from: c)!
        #expect(HomeV17Rules.chekiDate(d) == "'26 10 27")
        #expect(HomeV17Rules.dotDate(d) == "10.27")
    }
}

/// 見た目の確認用(LATER_SNAPSHOT_DIR が設定されている時だけ)。4つの状態を、上から下までスクロールして撮る
@MainActor
struct HomeV17SnapshotTests {
    private static let sizes: [(String, CGSize)] = [("pro", CGSize(width: 402, height: 874)), ("se", CGSize(width: 375, height: 667))]

    private func at(hour: Int, minute: Int = 0, dayOffset: Int = 0) -> Date {
        let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: Calendar.current.startOfDay(for: Date()))!
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    private func friends(_ n: Int) -> [V17Friend] {
        let names = ["みお", "ゆい", "ここ", "あやね"]
        return (0..<n).map { i in
            let home = HomeFriend(id: "f\(i)", name: names[i % 4], avatarData: nil, seed: HomeV17Rules.seed(for: "f\(i)"), hasShot: true, city: nil, mosaicTiny: nil, mosaicKey: "f\(i)", tag: nil, knockOff: false, isMe: false, groupIDs: [UUID()])
            return V17Friend(id: "f\(i)", name: names[i % 4], avatarData: nil, seed: home.seed, shotsToday: [2, 1, 3, 0][i % 4], home: home)
        }
    }

    private let words = ["散歩", "空", "コーヒー", "電車", "夕方"].enumerated().map { i, t in
        WorldWordsStore.Word(tag: t, count: 40 - i * 5, tones: [])
    }

    private func home(state: HomeState, now: Date, shots: [Date], data: HomeV17Data) -> some View {
        HomeView(
            state: state, now: now, light: state == .first ? .loading : .count(128), developContent: state == .first ? .first : .developing(capturedAt: now, isNight: state.isNight), developTexture: nil,
            shotsToday: shots.count,
            tones: DevelopProgress.defaultTones, openedTones: DevelopProgress.defaultTones,
            groupSummaries: [], canCreateGroup: true, isCovered: false, holdModel: HoldGaugeModel(),
            avatarImage: nil, avatarSeed: UUID(), showsAvatarBadge: false,
            onOpenProfile: {}, onDevelopTap: {}, onSelectGroup: { _ in }, onCreateGroup: {},
            v17: data, bump: V17Bump()
        )
    }

    private func shoot<V: View>(_ view: V, name: String, size: CGSize, offsets: [CGFloat], dir: URL) async throws {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: size)
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await Task.sleep(for: .seconds(1.0))
        for offset in offsets {
            if let scroll = Self.findScroll(in: host.view, width: size.width) {
                let maxY = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
                scroll.setContentOffset(CGPoint(x: 0, y: min(offset, maxY) - scroll.adjustedContentInset.top), animated: false)
            }
            try await Task.sleep(for: .seconds(1.3))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try image.pngData()?.write(to: dir.appendingPathComponent("\(name)-\(Int(offset)).png"))
        }
        window.isHidden = true
    }

    private static func findScroll(in view: UIView, width: CGFloat) -> UIScrollView? {
        var best: UIScrollView?
        func walk(_ v: UIView) {
            if let s = v as? UIScrollView, s.bounds.width >= width - 1 {
                if best == nil || s.contentSize.height > best!.contentSize.height { best = s }
            }
            v.subviews.forEach(walk)
        }
        walk(view)
        return best
    }

    @Test func v17のスナップショット() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"] else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let offsets: [CGFloat] = [0, 60, 700, 1300, 1900, 2500, 9999]
        for (label, size) in Self.sizes {
            let noon = at(hour: 14, minute: 53)
            try await shoot(home(state: .first, now: noon, shots: [], data: HomeV17Data()).environment(\.palette, .day),
                            name: "\(label)-first", size: size, offsets: offsets, dir: dir)
            let morning = at(hour: 9, minute: 41)
            try await shoot(home(state: .dawn, now: morning, shots: [], data: HomeV17Data(words: words, countries: 17, friends: friends(4))).environment(\.palette, .day),
                            name: "\(label)-dawn", size: size, offsets: offsets, dir: dir)
            let night = at(hour: 6, minute: 6)
            let shots = [at(hour: 9, minute: 8, dayOffset: -1), at(hour: 12, minute: 40, dayOffset: -1)]
            try await shoot(home(state: .night, now: night, shots: shots, data: HomeV17Data(shots: shots, words: words, countries: 17, friends: friends(4))).environment(\.palette, .night),
                            name: "\(label)-night", size: size, offsets: offsets, dir: dir)
            let after = at(hour: 15)
            let one = [at(hour: 10, minute: 12)]
            try await shoot(home(state: .ready(shotAt: one[0]), now: after, shots: one, data: HomeV17Data(shots: one, words: words, countries: 17, friends: friends(4))).environment(\.palette, .day),
                            name: "\(label)-after", size: size, offsets: offsets, dir: dir)
        }
    }
}
