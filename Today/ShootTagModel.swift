import Foundation

// MARK: - タグの決まり

/// 撮影前のタグ(写真がひらいた時に添えて見える、その日のひとこと)。
enum ShootTagRules {
    static let maxTags = DailyExposureRules.maxTags
    static let maxLength = 16

    enum Rejection: Equatable {
        /// 3つまで
        case full
        /// URL・メール・電話番号らしい数字・禁止リストの言葉
        case forbidden
    }

    /// 確定のときに整える:NFKC → 「#」「＃」を除く → すべての空白(全角・半角・改行)を除く → 16文字まで。
    /// 空になったらnil(確定しない)。
    static func normalize(_ raw: String) -> String? {
        var text = raw.precomposedStringWithCompatibilityMapping
        text = text.replacingOccurrences(of: "#", with: "").replacingOccurrences(of: "＃", with: "")
        text = String(text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }.map(Character.init))
        text = String(text.prefix(maxLength))
        return text.isEmpty ? nil : text
    }

    /// 保存・重複判定用のキー(英字の大文字・小文字を区別しない)。
    static func key(_ tag: String) -> String { tag.lowercased() }

    /// 個人や連絡先につながるもの・不適切な言葉は確定させない。端末内で判定する。
    static func isForbidden(_ tag: String) -> Bool {
        let lowered = tag.lowercased()
        if lowered.contains("@") { return true }
        if lowered.contains("http") || lowered.contains("www.") { return true }
        if lowered.range(of: #"\.(com|net|org|jp|io|co|me|app|info)"#, options: .regularExpression) != nil { return true }
        if lowered.range(of: #"[0-9]{7,}"#, options: .regularExpression) != nil { return true }
        return ShootTagBlocklist.words.contains { lowered.contains($0) }
    }
}

/// 不適切な言葉の禁止リスト(最小限の仮のもの)。正式なリストができたら、ここを差し替える。
enum ShootTagBlocklist {
    static let words: [String] = [
        "死ね", "しね", "殺す", "ころす", "きもい", "キモい", "ブス", "ぶす", "デブ", "でぶ",
        "fuck", "shit", "bitch",
    ]
}

// MARK: - みんなのタグ(川①と候補の元)

/// 「いま、よく選ばれている」の出どころ。最初は運営が選んだ固定リスト(B)。
/// あとで集計(A)に差し替えられるよう、プロトコルにしておく。
protocol TagSuggestionProvider {
    /// 川①に流すタグ(件数・順位は出さない)
    func popularTags() -> [String]
    /// 入力中の文字で前方一致する候補
    func candidates(matching prefix: String) -> [String]
}

struct BundledTagSuggestionProvider: TagSuggestionProvider {
    static let popular = ["朝ごはん", "空", "散歩", "雨の日", "夕焼け", "コーヒー", "帰り道", "ひとり時間", "電車", "猫", "青", "静か"]
    static let dictionary = popular + [
        "雨上がり", "雨音", "雨の匂い", "朝の光", "朝焼け", "昼休み", "夜道", "夜風", "月", "星",
        "机の上", "窓辺", "花", "緑", "海", "川", "公園", "駅", "本", "音楽", "料理", "おやつ",
        "犬", "友だち", "家族", "仕事", "勉強", "通学", "休日", "旅", "雲", "影", "光", "白", "黒",
    ]

    func popularTags() -> [String] { Self.popular }

    func candidates(matching prefix: String) -> [String] {
        let key = prefix.lowercased()
        guard !key.isEmpty else { return [] }
        return Self.dictionary.filter { $0.lowercased().hasPrefix(key) && $0.lowercased() != key }
    }
}

// MARK: - 自分のタグ(川②・候補・前回と同じ)

/// 自分が使ったタグの履歴。写真は7日で端末から削除されるため、タグだけを端末内に残す。
enum ShootTagHistory {
    private static let recentKey = "shootTagRecent"
    private static let lastKey = "shootTagLast"
    private static let recentLimit = 40

    /// 新しい順の、自分が使ったタグ
    static var recent: [String] {
        UserDefaults.standard.stringArray(forKey: recentKey) ?? []
    }

    /// タグのある直近の撮影のタグ(タグなしで撮った日は飛ばす)
    static var last: [String] {
        UserDefaults.standard.stringArray(forKey: lastKey) ?? []
    }

    static func record(_ tags: [String]) {
        guard !tags.isEmpty else { return }
        let defaults = UserDefaults.standard
        defaults.set(tags, forKey: lastKey)
        var list = recent
        for tag in tags.reversed() {
            list.removeAll { ShootTagRules.key($0) == ShootTagRules.key(tag) }
            list.insert(tag, at: 0)
        }
        defaults.set(Array(list.prefix(recentLimit)), forKey: recentKey)
    }

    static func candidates(matching prefix: String) -> [String] {
        let key = prefix.lowercased()
        guard !key.isEmpty else { return [] }
        return recent.filter { $0.lowercased().hasPrefix(key) && $0.lowercased() != key }
    }
}

// MARK: - 撮影前の下書き

/// 確定済みのチップを、同じ日のあいだだけ端末内に残す(Homeから入り直したら復元)。
/// 撮影が完了したら捨てる。失敗・キャンセルの時は残す。日付が変わったら捨てる。
enum ShootTagDraft {
    private static let tagsKey = "shootTagDraftTags"
    private static let dayKey = "shootTagDraftDay"

    static func load(now: Date = Date()) -> [String] {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: dayKey) == ExposureDayStore.dayKey(for: now) else {
            clear()
            return []
        }
        return defaults.stringArray(forKey: tagsKey) ?? []
    }

    static func save(_ tags: [String], now: Date = Date()) {
        let defaults = UserDefaults.standard
        defaults.set(tags, forKey: tagsKey)
        defaults.set(ExposureDayStore.dayKey(for: now), forKey: dayKey)
    }

    static func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: tagsKey)
        defaults.removeObject(forKey: dayKey)
    }
}

// MARK: - 触覚(この画面は「選ぶ」にあたる)

enum ShootTagHaptics {
    /// タグが確定してチップに着地した瞬間
    static let land: (intensity: Float, sharpness: Float) = (0.55, 0.65)
    /// 3つ目が着地した瞬間
    static let landFull: (intensity: Float, sharpness: Float) = (0.75, 0.7)
    /// 断られた(上限・使えない言葉):やわらかく2回、80msあけて
    static let reject: (intensity: Float, sharpness: Float) = (0.3, 0.3)
    static let rejectGap: TimeInterval = 0.08
    /// チップを外した
    static let remove: (intensity: Float, sharpness: Float) = (0.35, 0.5)
}
