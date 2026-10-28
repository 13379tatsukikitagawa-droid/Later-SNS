import SwiftUI
import Testing
@testable import Later_再度

/// 初回設定 v2:場面の順番・点の数・文言の定数と、見た目の確認(LATER_SNAPSHOT_DIR があるときだけ)
@MainActor
struct OnboardingV2Tests {
    @Test func 七画面で点が1つずつ灯る() {
        #expect(OnboardingStep.mainFlow == [.account, .name, .day, .tags, .quiet, .photo, .notify])
        #expect(OnboardingStep.mainFlow.map(\.litDots) == [1, 2, 3, 4, 5, 6, 7])
        #expect(OnboardingStep.account.next == .name)
        #expect(OnboardingStep.notify.next == nil)
        #expect(OnboardingStep.quiet.isQuiet && !OnboardingStep.tags.isQuiet)
        #expect(OnboardingStep.day.next == .tags && OnboardingStep.tags.next == .quiet)
        #expect(SelfTagCatalog.candidates.count == 12)
        #expect(OnboardingTagInputField.clean("#朝 型＃") == "朝型")
        #expect(OnboardingTagInputField.clean(String(repeating: "あ", count: 20)).count == 12)
        #expect(OnboardingStep.account.usesHeroOrb && !OnboardingStep.name.usesHeroOrb)
        #expect(OnboardingStep.emailInput.next == nil)
    }

    @Test func 三の場面は約25秒() {
        let total = LaterDayView.scenes.map(\.duration).reduce(0, +)
        #expect(abs(total - 25.2) < 0.01)
        #expect(LaterDayView.scenes.count == 6)
    }

    @Test func 数字は出典から切り離さない_通知の本文は1つ() {
        #expect(OnboardingCopy.quietStat == "約3人に1人")
        #expect(OnboardingCopy.quietSource.contains("出典"))
        #expect(OnboardingCopy.dailyNotificationBody == "9:00 になりました。今日を撮れます。")
    }

    @Test func 見た目() throws {
        guard let dir = ProcessInfo.processInfo.environment["LATER_SNAPSHOT_DIR"].map({ URL(fileURLWithPath: $0) }) else { return }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let rings = VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(0..<2, id: \.self) { col in
                        DayRing(scene: row * 2 + col, t: 0.9).frame(width: 236, height: 236)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        let r1 = ImageRenderer(content: rings)
        r1.scale = 1.5
        try #require(r1.uiImage?.pngData()).write(to: dir.appendingPathComponent("onboarding_day_rings.png"))

        for ms in [800.0, 2600, 3400] {
            let view = OnboardingWelcomeView(start: Date().addingTimeInterval(-ms / 1000), haptics: ExposureHaptics(), onFinished: {})
                .frame(width: 390, height: 844)
                .environment(\.colorScheme, .dark)
            let r = ImageRenderer(content: view)
            r.scale = 1
            try #require(r.uiImage?.pngData()).write(to: dir.appendingPathComponent("onboarding_welcome_\(Int(ms)).png"))
        }
    }
}
