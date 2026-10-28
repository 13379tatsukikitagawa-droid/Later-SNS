import Foundation
import CoreGraphics

/// プロフィール(フィルム版)の見た目の計算。写真の中身や保存のルールは変えない。
enum ProfileFilmMath {
    /// フィルムのコマ(今日から6日前まで)
    static let frameCount = ProfileShot.railSlotCount
    /// コマの大きさ(3:4)
    static let frameSize = CGSize(width: 72, height: 96)
    /// 中央からこの距離(pt)で、拡大と傾きが端まで変わる
    static let focusWidth: CGFloat = 80
    /// 長押しで消すまでの時間(秒)
    static let holdDuration: TimeInterval = 1.2
    /// 指をはなしたとき、リングがもどる時間(秒)
    static let releaseDuration: TimeInterval = 0.35
    /// 触覚 tick を連続で鳴らさない間隔(秒)
    static let tickInterval: TimeInterval = 0.09

    /// 今日(0)から6日前(6)までの日付キー。左が今日、右ほど古い。
    static func dayKeys(now: Date, calendar: Calendar = .current) -> [String] {
        Array(ProfileShot.railDayKeys(now: now, calendar: calendar).reversed())
    }

    /// 古さ(ago = 今日からの日数)で、うすくなる度合い
    static func ageFade(ago: Int) -> Double { 1 - Double(ago) * 0.045 }
    /// 古いほど、彩度を落とす
    static func ageSaturation(ago: Int) -> Double { 1.1 - Double(ago) * 0.06 }
    /// 古いほど、セピアにする
    static func ageSepia(ago: Int) -> Double { Double(ago) * 0.06 }
    /// 古いほど、縁を橙に焼く(0〜1)
    static func ageBurn(ago: Int) -> Double { Double(ago) * 0.16 }

    /// 中央からの距離(0が中央、1でふちの手前)
    static func distance(offset: CGFloat) -> Double {
        Double(abs(offset) / focusWidth)
    }

    /// 中央のコマが1.22倍、外側は1に近づく
    static func scale(distance: Double) -> CGFloat {
        1 + 0.22 * CGFloat(max(0, 1 - distance))
    }

    static func opacity(distance: Double, ago: Int) -> Double {
        max(0.28, (1 - 0.3 * min(distance, 2.2)) * ageFade(ago: ago))
    }

    /// 外側へ倒れる角度(度)。中央より右は+、左は−。
    static func tiltDegrees(distance: Double, offset: CGFloat) -> Double {
        let direction: Double = offset >= 0 ? 1 : -1
        return -34 * min(distance, 1) * direction
    }

    /// 長押しのリング(0〜1)。途中で離したときは、ここに戻る。
    static func ringProgress(holdElapsed: TimeInterval) -> Double {
        min(1, max(0, holdElapsed / holdDuration))
    }

    static func isHoldComplete(holdElapsed: TimeInterval) -> Bool {
        holdElapsed >= holdDuration
    }

    /// 前の tick から間隔が空いているか
    static func shouldTick(last: Date?, now: Date) -> Bool {
        guard let last else { return true }
        return now.timeIntervalSince(last) >= tickInterval
    }
}
