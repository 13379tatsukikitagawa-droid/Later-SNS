import CloudKit
import Foundation
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

    @Test func 十二文字をこえても切らず_ボタンでへらしてと伝える() {
        let long = "あいうえおかきくけこさしすせ" // 14
        #expect(GroupCreateName.clean(long) == long)
        #expect(GroupCreateName.status(long) == .over(2))
        #expect(GroupCreateName.buttonTitle(.over(2)) == "2文字、へらしてね")
        #expect(GroupCreateName.buttonTitle(.empty) == "名前を いれてね")
        #expect(GroupCreateName.buttonTitle(.ok) == "つぎへ")
        #expect(GroupCreateName.status("あいうえおかきくけこさし") == .ok) // ちょうど12
    }

    @Test func 改行は取る() {
        #expect(GroupCreateName.clean("朝活\nぐみ") == "朝活ぐみ")
    }

    @Test func たねは使っている名前を出さない() {
        let seeds = GroupCreateName.seeds(excluding: ["ゼミ", " 部活 "])
        #expect(!seeds.contains("ゼミ"))
        #expect(!seeds.contains("部活"))
        #expect(seeds.contains("帰り道の4人"))
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
