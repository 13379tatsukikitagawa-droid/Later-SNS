import CoreGraphics
import Testing
@testable import Later_再度

/// QRを読む画面:読みとれたあとの動き(窓 → 丸 → 招待の円の位置へ)と、位置
@MainActor
struct QRScanTests {
    @Test func ロックの動きの順番() {
        let start = QRScanView.Morph(tau: 0, reduceMotion: false)
        #expect(start.cornerRadius == 44 && start.blackout == 0 && start.labels == 0)
        // 0.25秒で縁がオレンジに光りきる
        #expect(QRScanView.Morph(tau: 0.25, reduceMotion: false).edgeGlow == 1)
        // 0.55秒で丸になる。まだ動かない
        let round = QRScanView.Morph(tau: 0.55, reduceMotion: false)
        #expect(round.cornerRadius == 132 && round.move < 0.1)
        // 1.05秒で、まわりが黒・招待の円の位置へ
        let moved = QRScanView.Morph(tau: 1.05, reduceMotion: false)
        #expect(moved.move == 1 && moved.blackout == 1 && moved.edgeGlow == 0)
        // 0.9秒から、INVITATION とグループ名
        #expect(QRScanView.Morph(tau: 0.85, reduceMotion: false).labels == 0)
        #expect(QRScanView.Morph(tau: 1.2, reduceMotion: false).labels == 1)
    }

    @Test func 動きを減らすときはクロスフェードだけ() {
        let m = QRScanView.Morph(tau: 0.3, reduceMotion: true)
        #expect(m.edgeGlow == 0 && m.disc == 1 && m.blackout == 1)
        #expect(QRScanView.Morph(tau: 0.15, reduceMotion: true).disc == 0.5)
    }

    @Test func 窓は見出しにかからず_招待の円は上() {
        let layout = QRScanView.Layout(size: CGSize(width: 402, height: 874), safeTop: 62, safeBottom: 34)
        let windowTop = layout.windowCenter.y - QRScanView.windowSide / 2
        #expect(windowTop >= layout.headingTop + 80)
        #expect(layout.invitationCenter.y < layout.windowCenter.y)
        // 小さい端末でも、窓がドックにかからない
        let small = QRScanView.Layout(size: CGSize(width: 375, height: 667), safeTop: 20, safeBottom: 0)
        #expect(small.windowCenter.y + QRScanView.windowSide / 2 + 40 < small.dockY - 34)
    }
}
