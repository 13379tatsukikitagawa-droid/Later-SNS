#if DEBUG
import SwiftUI

/// DEBUG だけ。本物の データが 無くても 全画面を 確かめる ための 見本(メモリ上のみ。保存・送信しない)。
/// 写真は 色の 面(後の フェーズで 画像に 差しかえる)。
enum SampleData {
    struct Friend: Identifiable { let id: String; let name: String; let handle: String; let color: Color; let tags: [String] }
    struct Post: Identifiable { let id: Int; let city: String; let author: String; let tag: String; let color: Color }
    struct TripSample { let name: String; let key: String; let members: [String]; let range: String }

    static let friends: [Friend] = [
        .init(id: "yui", name: "ゆい", handle: "@yui_0612", color: Color(hex: "EE5E9C"), tags: ["#夕焼け", "#ひるね"]),
        .init(id: "ren", name: "れん", handle: "@ren_k", color: Color(hex: "9ED8FF"), tags: ["#散歩", "#コーヒー"]),
        .init(id: "mio", name: "みお", handle: "@mio.m", color: LattagPalette.lime, tags: ["#ねこ", "#本"]),
    ]
    static let requests: [Friend] = [
        .init(id: "sou", name: "そう", handle: "@sou_7", color: Color(hex: "FFD60A"), tags: ["#朝"]),
    ]
    static let mondo: [Post] = [
        .init(id: 1, city: "Tokyo", author: "ゆい", tag: "#夕焼け", color: Color(hex: "FF8A3D")),
        .init(id: 2, city: "Paris", author: "Léa", tag: "#cafe", color: Color(hex: "C8A46A")),
        .init(id: 3, city: "Seoul", author: "Jin", tag: "#雨", color: Color(hex: "7A8CA0")),
        .init(id: 4, city: "New York", author: "Sam", tag: "#subway", color: Color(hex: "3A3A44")),
        .init(id: 5, city: "Osaka", author: "れん", tag: "#散歩", color: Color(hex: "61D278")),
        .init(id: 6, city: "Lisbon", author: "Ana", tag: "#sunset", color: Color(hex: "EE5E9C")),
    ]
    static let trip = TripSample(name: "京都 2泊3日", key: "K7M2QX", members: ["あなた", "ゆい", "れん"], range: "NOV 20 – 22")
    static func friendCount(_ n: Int) -> [Friend] { Array(friends.prefix(max(0, min(friends.count, n)))) }
}
#endif
