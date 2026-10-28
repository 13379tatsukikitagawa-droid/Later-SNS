import CoreGraphics
import Foundation
import Testing
@testable import Later_再度

/// v2.1 の追加修正:合言葉の正規化・失敗の制限・Profileを開くスワイプの判定
@MainActor
struct V21FixesTests {
    @Test func 合言葉はかな・全角・空白をそろえて照合する() {
        #expect(GroupInviteService.normalizePassphrase("hikari-2741") == "hikari-2741")
        #expect(GroupInviteService.normalizePassphrase("ひかり-2741") == "hikari-2741")
        #expect(GroupInviteService.normalizePassphrase("ヒカリ 2741") == "hikari-2741")
        #expect(GroupInviteService.normalizePassphrase("ＨＩＫＡＲＩ－２７４１") == "hikari-2741")
        #expect(GroupInviteService.normalizePassphrase(" hikari2741 ") == "hikari-2741")
        #expect(GroupInviteService.normalizePassphrase("つき-1000") == "tsuki-1000")
        #expect(GroupInviteService.isPassphrase(GroupInviteService.normalizePassphrase("ほし ー 5555")))
    }

    @Test func 五回続けて見つからないと一分待つ() {
        PassphraseAttempts.reset()
        defer { PassphraseAttempts.reset() }
        let now = Date()
        for _ in 0..<4 { #expect(PassphraseAttempts.recordFailure(now: now) == nil) }
        let until = PassphraseAttempts.recordFailure(now: now)
        #expect(until == now.addingTimeInterval(60))
        #expect(PassphraseAttempts.lockUntil != nil)
        PassphraseAttempts.unlock()
        #expect(PassphraseAttempts.lockUntil == nil)
    }

    @Test func プロフィールは画面の端から始めたときだけ開く() {
        let width: CGFloat = 402
        let row = CGRect(x: 0, y: 660, width: width, height: 110)
        func opens(_ x: CGFloat, _ y: CGFloat, dx: CGFloat, dy: CGFloat = 0, excluded: [CGRect] = [row]) -> Bool {
            MainNavigationView.shouldOpenProfile(start: CGPoint(x: x, y: y), translation: CGSize(width: dx, height: dy), screenWidth: width, excluded: excluded)
        }
        // 端から左へ:開く
        #expect(opens(width - 10, 300, dx: -80))
        #expect(opens(10, 300, dx: -80))
        // 端でない場所から:開かない
        #expect(!opens(200, 300, dx: -200))
        // グループの列の中で始めた:端でも開かない
        #expect(!opens(width - 10, 700, dx: -200))
        // 斜め(20°より大きい)・短い・右向き:開かない
        #expect(!opens(width - 10, 300, dx: -80, dy: 40))
        #expect(!opens(width - 10, 300, dx: -30))
        #expect(!opens(10, 300, dx: 120))
        // Homeの上に別の画面が重なっている:開かない
        #expect(!opens(width - 10, 300, dx: -80, excluded: [.infinite]))
    }
}
