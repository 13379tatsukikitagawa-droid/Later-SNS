// MarqueeRow.swift
// ことばの横流れ(6-3)。1段ぶん。TimelineView で毎フレーム位置を決める
// (Timer や repeatForever は、止める・再開が不安定なので使わない)。
// 止めたときは「止まっていた時間」をためて引き継ぐので、再開しても位置がとばない。

import SwiftUI

/// 3段のわけ方と、流れの位置の計算(テストできるよう View から分けている)
nonisolated enum MarqueeMath {
    /// 段ごとの速さ(1周の秒数)と向き。上=左へ46秒 / 中=右へ38秒 / 下=左へ52秒
    static let rowSeconds: [Double] = [46, 38, 52]
    static let rowReversed: [Bool] = [false, true, false]
    /// 「視差効果を減らす」のときは、とてもゆっくり
    static let reducedSeconds: Double = 200

    /// ことばを、ならびを変えてから rowCount 段にわける(1段の数は、ほぼ同じ)
    static func rows(_ words: [String], rowCount: Int = 3) -> [[String]] {
        guard rowCount > 0 else { return [] }
        var result = Array(repeating: [String](), count: rowCount)
        for (index, word) in words.enumerated() {
            result[index % rowCount].append(word)
        }
        return result
    }

    /// 1セット分の幅 w のとき、流れの横位置。時刻は「止まっていた時間」を引いたもの
    static func offset(time: Double, secondsPerLoop: Double, phase: Double, setWidth: Double, reversed: Bool) -> Double {
        guard secondsPerLoop > 0, setWidth > 0 else { return 0 }
        let t = time / secondsPerLoop + phase
        let fraction = t - floor(t)
        return reversed ? fraction * setWidth - setWidth : -fraction * setWidth
    }
}

struct MarqueeRow: View {
    let words: [String]
    let secondsPerLoop: Double
    let reversed: Bool
    /// はじまり位置(0〜1)。ひらくたびにランダム
    let phase: Double
    let selected: [String]
    let shakeCounts: [String: Int]
    /// タップした。位置は、名前つきの座標(coordinateSpaceName)で渡す
    var coordinateSpaceName: String
    var onTap: (String, CGPoint) -> Void = { _, _ in }

    @State private var paused = false
    @State private var pausedAt: Date?
    /// 止まっていた時間の合計
    @State private var pausedTotal: TimeInterval = 0
    @State private var setWidth: CGFloat = 0
    @State private var resumeToken = UUID()

    var body: some View {
        TimelineView(.animation(paused: paused)) { context in
            let date = pausedAt ?? context.date
            let x = MarqueeMath.offset(
                time: date.timeIntervalSinceReferenceDate - pausedTotal,
                secondsPerLoop: secondsPerLoop,
                phase: phase,
                setWidth: Double(setWidth),
                reversed: reversed
            )
            // 同じ列を3回ならべる(1セットが画面より短いときも、つなぎ目が見えない)
            HStack(spacing: 10) {
                tapeSet
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { setWidth = $0 + 10 }
                tapeSet
                tapeSet
            }
            .fixedSize()
            .offset(x: CGFloat(x))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 46)
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pause() }
                .onEnded { _ in scheduleResume() }
        )
        .onHover { inside in
            if inside { pause() } else { scheduleResume() }
        }
    }

    private var tapeSet: some View {
        HStack(spacing: 10) {
            ForEach(words, id: \.self) { word in
                DymoTape(kind: .word(word), selected: selected.contains(word), tilted: true)
                    .modifier(ShakeEffect(animatableData: CGFloat(shakeCounts[word] ?? 0)))
                    .animation(.linear(duration: 0.28), value: shakeCounts[word] ?? 0)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .named(coordinateSpaceName)) { location in
                        onTap(word, location)
                    }
            }
        }
    }

    private func pause() {
        resumeToken = UUID()
        guard pausedAt == nil else { return }
        pausedAt = Date()
        paused = true
    }

    /// 離して0.7秒後に、また流れる(そのあいだにまた触れたら、取り消す)
    private func scheduleResume() {
        let token = UUID()
        resumeToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            guard resumeToken == token, let pausedAt else { return }
            pausedTotal += Date().timeIntervalSince(pausedAt)
            self.pausedAt = nil
            paused = false
        }
    }
}
