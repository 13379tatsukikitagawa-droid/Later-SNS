import CoreLocation
import Foundation
import ImageIO
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - 設定値

/// Mondo(世界の「昨日」)の決めごと。あとから変えやすいよう、数値と外部の値はここに集める。
enum MondoConfig {
    /// 公開レコード(Public DB)の種類
    static let photoRecordType = "MondoPhoto"
    /// サーバ(server/mondo-worker)が作る、その日の Mondo(承認した写真の一覧と集計)
    static let dayRecordType = "MondoDay"

    /// 公開の初期値(仮決め:オフ。自分で選んだ人だけ出す)
    static let publicByDefault = false
    /// 「すべての昨日」の最大枚数(無限に追加読み込みしない)
    static let maxCards = 30
    /// ことばの群れの最大数
    static let maxBubbles = 6
    /// ことばごとの列(上位3つ)と、その横スクロールの枚数
    static let tagRows = 3
    static let tilesPerRow = 5
    /// 公開から削除までの時間(上限は7日。短いほど安全)
    static let retention: TimeInterval = 48 * 3600
    /// 公開する画像の長辺(Mondo 用に縮小)と、サムネイルの長辺
    static let imageMaxDimension: CGFloat = 1080
    static let thumbMaxDimension: CGFloat = 320

    /// サーバの承認(MondoDay)に載っている写真だけを出すか。
    /// true の間は、サーバ(画像審査)を置くまで、Mondo は「準備中」になる(審査していない写真を出さない)。
    /// デバッグビルドだけ、設定から「審査なしで見る(開発用)」に切りかえられる。
    static var requiresServerApproval: Bool {
        #if DEBUG
        // 「今日の窓を、昨日として読む」の間は、サーバの集計(昨日のぶんだけ)がまだないので、直接読む
        if MondoWindow.isReadingTodayAsYesterday { return false }
        return !UserDefaults.standard.bool(forKey: "mondoDebugAllowUnreviewed")
        #else
        return true
        #endif
    }

    /// 端末側の SensitiveContentAnalysis を使うか。使うには、Xcode で
    /// 「Sensitive Content Analysis」の capability を足す必要がある(第8-1章)。足すまでは false。
    static let usesSensitiveContentAnalysis = false

    /// お問い合わせ・Mondo のルールのリンク先(文面は別途用意。ここを差しかえる)
    static let contactEmail = "support@example.com"
    static let rulesURL = URL(string: "https://example.com/later/mondo-rules")!
}

// MARK: - Mondo 用の ID・名前

/// Mondo 専用の ID(iCloud の識別子は出さない)。ブロック・取り下げ・1日1枚のレコード名に使う。
/// 名前はプロフィールの名前を、そのまま出す(ユーザーの決定)。
enum MondoIdentity {
    private static let key = "mondoID"

    static var id: String {
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let new = UUID().uuidString.lowercased()
        UserDefaults.standard.set(new, forKey: key)
        return new
    }

    /// アイコン(ペルソナ)の種
    static func seed(for mondoID: String) -> UUID {
        UUID(uuidString: mondoID) ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    }

    /// 1日1枚のレコード名(同じ日に撮りなおしはないが、上書きで1枚にする)
    static func recordName(mondoID: String, dayKey: String) -> String {
        "mondo_\(mondoID)_\(dayKey)"
    }
}

// MARK: - 国・地域

/// 国コード+地域(都道府県レベル)だけ。緯度経度・市区町村は持たない。
struct MondoPlace: Equatable, Codable, Sendable {
    let countryCode: String
    let countryName: String
    let region: String?

    /// 「日本 ・ 東京都」「Italia ・ Lazio」
    var label: String {
        [countryName, region].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ・ ")
    }

    /// 端末側の逆ジオコードの結果から作る(元の座標は送らない)
    init?(placemark: CLPlacemark) {
        guard let code = placemark.isoCountryCode else { return nil }
        countryCode = code
        countryName = placemark.country ?? Locale.current.localizedString(forRegionCode: code) ?? code
        region = placemark.administrativeArea
    }

    init(countryCode: String, countryName: String, region: String?) {
        self.countryCode = countryCode
        self.countryName = countryName
        self.region = region
    }
}

/// 撮影時の逆ジオコードで作った、いちばん新しい国・地域(端末のメモリだけに持つ)。
@MainActor
enum MondoPlaceCache {
    static var latest: MondoPlace?
}

// MARK: - ことば

/// Mondo に出すことば。アプリの候補(suggestedTags)と、別名の辞書(server が持つ)で代表のことばにそろえる。
/// 自由入力のことばは、Mondo には出さない(グループにだけ届く)。
enum MondoTags {
    /// 端末側の最小の別名(サーバの辞書が正。ここは同じ端末内の表記ゆれをまとめるだけ)
    static let localAliases: [String: String] = [
        "coffee": "コーヒー", "珈琲": "コーヒー", "カフェ": "カフェ", "cafe": "カフェ",
        "sky": "空", "そら": "空", "breakfast": "朝ごはん", "あさごはん": "朝ごはん",
        "walk": "散歩", "さんぽ": "散歩", "work": "仕事", "night": "夜", "home": "家",
    ]

    /// 出してよいことば(候補 + 別名で候補になるもの)
    static var allowed: Set<String> { Set(DailyExposureRules.suggestedTags + ["コーヒー"]) }

    static func canonical(_ tag: String) -> String {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        return localAliases[trimmed.lowercased()] ?? localAliases[trimmed] ?? trimmed
    }

    /// 公開してよいことばだけ(最大3つ・重複なし)
    static func publishable(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags.map(canonical).filter { allowed.contains($0) && seen.insert($0).inserted }.prefix(3).map { $0 }
    }
}

// MARK: - 表示用の1枚

struct MondoEntry: Identifiable, Equatable, Sendable {
    /// Public DB のレコード名
    let id: String
    let mondoID: String
    let name: String
    let place: MondoPlace?
    let tags: [String]
    let dayKey: String
    /// 読み込み待ちの間に出す色(写真の平均色)
    let toneHex: String?
    let isMine: Bool
}

/// その日の Mondo(サーバの MondoDay か、開発用の端末側集計)
struct MondoDaySummary: Equatable, Sendable {
    let dayKey: String
    /// 表示する順(サーバ側でシャッフル済み。開発用の集計では日付シードでシャッフル)
    let entries: [MondoEntry]
    let lightCount: Int
    let countryCount: Int
    /// 昨日、多かったことば(使用数が多い順、最大6)と、その数
    let topTags: [(tag: String, count: Int)]

    static func == (a: MondoDaySummary, b: MondoDaySummary) -> Bool {
        a.dayKey == b.dayKey && a.entries == b.entries && a.lightCount == b.lightCount
    }
}

// MARK: - 集計(開発用の端末側集計と、表示のための並べかえ)

enum MondoAggregator {
    /// 「昨日の窓」のぶんだけを集計する(今日の投稿は混ぜない)。並びは日付シードのシャッフル。
    static func summarize(_ entries: [MondoEntry], dayKey: String, hidden: Set<String>, blocked: Set<String>) -> MondoDaySummary {
        let visible = entries.filter { $0.dayKey == dayKey && !hidden.contains($0.id) && !blocked.contains($0.mondoID) }
        var counts: [String: Int] = [:]
        for entry in visible { for tag in entry.tags { counts[tag, default: 0] += 1 } }
        let top = counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(MondoConfig.maxBubbles)
            .map { (tag: $0.key, count: $0.value) }
        return MondoDaySummary(
            dayKey: dayKey,
            entries: seededShuffle(visible, seed: dayKey),
            lightCount: visible.count,
            countryCount: Set(visible.compactMap { $0.place?.countryCode }).count,
            topTags: top
        )
    }

    /// 日付をシードにした固定乱数で並べかえる(同じ日は同じ並び・毎日ちがう並び)。
    static func seededShuffle<T>(_ items: [T], seed: String) -> [T] {
        var generator = SeededGenerator(seed: seed)
        return items.shuffled(using: &generator)
    }

    /// ことばの群れの並び(わざとバラバラ。ランキングに見えないように)
    static func bubbleOrder(_ tags: [(tag: String, count: Int)], dayKey: String) -> [(tag: String, count: Int)] {
        seededShuffle(tags, seed: "bubbles-" + dayKey)
    }

    /// フォントサイズ = 14 + round(その数 / 最大の数 × 10)
    static func bubbleFontSize(count: Int, maxCount: Int) -> CGFloat {
        guard maxCount > 0 else { return 14 }
        return 14 + CGFloat((Double(count) / Double(maxCount) * 10).rounded())
    }
}

/// 文字列から決まる乱数(SplitMix64)
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: String) {
        var hash: UInt64 = 1469598103934665603
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        state = hash
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - 画像(縮小・Exif を落とす)

enum MondoImageSanitizer {
    /// 長辺を maxDimension に縮小し、メタデータ(Exif・GPS・TIFF・機種)を一切持たない JPEG にする。
    static func sanitizedJPEG(from data: Data, maxDimension: CGFloat, quality: CGFloat = 0.82) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        // プロパティは画質だけ。メタデータの辞書は渡さない。
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// 画像にメタデータ(Exif・GPS・TIFF)が残っていないか(テスト・確認用)
    static func hasMetadata(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return false }
        if props[kCGImagePropertyGPSDictionary] != nil { return true }
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
           exif[kCGImagePropertyExifDateTimeOriginal] != nil || exif[kCGImagePropertyExifLensModel] != nil { return true }
        if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           tiff[kCGImagePropertyTIFFModel] != nil || tiff[kCGImagePropertyTIFFMake] != nil { return true }
        return false
    }

    /// 写真の平均色(読み込み待ちの、色のぼかし用)
    static func averageColorHex(_ data: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 8] as CFDictionary) else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return String(format: "%02X%02X%02X", pixel[0], pixel[1], pixel[2])
    }
}

// MARK: - 端末だけの記録(報告して見えなくした写真・公開した自分のレコード)

enum MondoLocalStore {
    private static let hiddenKey = "mondoHiddenRecords"
    private static let publishedKey = "mondoPublishedRecords"

    static var hidden: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: hiddenKey) ?? [])
    }

    static func hide(_ recordName: String) {
        var set = hidden
        set.insert(recordName)
        UserDefaults.standard.set(Array(set), forKey: hiddenKey)
    }

    /// 公開した自分のレコード名(取り下げ・オフで消すため)
    static var published: [String] {
        UserDefaults.standard.stringArray(forKey: publishedKey) ?? []
    }

    static func addPublished(_ recordName: String) {
        var list = published.filter { $0 != recordName }
        list.append(recordName)
        UserDefaults.standard.set(Array(list.suffix(14)), forKey: publishedKey)
    }

    static func removePublished(_ names: [String]) {
        UserDefaults.standard.set(published.filter { !names.contains($0) }, forKey: publishedKey)
    }
}

// MARK: - 入口(Home の光の球をタップ)

extension HomeState {
    enum MondoGate: Equatable {
        case enter
        case locked(title: String, message: String)
    }

    /// 判定は HomeState だけ(View ごとに時刻を見ない)。
    /// 9時の切りかわりのあとは、自分が撮っていなくても入れる(.first / .dawn も入れる)。
    /// 夜(00:00〜09:00)で直近の窓に撮らなかった .rest だけは、新しい世界がまだひらいていないので入れない。
    var mondoGate: MondoGate {
        switch self {
        case .deciding, .ready, .opened, .more, .night, .first, .dawn:
            return .enter
        case .rest:
            return .locked(title: "9時に、Mondo がひらく", message: "みんなの写真が、見られます")
        }
    }
}

// MARK: - 静かなお知らせ(Home のトーストに出す)

enum MondoNotice {
    static let name = Notification.Name("mondoNotice")

    static func post(_ text: String) {
        NotificationCenter.default.post(name: name, object: nil, userInfo: ["text": text])
    }
}

// MARK: - 窓(9:00 区切り・日本時間に固定)

/// Mondo の窓。全員で同じ窓にするため、日本時間に固定する(サーバの「今日」= UTC の日付 = 日本時間の 9:00 区切り、と同じ)。
/// 「昨日」の計算はここだけ(画面ごとに別々に計算しない)。
enum MondoWindow {
    static let timeZone = TimeZone(identifier: "Asia/Tokyo")!
    /// デバッグ:今日の窓を、昨日として読む(あしたを待たずに確かめる)
    static let debugTodayAsYesterdayKey = "mondoDebugTodayAsYesterday"

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// その時刻が属する窓の日付(9:00 開始。0:00〜8:59 は前の日の窓)
    static func dayKey(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date.addingTimeInterval(-9 * 3600))
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Mondo に出す「昨日」の窓
    static func yesterdayKey(now: Date) -> String {
        #if DEBUG
        if isReadingTodayAsYesterday { return dayKey(for: now) }
        #endif
        return dayKey(for: now.addingTimeInterval(-24 * 3600))
    }

    static var isReadingTodayAsYesterday: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: debugTodayAsYesterdayKey)
        #else
        return false
        #endif
    }
}

// MARK: - 送れなかった公開の再送

/// 送れなかった公開(通信できない・一時的な失敗)を、写真の id で覚えておく(端末の中だけ)。
/// アプリを開いたとき・投稿のあとに、もう一度送る。まだ「昨日」として見える窓のぶんだけ。
enum MondoPublishQueue {
    private static let key = "mondoPublishQueue"

    static var pending: [String] { UserDefaults.standard.stringArray(forKey: key) ?? [] }

    static func add(_ photoID: UUID) {
        var list = pending
        guard !list.contains(photoID.uuidString) else { return }
        list.append(photoID.uuidString)
        UserDefaults.standard.set(list, forKey: key)
    }

    static func remove(_ photoID: String) {
        UserDefaults.standard.set(pending.filter { $0 != photoID }, forKey: key)
    }
}

/// Mondo のログ(DEBUG のみ)。写真・位置・名前は出さない
enum MondoLog {
    static var environment: String {
        #if DEBUG
        return "Development"
        #else
        return "Production"
        #endif
    }

    static func write(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[Mondo][write] \(message())")
        #endif
    }

    static func read(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[Mondo][read] \(message())")
        #endif
    }

    static func filter(before: Int, after: Int, removedBy: String) {
        #if DEBUG
        print("[Mondo][filter] before=\(before) after=\(after) removedBy=\(removedBy)")
        #endif
    }

    static func delete(kind: String, count: Int) {
        #if DEBUG
        print("[Mondo][delete] kind=\(kind) count=\(count)")
        #endif
    }
}
