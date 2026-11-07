import AVFoundation
import SwiftUI

// 撮影画面の動画モードの決めごと(v20。画面は v21 の CaptureScreenV21・長押しは ShutterGesture)。
// 上のまん中のガラスのカプセル「写真 / 動画」・ファインダーを よこになぞっても切りかわる(左へ = 動画)。
// 動画のシャッターは珊瑚いろ:おして 0.62秒ためる → ドン・カチッで録画 → 目もり 24こが 0.42秒ごとにともる →
// 7秒すぎで赤 → はなすと とまる(10秒ぴったりは自動)。1秒より みじかいと 1こま使わない。

enum CaptureMode: String, Equatable {
    case photo, video
}

enum VideoShutterRules {
    /// 録画中の 1秒おきの 脈の 強さ。ふだんは 0.2(弱い)、のこり 3秒(7・8・9秒)は 0.3 → 0.45 → 0.6
    nonisolated static func pulseIntensity(second: Int) -> Float {
        let left = Int(VideoRules.maxDuration) - second
        switch left {
        case 3: return 0.3
        case 2: return 0.45
        case 1: return 0.6
        default: return 0.2
        }
    }

    /// よこになぞる:46pt 以上・縦は 40pt 以内
    static func swipe(dx: CGFloat, dy: CGFloat) -> CaptureMode? {
        guard abs(dx) >= 46, abs(dy) <= 40 else { return nil }
        return dx < 0 ? .video : .photo
    }

    /// 録画の経過 → ともった目もりの数
    static func litTicks(elapsed: Double) -> Int {
        min(VideoRules.tickCount, max(0, Int(elapsed / VideoRules.tickInterval)))
    }

    /// のこり わずか(赤)
    static func isWarning(elapsed: Double) -> Bool { elapsed >= VideoRules.warnAfter }

    /// 録画中の連続バイブ(reel):ふだん 0.14「カラカラ」、7秒すぎで 0.16 → 0.76「ぎゅーっ」
    static func reelLevel(elapsed: Double) -> Double {
        guard elapsed >= VideoRules.warnAfter else { return 0.14 }
        let k = min(1, (elapsed - VideoRules.warnAfter) / (VideoRules.maxDuration - VideoRules.warnAfter))
        return 0.16 + 0.6 * k
    }

    /// 「● 00:03 / 10」
    static func timerText(_ elapsed: Double) -> String {
        String(format: "● %02d:%02d / %d", Int(elapsed) / 60, Int(elapsed) % 60, Int(VideoRules.maxDuration))
    }

    static let coral: [Color] = [Color(hex: "FF9A7A"), Color(hex: "FF5A3C"), Color(hex: "D63A26")]
}

/// 上のまん中:写真 / 動画(白いつまみが ばねで左右に。動画のときは橙〜桃)
struct CaptureModeSwitch: View {
    let mode: CaptureMode
    let onChange: (CaptureMode) -> Void

    var body: some View {
        ZStack(alignment: mode == .photo ? .leading : .trailing) {
            Capsule().fill(.white.opacity(0.085)).background(.ultraThinMaterial.opacity(0.5), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            Capsule()
                .fill(mode == .photo ? AnyShapeStyle(Color.white) : AnyShapeStyle(LinearGradient(colors: [Color(hex: "FFB36A"), Color(hex: "FF5DA2")], startPoint: .leading, endPoint: .trailing)))
                .frame(width: 54, height: 26)
                .padding(2)
            HStack(spacing: 0) {
                label("写真", .photo)
                label("動画", .video)
            }
        }
        .frame(width: 112, height: 30)
        .animation(.spring(response: 0.38, dampingFraction: 0.7), value: mode)
        .accessibilityElement(children: .contain)
    }

    private func label(_ text: String, _ value: CaptureMode) -> some View {
        Button { if mode != value { onChange(value) } } label: {
            Text(text)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(mode == value ? Color(hex: "111111") : .white.opacity(0.75))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityAddTraits(mode == value ? .isSelected : [])
    }
}

