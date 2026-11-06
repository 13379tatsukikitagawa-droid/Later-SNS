// ShotDoneView.swift
// 撮影後の画面の、曲線の計算と小さな部品。
// (v18.2 で撮影後の画面はなくした。撮ったあとはホームへもどる:ShotLanding.swift。ここには共通の計算だけを残す)

import os
import SwiftUI

/// 曲線と時間の計算(テストできるよう View から分けている)
nonisolated enum CaptureEase {
    static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }

    /// start から duration かけて 0→1
    static func progress(_ t: Double, start: Double, duration: Double) -> Double {
        guard duration > 0 else { return t >= start ? 1 : 0 }
        return clamp((t - start) / duration)
    }

    /// cubic-bezier(x1, y1, x2, y2) の値(p は時間の進み 0〜1)
    static func bezier(_ p: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        let p = clamp(p)
        if p == 0 || p == 1 { return p }
        func sample(_ t: Double, _ a1: Double, _ a2: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * t * a1 + 3 * u * t * t * a2 + t * t * t
        }
        // x(t) = p を二分法で解く
        var lo = 0.0, hi = 1.0, t = p
        for _ in 0..<24 {
            t = (lo + hi) / 2
            if sample(t, x1, x2) < p { lo = t } else { hi = t }
        }
        return sample(t, y1, y2)
    }

    static func out(_ p: Double) -> Double { bezier(p, 0.2, 0.9, 0.25, 1) }
    static func io(_ p: Double) -> Double { bezier(p, 0.65, 0, 0.25, 1) }
    /// チェキが出てくる cubic-bezier(.25,1,.35,1)
    static func eject(_ p: Double) -> Double { bezier(p, 0.25, 1, 0.35, 1) }
    /// アバターへ飛ぶ cubic-bezier(.6,0,.3,1)
    static func fly(_ p: Double) -> Double { bezier(p, 0.6, 0, 0.3, 1) }

    /// ばね(spring(response:0.4, dampingFraction:0.6) 相当)。経過秒 s で 0→1(行きすぎてもどる)
    static func spring(_ s: Double, response: Double = 0.4, damping: Double = 0.6) -> Double {
        guard s > 0 else { return 0 }
        let omega = 2 * Double.pi / response
        let decay = damping * omega
        let wd = omega * sqrt(max(0.0001, 1 - damping * damping))
        return 1 - exp(-decay * s) * (cos(wd * s) + decay / wd * sin(wd * s))
    }

    static func lerp(_ a: Double, _ b: Double, _ p: Double) -> Double { a + (b - a) * p }
}

/// 波線のきらきら
struct WaveMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        let step = rect.width / 3
        for i in 0..<3 {
            let x0 = rect.minX + CGFloat(i) * step
            path.addQuadCurve(to: CGPoint(x: x0 + step, y: rect.midY),
                              control: CGPoint(x: x0 + step / 2, y: i % 2 == 0 ? rect.minY : rect.maxY))
        }
        return path
    }
}

/// 撮影の時間の印(Instruments の signpost と、DEBUG のログ)
nonisolated enum CaptureSignpost {
    static let signposter = OSSignposter(subsystem: "jp.later.capture", category: "AfterShot")
    private static let lock = NSLock()
    nonisolated(unsafe) private static var shutterTime: CFAbsoluteTime = 0

    /// ① ② ③ の起点:長押しが 1.0 になった
    static func shutter() {
        lock.lock(); shutterTime = CFAbsoluteTimeGetCurrent(); lock.unlock()
        signposter.emitEvent("shutter")
        log("shutter")
    }

    /// 区間の名前つきの点。Instruments で shutter からの差を読む
    static func mark(_ name: StaticString, _ detail: String = "") {
        signposter.emitEvent(name)
        log("\(name)" + (detail.isEmpty ? "" : " \(detail)"))
    }

    static func elapsedSinceShutter() -> Double {
        lock.lock(); defer { lock.unlock() }
        return shutterTime == 0 ? 0 : CFAbsoluteTimeGetCurrent() - shutterTime
    }

    private static func log(_ text: String) {
        #if DEBUG
        print(String(format: "[AfterShot] +%4.0fms %@", elapsedSinceShutter() * 1000, text))
        #endif
    }
}
