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

/// タグの候補の出どころ(川①は「気持ちのヒント」= EmotionHintSet に置きかえた。ここは入力中の候補)。
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

    /// 辞書から出す候補は、感情の言葉を先に並べる(前方一致が先、は変えない)
    func candidates(matching prefix: String) -> [String] {
        let key = prefix.lowercased()
        guard !key.isEmpty else { return [] }
        let emotions = EmotionHintCatalog.allEmotions
        let words = emotions + (EmotionHintCatalog.everyday + Self.dictionary).filter { !emotions.contains($0) }
        var seen = Set<String>()
        return words.filter { $0.lowercased().hasPrefix(key) && $0.lowercased() != key && seen.insert($0).inserted }
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

// MARK: - 気持ちのヒント(川①・うすい例)

/// 撮影前のタグの「気持ちのヒント」の辞書。差し替えやすいよう、ここに分けて持つ(アプリに同梱)。
/// 言葉の追加は、必ず人が見て決める(自動生成・ユーザー投稿は混ぜない)。1つ16文字以内、数字・記号・「#」なし。
/// ポジティブだけにしない(気持ちに、よい・わるいの評価をつけない)。
enum EmotionHintCatalog {
    enum Group: CaseIterable {
        case bright, calm, lonely, restless, mixed
    }

    static let emotions: [Group: [String]] = [
        .bright: ["うれしい", "わくわく", "たのしい", "ごきげん", "はしゃいだ", "誇らしい", "胸があつい", "ときめき",
                  "笑った", "満たされた", "晴れやか", "やったー", "にやにや", "ひらめき"],
        .calm: ["おだやか", "ほっとした", "しあわせ", "ぬくもり", "やすらぎ", "のんびり", "しみじみ", "ありがたい",
                "なごんだ", "落ち着く", "すがすがしい", "ゆるんだ", "ひと息", "満ち足りた"],
        .lonely: ["さみしい", "せつない", "なつかしい", "ぼんやり", "しょんぼり", "心細い", "恋しい", "名残惜しい",
                  "ゆううつ", "物思い", "遠い気持ち", "もの足りない", "しんみり", "ひとりきり"],
        .restless: ["もやもや", "ざわざわ", "そわそわ", "いらいら", "あせり", "不安", "緊張", "じれったい",
                    "悔しい", "気まずい", "むかむか", "どきどき", "落ち着かない", "びくびく"],
        .mixed: ["複雑", "ふしぎ", "余韻", "しんと", "無心", "感慨深い", "愛おしい", "照れくさい",
                 "くすぐったい", "いつも通り", "眠い", "つかれた", "だるい", "放心"],
    ]

    /// ふだんのことば(場面・物)
    static let everyday = ["雨の日", "帰り道", "机の上", "朝ごはん", "夕焼け", "コーヒー", "散歩", "電車", "猫", "空", "青", "手元",
                           "ひとり時間", "夜ふかし", "窓辺", "おやつ", "夕ごはん", "教室", "ベランダ", "自転車", "風",
                           "お風呂あがり", "休み時間", "部屋の隅"]

    /// 時間帯のかたより(端末の時刻だけを使う。位置・天気・曜日は使わない)
    static func timeOfDayWords(hour: Int) -> [String] {
        switch hour {
        case 9...11: return ["すがすがしい", "眠い", "わくわく", "ひらめき", "のんびり"]
        case 18...23: return ["しみじみ", "つかれた", "ほっとした", "なつかしい", "ゆるんだ", "ひと息"]
        default: return []
        }
    }

    static var allEmotions: [String] { Group.allCases.flatMap { emotions[$0] ?? [] } }

    static func isEmotion(_ word: String) -> Bool { allEmotions.contains(word) }
}

/// 1回ぶんの「気持ちのヒント」:川①の10個(感情8・ふだん2)と、うすい例の5つ(感情4・ふだん1)
struct EmotionHintSet: Equatable {
    let river: [String]
    let examples: [String]

    /// 1回ぶんを作る。除外 = 直近3回に出した言葉 ∪ 自分の前回のタグ(川②に出るぶん)。
    /// 言葉が足りなくなったら、古い回から順に除外をゆるめる(画面を空にしない)。
    static func make<R: RandomNumberGenerator>(
        history: [[String]],
        ownTags: [String],
        hour: Int,
        using rng: inout R
    ) -> EmotionHintSet {
        let own = Set(ownTags.map(ShootTagRules.key))
        // 新しい回から順に除外し、足りなければ古い回から外していく
        for keep in stride(from: history.count, through: 0, by: -1) {
            let excluded = Set(history.prefix(keep).flatMap { $0 }.map(ShootTagRules.key)).union(own)
            if let set = build(excluded: excluded, hour: hour, using: &rng) { return set }
        }
        // それでも足りない(辞書がとても少ない):自分のタグの除外もゆるめる
        return build(excluded: [], hour: hour, using: &rng, allowShort: true)!
    }

    private static func build<R: RandomNumberGenerator>(
        excluded: Set<String>,
        hour: Int,
        using rng: inout R,
        allowShort: Bool = false
    ) -> EmotionHintSet? {
        var used = excluded
        func available(_ words: [String]) -> [String] {
            words.filter { !used.contains(ShootTagRules.key($0)) }
        }
        func take(_ word: String) -> String {
            used.insert(ShootTagRules.key(word))
            return word
        }
        typealias C = EmotionHintCatalog
        let fourGroups: [C.Group] = [.bright, .calm, .lonely, .restless]

        /// 感情 n 個(4グループから1つずつ → 時間帯 → のこり)+ ふだん m 個
        func pick(emotions n: Int, everyday m: Int, timeBias: Bool) -> (emotions: [String], everyday: [String])? {
            var emotions: [String] = []
            for group in fourGroups where emotions.count < n {
                guard let word = available(C.emotions[group] ?? []).randomElement(using: &rng) else {
                    if allowShort { continue } else { return nil }
                }
                emotions.append(take(word))
            }
            if timeBias, emotions.count < n, Double.random(in: 0..<1, using: &rng) < 0.6,
               let word = available(C.timeOfDayWords(hour: hour)).randomElement(using: &rng) {
                emotions.append(take(word))
            }
            var rest = available(C.allEmotions).shuffled(using: &rng)
            while emotions.count < n, let word = rest.popLast() {
                emotions.append(take(word))
            }
            var everyday: [String] = []
            var days = available(C.everyday).shuffled(using: &rng)
            while everyday.count < m, let word = days.popLast() {
                everyday.append(take(word))
            }
            guard allowShort || (emotions.count == n && everyday.count == m) else { return nil }
            return (emotions, everyday)
        }

        guard let river = pick(emotions: 8, everyday: 2, timeBias: true) else { return nil }
        // うすい例:川①と重ならない言葉で、感情4+ふだん1。先頭は必ず感情、のこりはシャッフル
        guard let example = pick(emotions: 4, everyday: 1, timeBias: false) else { return nil }
        var tail = Array(example.emotions.dropFirst()) + example.everyday
        tail.shuffle(using: &rng)
        let examples = Array(example.emotions.prefix(1)) + tail
        let riverWords = (river.emotions + river.everyday).shuffled(using: &rng)
        guard !riverWords.isEmpty, !examples.isEmpty else { return nil }
        return EmotionHintSet(river: riverWords, examples: examples)
    }
}

/// 直近3回に出した言葉(川①の10個+うすい例の5つを1回ぶんとして、3回ぶん)。端末の中だけに保存し、サーバーには送らない。
enum EmotionHintHistory {
    private static let key = "emotionHintHistory"
    static let rounds = 3

    static func load(defaults: UserDefaults = .standard) -> [[String]] {
        (defaults.array(forKey: key) as? [[String]]) ?? []
    }

    /// 新しい回を先頭に入れて、3回ぶんだけ残す
    static func record(_ set: EmotionHintSet, defaults: UserDefaults = .standard) {
        var list = load(defaults: defaults)
        list.insert(set.river + set.examples, at: 0)
        defaults.set(Array(list.prefix(rounds)), forKey: key)
    }

    /// 画面をひらいたとき・「ほかの言葉」を押したときに、1回ぶん作って履歴に入れる
    static func next(ownTags: [String], now: Date = Date(), defaults: UserDefaults = .standard) -> EmotionHintSet {
        var rng = SystemRandomNumberGenerator()
        let set = EmotionHintSet.make(
            history: load(defaults: defaults),
            ownTags: ownTags,
            hour: Calendar.current.component(.hour, from: now),
            using: &rng
        )
        record(set, defaults: defaults)
        return set
    }
}
