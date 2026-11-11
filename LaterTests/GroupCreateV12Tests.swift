import CloudKit
import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Later_再度

/// グループ作成 v12:名前の規則(切らない・空白・絵文字)/ ボタンの文言 / たね / 色のコントラスト / 8色
@MainActor
struct GroupCreateV12Tests {
    @Test func 文字数は書記素で数え_絵文字も1文字() {
        #expect(GroupCreateName.count("帰り道の4人") == 6)
        #expect(GroupCreateName.count("👨‍👩‍👧‍👦🌙") == 2)
        #expect(GroupCreateName.initial("🌙よる") == "🌙")
    }

    @Test func 前後の空白_半角全角_を取り_空白だけは作れない() {
        #expect(GroupCreateName.finalize("　 ゼミ \u{3000}") == "ゼミ")
        #expect(GroupCreateName.status("　 \u{3000} ") == .empty)
        #expect(GroupCreateName.status("") == .empty)
    }

    @Test func 十四文字をこえても切らず_つくるは押せない() {
        let long = "あいうえおかきくけこさしすせそた" // 16
        #expect(GroupCreateName.clean(long) == long)
        #expect(GroupCreateName.status(long) == .over(2))
        #expect(GroupCreateName.status("あいうえおかきくけこさしすせ") == .ok) // ちょうど14
    }

    @Test func つくるボタンの文字は友だちの数でかわる() {
        #expect(GroupCreateName.createTitle(friends: 0, creating: false) == "つくる")
        #expect(GroupCreateName.createTitle(friends: 3, creating: false) == "つくって 3人に おくる")
        #expect(GroupCreateName.createTitle(friends: 3, creating: true) == "つくっています…")
        #expect(GroupCreateName.pickedNote(0) == "あとでも OK")
        #expect(GroupCreateName.pickedNote(3) == "3人 えらびました")
    }

    @Test func リンクは短く省略する() {
        let url = URL(string: "https://www.icloud.com/share/0aBcDeFgHiJk")
        #expect(GroupCreateName.shortLink(url) == "icloud.com/share/0aBcD…")
        #expect(GroupCreateName.shortLink(nil) == "")
    }

    @Test func 玉の色は名前から決まり_未入力はオレンジとピンク() {
        #expect(GroupCreateBlobPalette.index(for: "") == 0)
        #expect(GroupCreateBlobPalette.pairs[0] == ["FF8A3D", "FF5FA2"])
        #expect(GroupCreateBlobPalette.pairs.count == 8)
        #expect(GroupCreateBlobPalette.index(for: "部活") == GroupCreateBlobPalette.index(for: " 部活 "))
        for name in ["いつメン", "2-B", "ひみつ基地"] {
            #expect((0..<8).contains(GroupCreateBlobPalette.index(for: name)))
        }
    }

    @Test func 招待中は入るまで数える() throws {
        let schema = Schema([LaterPhoto.self, LaterGroup.self, UserProfile.self, PhotoVote.self, BlockedUser.self, ExposureDay.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: "invite-sent-test")!
        defaults.removePersistentDomain(forName: "invite-sent-test")
        let group = LaterGroup(name: "ゼミ")
        context.insert(group)
        GroupInviteSentStore.add(["a", "b", "a"], to: group.id, defaults: defaults)
        #expect(GroupInviteSentStore.ids(for: group.id, defaults: defaults) == ["a", "b"])
        #expect(GroupInviteSentStore.pendingCount(for: group, defaults: defaults) == 2)
        let joined = UserProfile(name: "b", username: "b")
        joined.cloudKitUserRecordName = "b"
        context.insert(joined)
        _ = group.addMember(joined)
        #expect(GroupInviteSentStore.pendingCount(for: group, defaults: defaults) == 1)
    }

    @Test func 改行は取る() {
        #expect(GroupCreateName.clean("朝活\nぐみ") == "朝活ぐみ")
    }

    @Test func たねは使っている名前を出さない() {
        let seeds = GroupCreateName.seeds(excluding: ["ゼミ", " 部活 "])
        #expect(!seeds.contains("ゼミ"))
        #expect(!seeds.contains("部活"))
        #expect(seeds.contains("いつメン"))
        #expect(GroupCreateName.seeds == ["いつメン", "放課後クラブ", "部活", "2-B", "帰り道", "ひみつ基地", "推し活", "テスト前"])
    }

    @Test func 顔の色は8つ_今までの番号は変わらない() {
        #expect(GroupPalette.count == 8)
        #expect(GroupPalette.automaticCount == 5)
        for name in ["なかま", "帰り道の4人", "ゼミ"] {
            #expect(GroupPalette.index(forName: name) < GroupPalette.automaticCount)
        }
    }

    // MARK: コントラスト(4.5 以上)

    private func luminance(_ color: Color) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> Double { let c = Double(c); return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    private func contrast(_ a: Color, _ b: Color) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    @Test func 昼も夜も文字が読める() {
        for night in [false, true] {
            let c = GroupCreateColors(night: night)
            #expect(contrast(c.ink, c.bg) >= 4.5)
            #expect(contrast(c.sub, c.bg) >= 4.5)
            #expect(contrast(c.placeholder, c.field) >= 4.5)
            #expect(contrast(c.primaryText, c.primaryBg) >= 4.5)
            #expect(contrast(c.disabledText, c.disabledBg) >= 4.5)
        }
    }

    @Test func 顔の設定は同期する() {
        let group = LaterGroup(name: "ゼミ")
        group.faceStyle = GroupFaceStyle.photo
        group.showsInitial = false
        let record = group.toCKRecord(existing: nil, ownerName: "owner", includeIcon: false)
        let other = LaterGroup(name: "x")
        other.apply(from: record)
        #expect(other.faceStyle == GroupFaceStyle.photo)
        #expect(other.showsInitial == false)
    }
}
