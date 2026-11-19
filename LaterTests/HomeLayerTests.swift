import Foundation
import SwiftData
import Testing
@testable import Later_再度

/// 今日のホームの下につづく層:状態ごとのちがい(表5)・ノック・👍・組み立て
@MainActor
struct HomeLayerTests {
    private let shot = Date()

    private var allStates: [HomeState] {
        [.first, .dawn, .deciding(shotAt: shot), .ready(shotAt: shot), .opened(shotAt: shot), .more(shotAt: shot, remaining: 1), .night, .rest]
    }

    // MARK: 表5

    @Test func 昨日のみんなは_firstで出さず_ひらいたあとだけ写真() {
        #expect(HomeLayerRules.yesterdayMode(.first) == .hidden)
        for state in [HomeState.dawn, .deciding(shotAt: shot), .ready(shotAt: shot), .night, .rest] {
            #expect(HomeLayerRules.yesterdayMode(state) == .locked)
        }
        #expect(HomeLayerRules.yesterdayMode(.opened(shotAt: shot)) == .open)
        #expect(HomeLayerRules.yesterdayMode(.more(shotAt: shot, remaining: 2)) == .open)
    }

    @Test func おわりの文() {
        #expect(HomeLayerRules.endLines(.first).title == "ここから、はじまる。")
        #expect(HomeLayerRules.endLines(.first).body == "まず、1枚。それだけで、いい。")
        for state in [HomeState.dawn, .deciding(shotAt: shot), .ready(shotAt: shot)] {
            #expect(HomeLayerRules.endLines(state).title == "ここまで。")
            #expect(HomeLayerRules.endLines(state).body == "つづきは、撮ったあとに。")
        }
        for state in [HomeState.opened(shotAt: shot), .more(shotAt: shot, remaining: 1), .night, .rest] {
            #expect(HomeLayerRules.endLines(state).title == "ここまで。")
            #expect(HomeLayerRules.endLines(state).body == "つづきは、あした 9:00。")
        }
    }

    @Test func ともだちの見出しは夜だけきのう_firstはわたしとよぶだけ() {
        for state in allStates {
            #expect(HomeLayerRules.friendsTitle(state) == (state.isNight ? "きのう" : "ともだち"))
            #expect(HomeLayerRules.showsFriends(state) == (state != .first))
        }
    }

    @Test func ロック中のことば_夜はあした9時_昼はタグ1つ() {
        #expect(HomeLayerRules.lockCaption(.night, tag: "夕焼け") == "あした 9:00")
        #expect(HomeLayerRules.lockCaption(.dawn, tag: "夕焼け") == "#夕焼け")
        #expect(HomeLayerRules.lockToast(.dawn) == "今日を撮ると、ひらく")
        for state in allStates where HomeLayerRules.yesterdayMode(state) == .locked {
            #expect(!HomeLayerRules.lockToast(state).isEmpty)
        }
    }

    @Test func 七日のフィルムの今日のこま() {
        #expect(HomeLayerRules.filmToday(state: .first, shotsToday: 0) == .empty)
        #expect(HomeLayerRules.filmToday(state: .dawn, shotsToday: 0) == .empty)
        #expect(HomeLayerRules.filmToday(state: .ready(shotAt: shot), shotsToday: 1) == .developing)
        #expect(HomeLayerRules.filmToday(state: .night, shotsToday: 1) == .developing)
        // 撮れない時間で、まだ撮っていない:「おやすみ」
        #expect(HomeLayerRules.filmToday(state: .rest, shotsToday: 0) == .rest)
    }

    @Test func 古いこまほど少しずつうすくなるが_消えない() {
        let values = (0..<7).map(HomeLayerRules.filmOpacity(ago:))
        #expect(values.first == 1)
        #expect(zip(values, values.dropFirst()).allSatisfy { $0 >= $1 })
        #expect(values.allSatisfy { $0 >= 0.4 })
        #expect(HomeLayerRules.filmDaysLeft(ago: 0) == 7)
        #expect(HomeLayerRules.filmDaysLeft(ago: 6) == 1)
    }

    @Test func ことばは撮ったあとだけひらく() {
        #expect(!HomeLayerRules.wordsUnlocked(state: .dawn, shotsToday: 0))
        #expect(!HomeLayerRules.wordsUnlocked(state: .first, shotsToday: 0))
        #expect(HomeLayerRules.wordsUnlocked(state: .ready(shotAt: shot), shotsToday: 1))
        #expect(HomeLayerRules.wordsUnlocked(state: .night, shotsToday: 1))
        #expect(!HomeLayerRules.wordsUnlocked(state: .rest, shotsToday: 0))
    }

    // MARK: ノック

    private func friend(hasShot: Bool, knockOff: Bool = false, isMe: Bool = false) -> HomeFriend {
        HomeFriend(id: "ck-a", name: "あお", avatarData: nil, seed: UUID(), hasShot: hasShot, city: nil, mosaicTiny: nil, mosaicKey: "k", tag: nil, knockOff: knockOff, isMe: isMe, groupIDs: [])
    }

    // MARK: 👍

    private func card(_ id: String, group: String, at date: Date) -> HomeYesterdayCard {
        HomeYesterdayCard(id: id, groupID: UUID(), groupRecordName: group, photoRecordName: "p-\(id)", authorName: id, mosaicTiny: nil, mosaicKey: id, tag: nil, captureDate: date, imageData: nil)
    }

    @Test func 親指は1日1つ_えらびなおせる_数はない() throws {
        let defaults = try #require(UserDefaults(suiteName: "HomeLayerTests-\(UUID().uuidString)"))
        let board = LampBoard(defaults: defaults, userIdProvider: { "me" })
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!)!
        let cards = [card("a", group: "g1", at: yesterday), card("b", group: "g2", at: yesterday), card("c", group: "g1", at: yesterday)]

        #expect(HomeThumb.chosen(in: cards, board: board) == nil)
        #expect(HomeThumb.choose(cards[0], in: cards, board: board) == .first)
        #expect(HomeThumb.chosen(in: cards, board: board) == "p-a")
        #expect(HomeThumb.choose(cards[0], in: cards, board: board) == .same)
        #expect(HomeThumb.chosen(in: cards, board: board) == "p-a")
        // ほかのグループの写真へ:前の👍は取り消される(1日に1つ)
        #expect(HomeThumb.choose(cards[1], in: cards, board: board) == .changed)
        #expect(HomeThumb.chosen(in: cards, board: board) == "p-b")
        #expect(board.lamps.count == 1)
        // 同じグループの別の写真へ
        #expect(HomeThumb.choose(cards[2], in: cards, board: board) == .changed)
        #expect(board.lamps.count == 1)
        #expect(HomeThumb.chosen(in: cards, board: board) == "p-c")
    }

    @Test func 親指は締め切りのあと押せない() throws {
        let defaults = try #require(UserDefaults(suiteName: "HomeLayerTests-\(UUID().uuidString)"))
        let board = LampBoard(defaults: defaults, userIdProvider: { "me" })
        let old = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let cards = [card("a", group: "g1", at: old)]
        #expect(HomeThumb.choose(cards[0], in: cards, board: board) == .closed)
        #expect(board.lamps.isEmpty)
    }

    // MARK: 動き

    @Test func すりガラスは130で出はじめ230で出きる() {
        #expect(LayerMotion.glassOpacity(offset: 0) == 0)
        #expect(LayerMotion.glassOpacity(offset: 130) == 0)
        #expect(LayerMotion.glassOpacity(offset: 180) == 0.5)
        #expect(LayerMotion.glassOpacity(offset: 230) == 1)
        #expect(LayerMotion.glassOpacity(offset: 900) == 1)
    }

    // MARK: 組み立て

    private func makeContext() throws -> ModelContext {
        let schema = Schema([LaterPhoto.self, LaterGroup.self, UserProfile.self, PhotoVote.self, BlockedUser.self, ExposureDay.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        return ModelContext(container)
    }

    private func at(dayOffset: Int, hour: Int) -> Date {
        let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: Calendar.current.startOfDay(for: Date()))!
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    @Test func 撮る前は他人の写真を渡さず_ひらいたあとだけ渡す() throws {
        let context = try makeContext()
        let me = UserProfile(name: "わたし", username: "me")
        me.cloudKitUserRecordName = "ck-me"
        let friend = UserProfile(name: "あお", username: "ao")
        friend.cloudKitUserRecordName = "ck-ao"
        let group = LaterGroup(name: "なかま", host: me)
        context.insert(me); context.insert(friend); context.insert(group)
        _ = group.addMember(me)
        _ = group.addMember(friend)

        let photo = LaterPhoto(imageData: Data([1, 2, 3]), captureDate: at(dayOffset: -1, hour: 15), unlockDate: at(dayOffset: 0, hour: 9), owner: friend)
        photo.authorCloudKitUserRecordName = "ck-ao"
        photo.tags = ["夕焼け"]
        photo.groupID = group.id
        context.insert(photo)
        group.photos.append(photo)

        let now = at(dayOffset: 0, hour: 14)
        func build(_ state: HomeState, shots: Int) -> HomeLayerData {
            HomeLayerBuilder.make(state: state, now: now, shotsToday: shots, me: me, myRecordName: "ck-me", groups: [group], exposureDays: [], blocked: [], words: ["a", "b"], picks: [])
        }

        let dawn = build(.dawn, shots: 0)
        #expect(dawn.yesterday.count == 1)
        #expect(dawn.yesterday.allSatisfy { $0.imageData == nil })
        #expect(dawn.friends.map(\.name) == ["あお"])
        #expect(dawn.me?.hasShot == false)
        #expect(dawn.film.count == 7)
        #expect(dawn.film.first?.kind == .empty)

        let opened = build(.opened(shotAt: now), shots: 1)
        #expect(opened.yesterday.first?.imageData == Data([1, 2, 3]))
        #expect(opened.me?.hasShot == true)
        #expect(opened.film.first?.kind == .developing)

        let first = build(.first, shots: 0)
        #expect(first.yesterday.isEmpty)
        // はじめて:今日は「+ きょう撮る」、撮らなかった日は「おやすみ」
        #expect(first.film.first?.kind == .empty)
        #expect(first.film.dropFirst().allSatisfy { $0.kind == .rest })

        // ブロックした人は出さない
        let blocked = HomeLayerBuilder.make(state: .opened(shotAt: now), now: now, shotsToday: 1, me: me, myRecordName: "ck-me", groups: [group], exposureDays: [], blocked: ["ck-ao"], words: [], picks: [])
        #expect(blocked.yesterday.isEmpty)
        #expect(blocked.friends.isEmpty)
    }
}
