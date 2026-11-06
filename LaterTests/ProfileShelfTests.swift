import SwiftUI
import SwiftData
import Testing
@testable import Later_再度

/// プロフィール(フィルムの棚):ペルソナ名の計算・31コマ・画像の書き出し(LATER_SNAPSHOT_DIR が設定されている時だけ)。
/// 画像の書き出しは、同時に何枚も描くと SwiftData の通知が別の入れ物に届いて落ちるので、1つずつ順に流す。
@MainActor
@Suite(.serialized)
struct ProfileShelfTests {
    /// 描いた画面の @Query が、入れ物より先に消えないように持っておく
    private static var keepAlive: [ModelContainer] = []

    @Test func ペルソナ名は同じIDからいつも同じ() {
        let id = UUID(uuidString: "6F0D8C52-5B3B-4C2E-9D1A-0B7E3B6C9A11")!
        let first = ProfilePersonaName.name(for: id)
        #expect(first == ProfilePersonaName.name(for: id))
        #expect(first.contains(" #"))
        // FNV-1a の既知の値(固定の計算であること)
        #expect(ProfilePersonaName.fnv1a("") == 0xcbf2_9ce4_8422_2325)
        #expect(ProfilePersonaName.fnv1a("a") == 0xaf63_dc4c_8601_ec8c)
    }

    @Test func 今日から過去31日のコマ() {
        let now = Date()
        let days = ProfileShelfDay.make(now: now)
        #expect(days.count == 31)
        #expect(days.first?.isToday == true)
        #expect(days[6].isGone == false)
        #expect(days[7].isGone == true)
        #expect(days[0].label == "今日")
        #expect(days[3].label == "あと4日")
        #expect(days[10].label == "消えました")
    }

    // MARK: 編集のきまり

    @Test func タグは井桁と空白を除いて16文字まで() {
        #expect(ProfileShelfEditRules.cleanTag("#雨の日") == "雨の日")
        #expect(ProfileShelfEditRules.cleanTag("＃ 帰り 道　") == "帰り道")
        #expect(ProfileShelfEditRules.cleanTag("##") == "")
        // 文字は切らない(長すぎるときは、ボタンで知らせる)
        #expect(ProfileShelfEditRules.cleanTag("あいうえおかきくけこさしすせそたちつ").count == 18)
        #expect(ProfileShelfEditRules.add("あいうえおかきくけこさしすせそたちつ", to: []) == .tooLong(2))
        #expect(ProfileShelfEditRules.addButton(input: "あいうえおかきくけこさしすせそたちつ", tags: []).title == "2文字へらす")
        let full = ProfileShelfEditRules.addButton(input: "雨", tags: ["a", "b", "c"])
        #expect(full.title == "3つまで" && !full.enabled)
        let empty = ProfileShelfEditRules.addButton(input: "", tags: [])
        #expect(empty.title == "追加" && !empty.enabled)
        let ok = ProfileShelfEditRules.addButton(input: "#雨", tags: [])
        #expect(ok.title == "追加" && ok.enabled)
        #expect(ProfileShelfEditRules.cleanTag("a\nb\tc") == "abc")
    }

    @Test func タグは3つまで_同じ言葉と空は断る() {
        #expect(ProfileShelfEditRules.add("#青", to: []) == .added(["青"]))
        #expect(ProfileShelfEditRules.add("  ", to: ["青"]) == .empty)
        #expect(ProfileShelfEditRules.add("# 青", to: ["青"]) == .duplicate)
        #expect(ProfileShelfEditRules.add("Rain", to: ["rain"]) == .duplicate)
        #expect(ProfileShelfEditRules.add("静か", to: ["a", "b", "c"]) == .full)
        #expect(ProfileShelfEditRules.AddResult.full.message == "3つまでです")
        #expect(ProfileShelfEditRules.maxTags == 3)
    }

    @Test func 名前は12文字まで_空ならゲスト() {
        #expect(ProfileShelfEditRules.clampName("あいうえおかきくけこさしすせ").count == 12)
        #expect(ProfileShelfEditRules.savedName("   ") == .ok("ゲスト"))
        #expect(ProfileShelfEditRules.savedName("") == .ok("ゲスト"))
        #expect(ProfileShelfEditRules.savedName("  そら ") == .ok("そら"))
        #expect(ProfileShelfEditRules.savedName("a@b.jp") == .looksLikeContact)
    }

    @Test func タグを全部外して保存したら前のタグを残す() {
        #expect(ProfileShelfEditRules.savedTags(draft: [], previous: ["青"]) == ["青"])
        #expect(ProfileShelfEditRules.savedTags(draft: ["a", "b"], previous: ["青"]) == ["a", "b"])
    }

    @Test func シートの色は表どおり() {
        let day = ProfileSheetColors(palette: .day)
        let night = ProfileSheetColors(palette: .night)
        #expect(day.night == false)
        #expect(night.night == true)
    }

    // MARK: 画像の書き出し

    private func sampleJPEG(_ hue: CGFloat) -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { context in
            let colors = [UIColor(hue: hue, saturation: 0.45, brightness: 1, alpha: 1).cgColor,
                          UIColor(hue: hue + 0.12, saturation: 0.7, brightness: 0.55, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 300, y: 400), options: [])
        }
        return image.jpegData(compressionQuality: 0.8)!
    }

    private func makeContainer(todayTaken: Bool) throws -> ModelContainer {
        let schema = Schema([LaterPhoto.self, LaterGroup.self, UserProfile.self, PhotoVote.self, BlockedUser.self, ExposureDay.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let profile = UserProfile(name: "あおぞら", username: "")
        profile.selfTags = ["雨の日", "帰り道", "ひとり時間"]
        context.insert(profile)
        UserDefaults.standard.set(profile.id.uuidString, forKey: "currentProfileID")
        let group = LaterGroup(name: "よいしょー")
        context.insert(group)
        group.members.append(profile)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let offsets = todayTaken ? [0, 1, 2, 3, 5, 6, 9, 12] : [1, 2, 3, 5, 6, 9, 12]
        for offset in offsets {
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let captured = min(calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day)!, Date())
            let exposure = ExposureDay(dayKey: ExposureDayStore.dayKey(for: captured), captureDate: captured)
            exposure.colorHex = ["FFB48A", "9A6CF0", "6AA8FF", "7BE0C8", "FFD0A0"][offset % 5]
            exposure.thumbnailData = sampleJPEG(CGFloat(offset % 10) / 10)
            context.insert(exposure)
            let photo = LaterPhoto(imageData: sampleJPEG(CGFloat(offset % 10) / 10), captureDate: captured, unlockDate: captured, owner: profile)
            photo.groupID = group.id
            photo.tags = [["雨の日", "帰り道", "夕焼け", "朝ごはん"][offset % 4], "散歩"]
            context.insert(photo)
        }
        try context.save()
        return container
    }

    private func render(_ name: String, todayTaken: Bool, initialOffset: Int?, height: CGFloat = 844, night: Bool = false, sheet: ProfileShelfSheet? = nil) throws {
        guard let dir = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"].map({ URL(fileURLWithPath: $0) }) else { return }
        let container = try makeContainer(todayTaken: todayTaken)
        Self.keepAlive.append(container)
        let calendar = Calendar.current
        let key = initialOffset.map { ExposureDayStore.dayKey(for: calendar.date(byAdding: .day, value: -$0, to: calendar.startOfDay(for: Date()))!) }
        let root = ProfileShelfView(initialKey: key, initialSheet: sheet)
            .modelContainer(container)
            .environment(\.colorScheme, night ? .dark : .light)
            .environment(\.palette, night ? .night : .day)
        let controller = UIHostingController(rootView: root)
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: height)
        window.backgroundColor = night ? .black : .white
        window.rootViewController = controller
        window.makeKeyAndVisible()
        // 現像のアニメ(2.6秒)が終わるまで待つ
        RunLoop.main.run(until: Date().addingTimeInterval(3.4))
        let renderer = UIGraphicsImageRenderer(size: window.bounds.size)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to: dir.appendingPathComponent("\(name).png"))
        window.isHidden = true
    }

    @Test func 画像_今日の1枚() throws { try render("profile_shelf_today", todayTaken: true, initialOffset: nil) }
    @Test func 画像_過去の日() throws { try render("profile_shelf_past", todayTaken: true, initialOffset: 3) }
    @Test func 画像_今日はまだ() throws { try render("profile_shelf_empty", todayTaken: false, initialOffset: nil) }
    @Test func 画像_小さい画面() throws { try render("profile_shelf_se", todayTaken: true, initialOffset: nil, height: 667) }
    @Test func 画像_夜の今日の1枚() throws { try render("profile_shelf_night_today", todayTaken: true, initialOffset: nil, night: true) }
    @Test func 画像_夜の今日はまだ() throws { try render("profile_shelf_night_empty", todayTaken: false, initialOffset: nil, night: true) }
    @Test func 画像_設定シート() throws { try render("profile_shelf_settings", todayTaken: true, initialOffset: nil, sheet: .settings) }
    @Test func 画像_夜の設定シート() throws { try render("profile_shelf_night_settings", todayTaken: true, initialOffset: nil, night: true, sheet: .settings) }
    @Test func 画像_編集シート() throws { try render("profile_shelf_edit", todayTaken: true, initialOffset: nil, sheet: .edit) }
    @Test func 画像_夜の編集シート() throws { try render("profile_shelf_night_edit", todayTaken: true, initialOffset: nil, night: true, sheet: .edit) }
    @Test func 画像_小さい画面の編集シート() throws { try render("profile_shelf_se_edit", todayTaken: true, initialOffset: nil, height: 667, sheet: .edit) }
}
