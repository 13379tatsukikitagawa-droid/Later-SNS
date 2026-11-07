import Testing
@testable import Later_再度

/// 動画の 録画中の 脈(A-2):ふだんは 弱く、のこり 3秒で 少しずつ 強く
struct VideoHapticsTests {
    @Test func 録画中の脈の強さ() {
        #expect(VideoRules.maxDuration == 10)
        for second in 1...6 { #expect(VideoShutterRules.pulseIntensity(second: second) == 0.2) }
        #expect(VideoShutterRules.pulseIntensity(second: 7) == 0.3)
        #expect(VideoShutterRules.pulseIntensity(second: 8) == 0.45)
        #expect(VideoShutterRules.pulseIntensity(second: 9) == 0.6)
    }
}
