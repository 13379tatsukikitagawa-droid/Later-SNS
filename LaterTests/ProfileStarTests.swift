import SwiftUI
import Testing
@testable import Later_再度

/// プロフィール v5「あなたの星」:配置の計算と、見た目の確認(LATER_SNAPSHOT_DIR がある時だけ)
@MainActor
struct ProfileStarTests {
    // MARK: 7日の点

    @Test func slotsRecedeTowardTheCenter() {
        #expect(ProfileStarLayout.slotCenter(0) == CGPoint(x: 195, y: 736))
        #expect(ProfileStarLayout.slotCenter(6).y == 524)
        for slot in 1..<ProfileStarLayout.slotCount {
            // 奥ほど上・小さい・うすい
            #expect(ProfileStarLayout.slotCenter(slot).y < ProfileStarLayout.slotCenter(slot - 1).y)
            #expect(ProfileStarLayout.slotRadius(slot) < ProfileStarLayout.slotRadius(slot - 1))
            #expect(ProfileStarLayout.slotOpacity(slot) < ProfileStarLayout.slotOpacity(slot - 1))
        }
        #expect(ProfileStarLayout.slotRadius(0) == 16)
        #expect(ProfileStarLayout.slotRadius(1) == 12.5)
        #expect(abs(ProfileStarLayout.slotRadius(6) - 6) < 0.001)
        #expect(ProfileStarLayout.slotOpacity(0) == 1)
        #expect(abs(ProfileStarLayout.slotOpacity(6) - 0.45) < 0.001)
        // ジグザグ:左右に交互、奥ほど中央へ(最小で50%)
        let near = abs(ProfileStarLayout.slotCenter(1).x - 195)
        let far = abs(ProfileStarLayout.slotCenter(6).x - 195)
        #expect(far < near)
        #expect(far >= 96 * 0.5 - 0.001)
        #expect((ProfileStarLayout.slotCenter(1).x - 195) * (ProfileStarLayout.slotCenter(2).x - 195) < 0)
    }

    @Test func slotFollowsTheNineOClockDay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        func at(_ dayOffset: Int, _ h: Int) -> Date {
            calendar.date(byAdding: .hour, value: dayOffset * 24 + h, to: today)!
        }
        let now = at(0, 15)
        #expect(ProfileStarLayout.slot(for: at(0, 10), now: now) == 0)
        #expect(ProfileStarLayout.slot(for: at(-1, 20), now: now) == 1)
        #expect(ProfileStarLayout.slot(for: at(-6, 12), now: now) == 6)
        #expect(ProfileStarLayout.slot(for: at(-7, 12), now: now) == nil)
        // 翌朝 8:00 は、まだ前の日の「今日」
        #expect(ProfileStarLayout.slot(for: at(0, 18), now: at(1, 8)) == 0)
        #expect(ProfileStarLayout.slot(for: at(0, 18), now: at(1, 9)) == 1)
    }

    // MARK: 点の輪(ウィジェットの円盤と同じ進み)

    @Test func ringMatchesTheWidget() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let shot = calendar.date(bySettingHour: 18, minute: 11, second: 0, of: today)!
        let now = calendar.date(bySettingHour: 23, minute: 40, second: 0, of: today)!
        var snapshot = LaterWidgetSnapshot.empty
        snapshot.lastShotAt = shot
        snapshot.dayKey = LaterWidgetDay.key(for: now)
        let widget = LaterWidgetState.derive(snapshot, now: now)
        let progress = ProfileStarLayout.developProgress(shotAt: shot, now: now)
        #expect(abs(progress - widget.developProgress) < 0.0001)
        #expect(ProfileStarLayout.developPercent(progress) == widget.developPercent)

        #expect(ProfileStarLayout.litCount(progress: 0) == 0)
        #expect(ProfileStarLayout.litCount(progress: 0.5) == 18)
        #expect(ProfileStarLayout.litCount(progress: 1) == 36)
        #expect(ProfileStarLayout.litCount(progress: 1.4) == 36)
    }

    // MARK: タグの軌道・視差

    @Test func tagsOrbitAndHideBehind() {
        let start = ProfileStarLayout.tagOrbit(index: 0, count: 3, elapsed: 0)
        #expect(abs(start.depth - 1) < 0.0001) // 最初は手前
        let half = ProfileStarLayout.tagOrbit(index: 0, count: 3, elapsed: 45)
        #expect(half.depth < 0.0001) // 45秒で奥へ
        let full = ProfileStarLayout.tagOrbit(index: 0, count: 3, elapsed: 90)
        #expect(abs(full.offset.x - start.offset.x) < 0.001 && abs(full.offset.y - start.offset.y) < 0.001)
        // 軌道の大きさ(横150・縦44を −9° 傾けた範囲)におさまる
        for t in stride(from: 0.0, to: 90, by: 3) {
            let o = ProfileStarLayout.tagOrbit(index: 1, count: 3, elapsed: t).offset
            #expect(abs(o.x) <= 151 && abs(o.y) <= 44 + 150 * sin(9 * .pi / 180) + 1)
        }
    }

    @Test func parallaxIsCapped() {
        #expect(ProfileStarLayout.parallax(k: 22, tilt: 1) == 14)
        #expect(ProfileStarLayout.parallax(k: 22, tilt: -3) == -14)
        #expect(ProfileStarLayout.parallax(k: 3, tilt: 1) < ProfileStarLayout.parallax(k: 10, tilt: 1))
        #expect(ProfileStarLayout.parallax(k: 10, tilt: 0) == 0)
    }

    @Test func spokenLabels() {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 18))!
        let point = WeekDayPoint(id: "2026-10-15", date: date, opened: true, color: .orange, locationName: nil, tags: [], showsPhoto: true, remainingDays: 6)
        #expect(ProfileImmersiveView.spokenLabel(for: ProfileStarDay(slot: 2, point: point, color: .orange, date: date)) == "10月15日の写真。あと6日で消えます。ダブルタップでひらく")
        #expect(ProfileImmersiveView.spokenLabel(for: ProfileStarDay(slot: 0, point: nil, color: .white, date: date)).contains("9:00"))
    }

    // MARK: 見た目(シートの①〜⑤ と、日数 1・3・7)

    enum Case: String, CaseIterable {
        case developing = "1_developing"
        case touched = "2_touched"
        case beforeShot = "3_before"
        case firstDay = "4_firstday"
        case reduced = "5_reduced"
        case threeDays = "6_three"
    }

    static func input(_ c: Case, now: Date) -> ProfileStarInput {
        let calendar = Calendar.current
        let colors: [Color] = [
            Color(red: 0.95, green: 0.55, blue: 0.35), Color(red: 0.4, green: 0.6, blue: 0.95), Color(red: 0.9, green: 0.4, blue: 0.6),
            Color(red: 0.5, green: 0.85, blue: 0.6), Color(red: 0.95, green: 0.8, blue: 0.4), Color(red: 0.6, green: 0.5, blue: 0.95),
        ]
        func day(_ slot: Int) -> ProfileStarDay {
            let date = calendar.date(byAdding: .day, value: -slot, to: now)!
            let point = WeekDayPoint(id: "d\(slot)", date: date, opened: slot > 0, color: slot > 0 ? colors[slot - 1] : nil, locationName: nil, tags: [], showsPhoto: slot > 0, remainingDays: 7 - slot)
            return ProfileStarDay(slot: slot, point: point, color: slot > 0 ? colors[slot - 1] : .white, date: date)
        }
        let shot = calendar.date(byAdding: .hour, value: -5, to: now)!
        var input = ProfileStarInput(tags: ["夕焼け", "散歩", "コーヒー"], now: now)
        input.planetColor = Color(red: 0.95, green: 0.6, blue: 0.4)
        input.image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200)).image { ctx in
            let colors = [UIColor(red: 0.98, green: 0.7, blue: 0.45, alpha: 1).cgColor, UIColor(red: 0.3, green: 0.25, blue: 0.5, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 200, y: 200), options: [])
            UIColor.white.withAlphaComponent(0.6).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 120, y: 40, width: 40, height: 40))
        }
        switch c {
        case .developing, .touched:
            input.days = [0, 1, 2, 4, 5, 6].map(day) // 3日前は撮らなかった
            input.todayShotAt = shot
            if c == .touched { input.selectedSlot = 2 }
        case .beforeShot:
            input.days = [1, 2, 3, 5].map(day)
        case .firstDay:
            input.days = [day(0)]
            input.todayShotAt = shot
        case .reduced:
            input.days = [0, 1, 2, 3, 4, 5, 6].map(day)
            input.todayShotAt = shot
            input.motion = .reduced
        case .threeDays:
            input.days = [0, 1, 2].map(day)
            input.todayShotAt = shot
        }
        input.auroraColors = input.days.compactMap { $0.slot > 0 ? $0.color : nil }
        return input
    }

    @Test func render() throws {
        guard let dir = HomeSnapshotTests.outputDirectory else { return }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let calendar = Calendar.current
        let now = calendar.date(bySettingHour: 23, minute: 10, second: 0, of: Date())!
        let size = CGSize(width: 390, height: 844)
        let sheet = HStack(spacing: 16) {
            ForEach(Case.allCases, id: \.self) { c in
                let input = Self.input(c, now: now)
                ZStack(alignment: .topLeading) {
                    LinearGradient(colors: [Color(red: 0.04, green: 0.05, blue: 0.12), .black], startPoint: .top, endPoint: .bottom)
                    ProfileStarFrame(input: input, time: now, tilt: ProfileStarTilt(), size: size)
                    Text("たつき").font(.system(size: 35, weight: .heavy)).foregroundStyle(.white)
                        .position(x: 195, y: ProfileStarLayout.nameY)
                    Text("LATER ・ 08.14 から").font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.white.opacity(0.58))
                        .position(x: 195, y: ProfileStarLayout.sinceY)
                    if c == .reduced {
                        HStack(spacing: 8) { ForEach(input.tags, id: \.self) { ProfileStarTag(text: $0) } }
                            .position(x: 195, y: ProfileStarLayout.tagRowY)
                    }
                    HStack {
                        Text("預けた日々").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        Spacer()
                        Text(input.todayShotAt == nil ? "今日は、まだ撮っていません" : "今日 現像 \(ProfileStarLayout.developPercent(ProfileStarLayout.developProgress(shotAt: input.todayShotAt!, now: now)))%")
                            .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.white.opacity(0.62))
                    }
                    .padding(.horizontal, 24).frame(width: 390)
                    .position(x: 195, y: ProfileStarLayout.headingY)
                    VStack(spacing: 3) {
                        Text("点を押し続けると、その日がひらく")
                        Text("写真は、撮ってから7日間だけ残ります")
                    }
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                    .frame(width: 390, height: 844, alignment: .bottom).padding(.bottom, 26)
                    if c == .touched, let day = input.days.first(where: { $0.slot == 2 }), let point = day.point {
                        WeekDayCard(point: point, thumbnail: nil)
                            .position(x: ProfileStarLayout.slotCenter(2).x + 12.5 * 1.35 + 14 + 75, y: ProfileStarLayout.slotCenter(2).y)
                    }
                }
                .frame(width: size.width, height: size.height)
                .clipped()
            }
        }
        .padding(16)
        .background(Color(white: 0.15))
        let renderer = ImageRenderer(content: sheet)
        renderer.scale = 1
        try #require(renderer.uiImage?.pngData()).write(to: dir.appendingPathComponent("profile_star.png"))
    }
}
