import SwiftUI

/// Homeのグループの列・グループのシートが読む、1グループの要約。
/// 「だれが投稿したか」は持たない(数だけ)。
struct GroupSummary: Identifiable, Equatable {
    let id: UUID
    let name: String
    let iconData: Data?
    /// オーラの色(写真がないグループ)。列の中で同じ色が続かないように決める
    let auraIndex: Int
    /// 点の数(メンバー数)
    let memberCount: Int
    /// 光る点の数(昨日の窓に「投稿する」を選んだ人の数)
    let postedYesterday: Int
    /// 人数の上限(4〜8)
    var memberLimit: Int = GroupMembershipPolicy.maxMembersPerGroup

    var isFull: Bool { memberCount >= memberLimit }
    var openSeats: Int { max(0, memberLimit - memberCount) }
    var allPosted: Bool { memberCount > 0 && postedYesterday >= memberCount }
    var initial: String { String(name.trimmingCharacters(in: .whitespaces).prefix(1)) }
    /// 「3 / 8」
    var countText: String { "\(postedYesterday) / \(memberCount)" }
    var spokenSummary: String { "\(name)、メンバー\(memberCount)人のうち\(postedYesterday)人が昨日投稿しました" }
}

enum GroupRingMath {
    static let maxDots = 12

    /// 点の数と、光る点の数。メンバーが12人をこえたら12個に丸め、光る割合をそろえる。
    /// 1人でも投稿していれば1つは光り、全員でなければ1つは消えたまま(全員そろったと見せない)。
    static func dots(memberCount: Int, posted: Int) -> (total: Int, lit: Int) {
        let members = max(1, memberCount)
        let posted = min(max(0, posted), members)
        guard members > maxDots else { return (members, posted) }
        var lit = Int((Double(posted) / Double(members) * Double(maxDots)).rounded())
        if posted > 0 { lit = max(1, lit) }
        if posted < members { lit = min(maxDots - 1, lit) }
        return (maxDots, lit)
    }

    /// 点の角度(12時の位置から時計まわり、rad)。光っている点から先にならぶ。
    static func angle(index: Int, total: Int) -> Double {
        -Double.pi / 2 + Double(index) / Double(max(1, total)) * 2 * .pi
    }

    /// 昨日の窓に「投稿する」を選んだ人の数(同じ人がグループに複数枚あっても1人)
    static func postedYesterday(in group: LaterGroup, now: Date, calendar: Calendar = .current) -> Int {
        let window = DailyWindow.yesterday(for: now, calendar: calendar)
        var authors = Set<String>()
        for photo in group.photos where photo.isPosted && photo.captureDate >= window.open && photo.captureDate < window.close {
            authors.insert(photo.authorCloudKitUserRecordName ?? photo.owner?.id.uuidString ?? photo.dedupeKey)
        }
        return authors.count
    }

    /// オーラの色の番号。IDから決め、となりと同じ色が続かないようにずらす。
    static func auraIndices(for ids: [UUID]) -> [Int] {
        var result: [Int] = []
        for id in ids {
            let n = GroupPalette.automaticCount
            var index = stableHash(id) % n
            if let previous = result.last, previous == index { index = (index + 1) % n }
            result.append(index)
        }
        return result
    }

    static func stableHash(_ id: UUID) -> Int {
        // hashValue はプロセスごとに変わるので、UUIDのバイトから決める
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        return bytes.reduce(7) { ($0 &* 31 &+ Int($1)) & 0x7fffffff }
    }

    /// 写真がないグループのオーラ(3色)
    static let auraPalettes: [[Color]] = [
        [Color(hex: "FFB078"), Color(hex: "FF8FA0"), Color(hex: "8A6CF0")],
        [Color(hex: "6AA8FF"), Color(hex: "7BE0C8"), Color(hex: "3E5BD8")],
        [Color(hex: "FFD36E"), Color(hex: "FF9A4D"), Color(hex: "E05A7A")],
        [Color(hex: "9AE6B4"), Color(hex: "4FB3BF"), Color(hex: "2F6F9F")],
        [Color(hex: "D9A3FF"), Color(hex: "FF9ECF"), Color(hex: "6B5BD6")],
        // 6つめはグレー(自動では選ばない。「色だけ」で手で選んだときだけ)
        [Color(hex: "B8B8C0"), Color(hex: "7C7C86"), Color(hex: "3A3A42")],
    ]

    /// MEを除いた参加中のグループから、要約を作る(並び順は呼び出し側のまま。投稿数では並べない)
    static func summaries(for groups: [LaterGroup], now: Date) -> [GroupSummary] {
        let auras = auraIndices(for: groups.map(\.id))
        return zip(groups, auras).map { group, aura in
            GroupSummary(
                id: group.id,
                name: group.name,
                iconData: group.iconImageData,
                // 作成時に選んだ色があれば、それを使う
                auraIndex: GroupPalette.isValid(group.colorIndex) ? group.colorIndex : aura,
                memberCount: max(1, group.deduplicatedMemberIDs.count),
                postedYesterday: postedYesterday(in: group, now: now),
                memberLimit: GroupPalette.clampLimit(group.memberLimit)
            )
        }
    }
}

// MARK: - 色・名前・人数の上限

/// グループの色(オーラの組み合わせ)。名前から自動で決めるのは先頭5つ(グレーは選ばない)。
enum GroupPalette {
    /// 自動で選ぶ色の数(最後の1つはグレー。手で選んだときだけ)
    static let automaticCount = 5
    static var count: Int { GroupRingMath.auraPalettes.count }

    static func isValid(_ index: Int) -> Bool { (0..<count).contains(index) }

    /// 名前 → 色。同じ名前なら必ず同じ色(プロセスごとに変わる hashValue は使わない)
    static func index(forName name: String) -> Int {
        var hash: UInt32 = 2_166_136_261
        for scalar in name.unicodeScalars {
            hash = (hash ^ scalar.value) &* 16_777_619
        }
        return Int(hash % UInt32(automaticCount))
    }

    static func clampLimit(_ limit: Int) -> Int {
        min(GroupMembershipPolicy.memberLimitRange.upperBound, max(GroupMembershipPolicy.memberLimitRange.lowerBound, limit))
    }
}

enum GroupNameRules {
    static let maxLength = 12

    /// 入力中の名前を整える:改行・絵文字を取りのぞき、12文字まで(前後の空白は確定時に削る)
    static func sanitizeInput(_ input: String) -> String {
        let filtered = input.filter { character in
            !character.isNewline && !isEmoji(character)
        }
        return String(filtered.prefix(maxLength))
    }

    /// 確定した名前(前後の空白を削る)
    static func finalize(_ input: String) -> String {
        sanitizeInput(input).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func initial(of name: String) -> String {
        String(finalize(name).prefix(1))
    }

    private static func isEmoji(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            scalar.properties.isEmojiPresentation
                || (scalar.properties.isEmoji && scalar.value > 0x238C)
                || scalar.value == 0xFE0F || scalar.value == 0x200D
        }
    }
}

/// 入れるかどうか(参加の直前に、アプリで判定する。参加の直後にも人数を数えなおす)
enum JoinCheck: Equatable {
    case ok
    /// e1 満員
    case full
    /// e2 期限切れ・止められた
    case unavailable
    /// e3 すでに入っている
    case alreadyMember
    /// e4 10個まで
    case tooManyGroups

    static func evaluate(
        isAlreadyMember: Bool,
        memberCount: Int,
        memberLimit: Int,
        joinedGroupCount: Int,
        expiresAt: Date?,
        revoked: Bool,
        now: Date
    ) -> JoinCheck {
        if isAlreadyMember { return .alreadyMember }
        if revoked { return .unavailable }
        if let expiresAt, expiresAt <= now { return .unavailable }
        if memberCount >= GroupPalette.clampLimit(memberLimit) { return .full }
        if joinedGroupCount >= GroupMembershipPolicy.maxGroupsPerUser { return .tooManyGroups }
        return .ok
    }

    /// 参加の直後:上限をこえていたら、あとから入った自分が抜ける
    static func isOverCapacity(acceptedCount: Int, memberLimit: Int) -> Bool {
        acceptedCount > GroupPalette.clampLimit(memberLimit)
    }
}
