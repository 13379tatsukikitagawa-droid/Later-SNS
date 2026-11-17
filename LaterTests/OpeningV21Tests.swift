import SwiftUI
import Testing
@testable import Later_再度

/// v72 B:オープニング
@MainActor
struct OpeningV21Tests {
    @Test func 曲線は両端を通る() {
        let b = OPBez(0.34, 1.12, 0.42, 1)
        #expect(b.at(0) == 0 && b.at(1) == 1)
        #expect(b.at(0.5) > 0.5)
        #expect(OPBez(0.34, 1.12, 0.42, 1).at(0.8) > 1)   // 少しだけ 行きすぎる
    }

    @Test func キーフレームは区間ごとに補間() {
        let v = opKeys(0, [(0, 1), (180, 0.86), (360, 1)], OPBez(0.3, 1.4, 0.5, 1))
        #expect(v == 1)
        #expect(opKeys(180, [(0, 1), (180, 0.86), (360, 1)], OPBez(0.3, 1.4, 0.5, 1)) == 0.86)
        #expect(opKeys(999, [(0, 1), (180, 0.86), (360, 1)], OPBez(0.3, 1.4, 0.5, 1)) == 1)
    }

    @Test func 時間割りは2秒半以内() {
        #expect(OP72.openStart + OP72.openDur == OP72.total)
        #expect(OP72.total <= 2500)
        #expect(OP72.skipAfter == 600)
    }

    @Test func はじめも2回目も同じ_設定どおり() {
        let d = UserDefaults.standard
        let saved = d.string(forKey: "opening.mode")
        defer { d.set(saved, forKey: "opening.mode") }
        OpeningSettings.mode = .on
        #expect(OpeningSettings.variant(reduceMotion: false) == .full)
        #expect(OpeningSettings.variant(reduceMotion: false) == .full)
        #expect(OpeningSettings.variant(reduceMotion: true) == .fade)
        OpeningSettings.mode = .off
        #expect(OpeningSettings.variant(reduceMotion: false) == nil)
        OpeningSettings.mode = .short
        #expect(OpeningSettings.variant(reduceMotion: false) == .short)
    }
}
