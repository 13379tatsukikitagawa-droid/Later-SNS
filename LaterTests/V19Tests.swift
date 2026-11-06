import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// v19 ME と Mondo の決めごと
@MainActor
struct V19Tests {
    private func entry(_ id: String, _ code: String, _ region: String?, tags: [String] = []) -> MondoEntry {
        MondoEntry(id: id, mondoID: "m\(id)", name: "x", place: MondoPlace(countryCode: code, countryName: code == "JP" ? "日本" : "Portugal", region: region),
                   tags: tags, dayKey: "2026-11-04", toneHex: nil, isMine: false)
    }

    @Test func 陸と海の点が見本から読める() {
        #expect(MondoGeo.land.count == 2553)
        #expect(MondoGeo.ocean.count == 1854)
        #expect(MondoGeo.land.allSatisfy { abs($0.lat) <= 90 && abs($0.lon) <= 180 })
    }

    @Test func 光は都道府県と州ごとにまとまり多い順() {
        let lights = MondoGeo.lights(from: [
            entry("1", "JP", "東京都", tags: ["朝", "電車"]), entry("2", "JP", "東京都", tags: ["朝"]), entry("3", "JP", "Tokyo"),
            entry("4", "PT", "Lisboa"), entry("5", "JP", nil),
        ])
        #expect(lights.first?.name == "東京都")
        #expect(lights.first?.count == 2)
        #expect(lights.first?.tags.first == "朝")
        #expect(lights.first?.latinName == "TOKYO")
        // 「Tokyo」(英語の端末)も、同じ場所に置く
        let tokyo = lights.first { $0.id == "JP|Tokyo" }
        #expect(tokyo?.point == lights.first?.point)
        // 表にない州は、国の中心から少しずらす(毎回同じ)
        let lisboa = lights.first { $0.id == "PT|Lisboa" }
        #expect(lisboa != nil)
        #expect(MondoGeo.point(countryCode: "PT", region: "Lisboa") == MondoGeo.point(countryCode: "PT", region: "Lisboa"))
        // 国だけ:国の中心
        #expect(lights.first { $0.id == "JP|" }?.name == "日本")
        // 知らない国は出さない
        #expect(MondoGeo.lights(from: [entry("9", "ZZ", nil)]).isEmpty)
    }

    @Test func となりへは経度で東へ() {
        let lights = MondoGeo.lights(from: [entry("1", "JP", "東京都"), entry("2", "PT", nil), entry("3", "US", "New York")])
        let ny = lights.first { $0.id == "US|New York" }!
        #expect(MondoGeo.next(after: ny, in: lights)?.countryCode == "PT")
        let tokyo = lights.first { $0.countryCode == "JP" }!
        #expect(MondoGeo.next(after: tokyo, in: lights)?.countryCode == "US")
    }

    @Test func 地球儀の数字() {
        #expect(GlobeRules.jumpDuration(distance: 0) == 0.7)
        #expect(GlobeRules.jumpDuration(distance: 400) == 1.5)
        #expect(abs(GlobeRules.jumpZoomAt(1, from: 1) - 2.6) < 0.0001)
        var view = GlobeView2D(lon: 170, lat: 0, zoom: 1)
        view.turn(dLon: 20, dLat: 100)
        #expect(abs(view.lon - -170) < 0.0001)
        #expect(view.lat == 70)
        // まん中の点は、真ん中・手前
        let p = GlobeView2D(lon: 139.7, lat: 35.7).project(GeoPoint(lat: 35.7, lon: 139.7), radius: 100)
        #expect(abs(p.x) < 0.001 && abs(p.y) < 0.001 && abs(p.v - 1) < 0.001)
        #expect(MondoGeo.normalize("東京都") == MondoGeo.normalize("東京"))
    }

    @Test func MEの日めくりのことば() {
        let cal = Calendar.current
        let day = MEDay(key: "k", date: Date(), ago: 6, shots: [], tags: [], developed: true)
        #expect(day.daysLeft == 1)
        #expect(MERules.lifeText(day) == "あした きえる")
        #expect(MERules.lifeText(MEDay(key: "k", date: Date(), ago: 0, shots: [], tags: [], developed: false)) == "9:00 に ひらく")
        #expect(MERules.lifeText(MEDay(key: "k", date: Date(), ago: 2, shots: [], tags: [], developed: true)) == "あと 5日")
        #expect(MERules.label(ago: 1, date: Date(), calendar: cal) == "きのう")
        #expect(MERules.lightLeak(ago: 4) == 0)
        #expect(MERules.lightLeak(ago: 5) > 0)
        #expect(abs(MERules.sepia(ago: 2) - 0.15) < 0.0001)
        #expect(MERules.fan(count: 3, index: 2).x == 48)
    }

    @Test func えらぶは1日1枚で移る() {
        let saved = MEPickStore.picks
        defer { MEPickStore.picks = saved }
        MEPickStore.picks = [:]
        MEPickStore.set(day: "2026-11-04", shotID: "a", imageData: nil)
        MEPickStore.set(day: "2026-11-04", shotID: "b", imageData: nil)
        #expect(MEPickStore.pick(day: "2026-11-04") == "b")
        #expect(MEPickStore.picks.count == 1)
        MEPickStore.set(day: "2024-01-01", shotID: "old", imageData: nil)
        MEPickStore.prune(now: Date())
        #expect(MEPickStore.pick(day: "2024-01-01") == nil)
    }

    @Test func MEは同じ1枚をまとめて3枚まで() throws {
        let profile = UserProfile(name: "a", username: "")
        let cal = Calendar.current
        let now = cal.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.date(bySettingHour: 10, minute: 0, second: 0, of: now)!)!
        var photos: [LaterPhoto] = []
        for i in 0..<4 {
            let t = yesterday.addingTimeInterval(Double(i) * 3600)
            // 同じ1枚がグループ2つぶん
            for _ in 0..<2 {
                let p = LaterPhoto(imageData: Data(), captureDate: t, unlockDate: t, owner: profile)
                p.tags = ["空"]
                photos.append(p)
            }
        }
        let days = MERules.days(photos: photos, now: now)
        #expect(days.count == 7)
        #expect(days[1].shots.count == 3)
        #expect(days[1].developed)
        #expect(days[0].shots.isEmpty)
    }
}

/// 見た目の確認用(LATER_SNAPSHOT_DIR がある時だけ)
@MainActor
struct V19SnapshotTests {
    private func sampleJPEG(_ hue: CGFloat) -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { ctx in
            UIColor(hue: hue, saturation: 0.6, brightness: 0.9, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
            UIColor(hue: hue + 0.3, saturation: 0.7, brightness: 0.4, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 260, width: 300, height: 140))
        }.jpegData(compressionQuality: 0.8)!
    }

    private func shoot<V: View>(_ view: V, name: String, dir: URL, wait: Double = 1.5) async throws {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        try await Task.sleep(for: .seconds(wait))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        try image.pngData()?.write(to: dir.appendingPathComponent("\(name).png"))
        window.isHidden = true
    }

    @Test func v19のスナップショット() async throws {
        guard let path = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"] else { return }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // ME
        let schema = Schema([LaterPhoto.self, LaterGroup.self, UserProfile.self, PhotoVote.self, BlockedUser.self, ExposureDay.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let profile = UserProfile(name: "あおぞら", username: "")
        context.insert(profile)
        UserDefaults.standard.set(profile.id.uuidString, forKey: "currentProfileID")
        let cal = Calendar.current
        let today = cal.startOfDay(for: DailyWindow.latest(for: Date()).open)
        for offset in [0, 1, 3, 4, 5, 6, 9, 12, 20] {
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let count = [2, 3, 0, 1, 2, 3, 1][min(offset, 6)]
            for i in 0..<max(1, count) where !(offset == 2) {
                let t = min(cal.date(bySettingHour: 10 + i * 3, minute: 12, second: 0, of: day)!, Date())
                let photo = LaterPhoto(imageData: sampleJPEG(CGFloat((offset + i) % 10) / 10), captureDate: t, unlockDate: t, owner: profile)
                photo.tags = [["雨の日", "夕焼け", "カフェ", "海"][offset % 4], "帰り道"]
                context.insert(photo)
                if i == 0 {
                    let exposure = ExposureDay(dayKey: ExposureDayStore.dayKey(for: t), captureDate: t)
                    exposure.colorHex = ["FFB48A", "9A6CF0", "6AA8FF", "7BE0C8", "FFD0A0"][offset % 5]
                    context.insert(exposure)
                }
            }
        }
        try context.save()
        let saved = MEPickStore.picks
        MEPickStore.picks = [ExposureDayStore.dayKey(for: cal.date(byAdding: .day, value: -1, to: today)!): "x"]
        defer { MEPickStore.picks = saved }
        try await shoot(MEScreenV19(onBack: {}, onShoot: {}).modelContainer(container), name: "v19-me", dir: dir)

        // Mondo の地球儀と、場所のカード
        let entries = (0..<40).map { i in
            MondoEntry(id: "e\(i)", mondoID: "m\(i)", name: "x",
                       place: [MondoPlace(countryCode: "JP", countryName: "日本", region: "東京都"), MondoPlace(countryCode: "US", countryName: "United States", region: "New York"),
                               MondoPlace(countryCode: "PT", countryName: "Portugal", region: "Lisboa"), MondoPlace(countryCode: "FR", countryName: "France", region: "Île-de-France"),
                               MondoPlace(countryCode: "KR", countryName: "대한민국", region: "서울특별시")][i % 5],
                       tags: [["朝", "電車"], ["夕焼け"], ["坂道", "海"], ["帰り道"], ["カフェ"]][i % 5], dayKey: "2026-11-04", toneHex: ["F7B38A", "6C5BA8", "C9E1D2", "E6709A", "FFC27A"][i % 5], isMine: false)
        }
        let globe = GlobeController()
        globe.lights = MondoGeo.lights(from: entries)
        globe.view = GlobeView2D(lon: 100, lat: 30, zoom: 1)
        let globeView = ZStack(alignment: .top) {
            Color(hex: "050506").ignoresSafeArea()
            VStack(spacing: 20) {
                Color.clear.frame(height: 80)
                GlobeCanvasV19(controller: globe, radius: 120).frame(width: 402, height: 300)
                MondoPlaceChips(controller: globe).frame(height: 44)
                Spacer()
            }
        }
        try await shoot(globeView, name: "v19-globe", dir: dir)
        let zoomed = GlobeController()
        zoomed.lights = globe.lights
        zoomed.view = GlobeView2D(lon: -9.1, lat: 38.7, zoom: 2.6)
        let light = globe.lights.first { $0.countryCode == "PT" }!
        let cardView = ZStack(alignment: .bottom) {
            Color(hex: "050506").ignoresSafeArea()
            GlobeCanvasV19(controller: zoomed, radius: 120).frame(width: 402, height: 874).frame(maxHeight: .infinity, alignment: .top).offset(y: -140)
            VStack(spacing: 12) {
                MondoPlaceCard(light: light, entries: entries.filter { light.entryIDs.contains($0.id) }, locked: true, onClose: {}, onNext: {}, onOpenPhoto: { _, _ in }, onToast: { _ in })
            }
            .padding(.horizontal, 12).padding(.bottom, 14)
        }
        try await shoot(cardView, name: "v19-card-locked", dir: dir)
    }
}
