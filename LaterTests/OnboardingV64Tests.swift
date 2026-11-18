import Testing
import Foundation
@testable import Later_再度

/// P01:はじめての設定(モック v64 の 8手順)と オープニングの 小さな 部品
@MainActor
struct OnboardingV64Tests {
    @Test func 手順のもどり先とページ番号() {
        #expect(OBStep.signin.back == nil && OBStep.name.back == nil && OBStep.go.back == nil)
        #expect(OBStep.mail.back == .signin && OBStep.sent.back == .mail)
        #expect(OBStep.id.back == .name && OBStep.id.page == 1 && OBStep.tag.back == .id && OBStep.fr.back == .tag && OBStep.nt.back == .fr)
        #expect(OBStep.name.page == 1 && OBStep.tag.page == 2 && OBStep.fr.page == 3 && OBStep.nt.page == 4)
        #expect(OBStep.signin.page == nil && OBStep.go.page == nil)
        #expect(OBStep.tag.pageLabel == "TAG" && OBStep.fr.pageLabel == "FRIENDS")
        // 保存用の 文字は モックの 名前どおり(「in」は Swift の 予約語なので signin)
        #expect(OBStep(rawValue: "in") == .signin && OBStep.allCases.count == 9)
    }

    @Test func 名前から決まる色はいつも同じ() {
        #expect(OB.colorIndex(for: "あや") == OB.colorIndex(for: "あや"))
        for n in ["あや", "Ken", "ゆい", "a", "🙂"] { #expect((0..<OB.palette.count).contains(OB.colorIndex(for: n))) }
    }

    @Test func メールの形() {
        #expect(OnboardingV64View.isValidEmail("you@example.com"))
        #expect(OnboardingV64View.isValidEmail("  You@Example.com "))
        #expect(!OnboardingV64View.isValidEmail("you@example"))
        #expect(!OnboardingV64View.isValidEmail("you example.com"))
        #expect(!OnboardingV64View.isValidEmail(""))
    }

    @Test func 名前とタグのきまりはそのまま() {
        #expect(OnboardingRules.validateName("あや").problem == nil)
        #expect(OnboardingRules.validateName("").problem == .empty)
        #expect(OnboardingRules.validateName("0123456789abc").problem == .tooLong)
        #expect(OnboardingRules.normalizedTag("#ねむい") == "ねむい")
        #expect(OnboardingRules.normalizedTag("ねむ い") == nil)
    }

    @Test func ミルク色の膜はだんだんうすく() {
        let order: [OBStep] = [.signin, .name, .tag, .fr, .nt, .go]
        let values = order.map { OB.milk($0) }
        #expect(values == values.sorted(by: >))
        #expect(OB.milk(.go) == 0 && OB.milk(.signin) == 1)
    }

    @Test func 動きの曲線と日付() {
        #expect(OpeningEase.bezier(0.3, 0.9, 0.3, 1, 0) == 0 && OpeningEase.bezier(0.3, 0.9, 0.3, 1, 1) == 1)
        let mid = OpeningEase.bezier(0.2, 0.8, 0.3, 1, 0.5)
        #expect(mid > 0.5 && mid < 1)   // 先に 進んで ゆっくり とまる
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        let d = cal.date(from: DateComponents(year: 2026, month: 11, day: 6))!
        #expect(OpeningStyle.shortDate(d) == "11.06")
        #expect(OpeningStyle.shortDate(d, apostrophe: true) == "'26 11 06")
    }
}
