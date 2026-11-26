// CaptureKit.swift
// 撮影の流れ(タグ → 撮影 → 撮影後)で共有する、小さな部品と決めごと。
// - 色(昼夜・テープ6色・サンライズ)
// - フォント(入っていなければ、システムの代わりを使う)
// - テープの色の決め方(FNV-1a。hashValue は使わない)
// - 動きの曲線(out / io / spring)
// - 画面の配置(ファインダーとスロットの位置。流れの中の「つながる動き」でも同じ値を使う)
// - 触覚(ExposureHaptics の上に名前をつけただけ。設定がオフなら鳴らない)

import SwiftUI
import UIKit

// MARK: - 色

/// タグ画面・撮影後の画面の昼夜の色(10章)。撮影画面は昼夜で変えない(いつも黒)。
nonisolated struct CaptureColors: Equatable {
    let bg: PaletteHex
    let ink: PaletteHex
    let sub: PaletteHex
    let line: PaletteHex
    let fill: PaletteHex
    let card: PaletteHex
    let cardStroke: PaletteHex
    let ctaBG: PaletteHex
    let ctaText: PaletteHex
    let slot: PaletteHex

    static let day = CaptureColors(
        bg: PaletteHex(rgb: 0xFFFFFF),
        ink: PaletteHex(rgb: 0x111111),
        sub: PaletteHex(rgb: 0x6E6E73),
        line: PaletteHex(rgb: 0xE8E8ED),
        fill: PaletteHex(rgb: 0xF3F3F6),
        card: PaletteHex(rgb: 0x111111),
        cardStroke: PaletteHex(rgb: 0xFFFFFF, alpha: 0),
        ctaBG: PaletteHex(rgb: 0x111111),
        ctaText: PaletteHex(rgb: 0xFFFFFF),
        slot: PaletteHex(rgb: 0x111111)
    )

    static let night = CaptureColors(
        bg: PaletteHex(rgb: 0x000000),
        ink: PaletteHex(rgb: 0xFFFFFF),
        sub: PaletteHex(rgb: 0x9A9AA0),
        line: PaletteHex(rgb: 0x2A2A2E),
        fill: PaletteHex(rgb: 0xFFFFFF, alpha: 0.09),
        card: PaletteHex(rgb: 0x1C1C1E),
        cardStroke: PaletteHex(rgb: 0xFFFFFF, alpha: 0.10),
        ctaBG: PaletteHex(rgb: 0xFFFFFF),
        ctaText: PaletteHex(rgb: 0x111111),
        slot: PaletteHex(rgb: 0x2C2C2E)
    )

    /// アプリ全体の Palette(ThemeClock が決める)に合わせて選ぶ
    static func `for`(_ palette: Palette) -> CaptureColors {
        palette == .night ? .night : .day
    }
}

enum CaptureTint {
    static let orange = PaletteHex(rgb: 0xFF6A1A).color
    static let stamp = PaletteHex(rgb: 0xFF8A3D).color
    static let cameraBG = PaletteHex(rgb: 0x0B0B0C).color
    static let leftBox = PaletteHex(rgb: 0x1C1C1E).color
    static let paper = PaletteHex(rgb: 0xFFFDF8).color
    static let used = PaletteHex(rgb: 0xC7C7CC).color
    /// 進行リングのサンライズ(黄 → 橙 → ピンク)
    static let sunrise: [Color] = [PaletteHex(rgb: 0xFFD60A).color, PaletteHex(rgb: 0xFF6A1A).color, PaletteHex(rgb: 0xFF7AB6).color]
}

// MARK: - テープの色(5章)

nonisolated enum TapeColor: Int, CaseIterable, Sendable {
    case t1 = 1, t2, t3, t4, t5, t6

    var hex: UInt32 {
        switch self {
        case .t1: 0x111111
        case .t2: 0xE8463A
        case .t3: 0x2F6BFF
        case .t4: 0xFFD60A
        case .t5: 0x22B573
        case .t6: 0xFF7AB6
        }
    }

    var color: Color { PaletteHex(rgb: hex).color }
    /// 黄だけ文字は黒
    var textColor: Color { self == .t4 ? PaletteHex(rgb: 0x111111).color : .white }
}

/// 名前から決まる安定した値(FNV-1a 64bit)。hashValue は起動ごとに変わるので使わない。
nonisolated enum FNV1a {
    static func hash(_ text: String) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x0000_0100_0000_01B3
        }
        return h
    }
}

nonisolated enum TapeStyle {
    /// 表の色(気分で決める)。表にないことば(自分で書いたもの)は FNV-1a で t1〜t6 から選ぶ。
    static let fixed: [String: TapeColor] = [
        "がんばった": .t4, "ごきげん": .t4, "たのしい": .t4, "朝": .t4,
        "わくわく": .t2, "そわそわ": .t2, "きんちょう": .t2, "電車": .t2, "夕方": .t2,
        "ねむい": .t3, "ぼんやり": .t3, "さみしい": .t3, "空": .t3,
        "ほっとした": .t5, "おだやか": .t5, "散歩": .t5,
        "しあわせ": .t6, "むねがいっぱい": .t6, "ごはん": .t6,
        "だるい": .t1, "もやもや": .t1, "めんどう": .t1, "コーヒー": .t1, "仕事": .t1,
    ]

    static func color(for word: String) -> TapeColor {
        if let fixed = fixed[word] { return fixed }
        let index = Int(FNV1a.hash(word) % 6)
        return TapeColor.allCases[index]
    }

    /// 一覧のテープの小さなゆらぎ(-1.4° 〜 +1.2°)。同じことばは毎回同じ角度。
    static func tilt(for word: String) -> Double {
        let unit = Double(FNV1a.hash("tilt:" + word) % 1000) / 999.0
        return -1.4 + unit * 2.6
    }
}

// MARK: - フォント(入っていなければ、システムの代わり。新しく足さない)

enum CaptureFont {
    nonisolated private static func available(_ name: String) -> Bool { UIFont(name: name, size: 12) != nil }
    private static let serifItalicName: String? = ["InstrumentSerif-Italic"].first(where: available)
    private static let handName: String? = ["ZenKurenaido-Regular", "Kurenaido-Regular", "Kurenaido"].first(where: available)
    private static let headingName: String? = ["HiraginoSans-W8", "HiraginoSans-W7"].first(where: available)

    /// 数字・日付・のこり(v118:SF Pro の 太字)
    static func mono(_ size: CGFloat, bold: Bool = true) -> Font {
        Typo.label(size, bold: bold)
    }

    /// 「today's mood」だけ(Instrument Serif 斜体)
    static func serifItalic(_ size: CGFloat) -> Font {
        if let serifItalicName { return .custom(serifItalicName, size: size) }
        return .system(size: size, design: .serif).italic()
    }

    /// 人の手で書いたもの(Kurenaido。なければ丸ゴシック系)
    static func hand(_ size: CGFloat) -> Font {
        if let handName { return .custom(handName, size: size) }
        return .system(size: size, weight: .medium, design: .rounded)
    }

    /// 見出し(ヒラギノ角ゴ W8。なければシステムの太字)
    static func heading(_ size: CGFloat) -> Font {
        if let headingName { return .custom(headingName, size: size) }
        return .system(size: size, weight: .black)
    }
}

// MARK: - 動きの曲線(9章)

enum FlowMotion {
    /// 出てくる動き全部
    static func out(_ duration: Double) -> Animation { .timingCurve(0.2, 0.9, 0.25, 1, duration: duration) }
    /// 大きく動く(カードがひろがる・スロットに入る)
    static func io(_ duration: Double) -> Animation { .timingCurve(0.65, 0, 0.25, 1, duration: duration) }
    /// 小さな物(テープ・フィルム・アバター)
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.6)
}

// MARK: - 配置(基準 390×844。画面の大きさに合わせる)

struct CaptureLayout: Equatable {
    /// 画面全体(セーフエリアを含む)
    var size: CGSize
    var safeTop: CGFloat
    var safeBottom: CGFloat

    /// v21:見本は 390×844。縦の位置は画面の高さの比で動かす(ノッチ・Dynamic Island の下に入るように)
    var ky: CGFloat { max(0.72, size.height / 844) }
    func y(_ v: CGFloat) -> CGFloat { v * ky }

    /// シャッターの中心(見本:上端 676・104pt の円)
    var shutterCenter: CGPoint {
        CGPoint(x: size.width / 2, y: y(728))
    }

    /// 上のバー(高さ 46)の中心
    var topBarCenterY: CGFloat { max(safeTop + 26, y(56) + 23) }

    /// 撮影の窓(左右16・上112・高さ500・角30)。上のバーとは重ねない
    var finder: CGRect {
        let top = max(y(112), topBarCenterY + 23 + 8)
        let w = max(0, size.width - 16)
        return CGRect(x: 8, y: top, width: w, height: min(w * 4 / 3, y(520)))
    }

    /// 撮影後の画面の、上のスロット(幅270×高18)
    var slot: CGRect {
        CGRect(x: (size.width - 270) / 2, y: safeTop + 137, width: 270, height: 18)
    }

    /// 撮影後の画面の、右上のアバター
    var avatarCenter: CGPoint {
        CGPoint(x: size.width - 42, y: safeTop + 20)
    }
}

// MARK: - 触覚(11章)

extension ExposureHaptics {
    /// タグを選ぶ(1つ目):ポン
    func capturePon() { playTransient(intensity: 0.5, sharpness: 0.45) }
    /// タグを選ぶ(2つ目):カチッ
    func captureKachi() { playTransient(intensity: 0.75, sharpness: 0.8) }
    /// はずす・じぶんで書く:ごく軽く
    func captureFeather() { playTransient(intensity: 0.22, sharpness: 0.3) }
    /// ながおしの段階(0.34 / 0.72):コッ(一段ずつ強く)
    func captureKot(stage: Int) { playTransient(intensity: stage >= 2 ? 0.8 : 0.6, sharpness: 0.65) }
    /// 撮れた:パシャ(強さ 0.9・シャープ 0.8)
    func capturePasha() { fireCapture(intensity: 0.9, sharpness: 0.8) }
    /// チェキが出てくる:ジーッ(弱い連続)
    func captureZii(duration: TimeInterval) { playRamp(from: 0.18, to: 0.28, sharpness: 0.15, duration: duration) }
    /// スタンプ:トン(中)
    func captureTon() { playTransient(intensity: 0.6, sharpness: 0.5) }
    /// アバターに届いた:ポッ(軽く1回)
    func capturePop() { playTransient(intensity: 0.35, sharpness: 0.55) }
}

// MARK: - ダイモテープ(6-2)

struct DymoTape: View {
    enum Kind: Equatable {
        case word(String)
        case place(String)
        /// 書いている途中(点線のうすいテープ)
        case draft(String)
        /// 空き枠(点線の「+ タグ」)
        case empty
    }

    let kind: Kind
    var height: CGFloat = 34
    var fontSize: CGFloat = 14
    var maxWidth: CGFloat = 210
    var selected = false
    var tilted = false

    var body: some View {
        CappedWidth(maxWidth: maxWidth) {
            content
                .frame(height: height)
        }
        .rotationEffect(.degrees(tilted ? tiltDegrees : 0))
            .opacity(selected ? 0.26 : 1)
            .scaleEffect(selected ? 0.94 : 1)
            .animation(FlowMotion.spring, value: selected)
    }

    private var tiltDegrees: Double {
        if case .word(let word) = kind { return TapeStyle.tilt(for: word) }
        return 0
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .word(let word):
            solid(text: TagDictionary.display(word), color: TapeStyle.color(for: word))
        case .place(let place):
            HStack(spacing: 4) {
                Image(systemName: "mappin")
                    .font(.system(size: fontSize * 0.82, weight: .bold))
                label(place)
            }
            .foregroundStyle(PaletteHex(rgb: 0x111111).color)
            .padding(.horizontal, height * 0.42)
            .frame(height: height)
            .background(tapeShape.fill(CaptureTint.paper))
            .overlay(holes(color: PaletteHex(rgb: 0xE7E2D6).color))
            .shadow(color: .black.opacity(selected ? 0 : 0.18), radius: 1.5, y: 1)
        case .draft(let text):
            label(text.isEmpty ? "…" : text)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, height * 0.42)
                .frame(height: height)
                .background(tapeShape.strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])).foregroundStyle(.white.opacity(0.55)))
        case .empty:
            // v14 ④:かならず1行(幅が足りなくても折り返さない)
            Text("+ タグ")
                .lineLimit(1)
                .fixedSize()
                .font(.system(size: fontSize * 0.92, weight: .bold))
                .foregroundStyle(.white.opacity(0.42))
                .padding(.horizontal, height * 0.42)
                .frame(height: height)
                .background(tapeShape.strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])).foregroundStyle(.white.opacity(0.3)))
        }
    }

    private func solid(text: String, color: TapeColor) -> some View {
        label(text)
            .foregroundStyle(color.textColor)
            .shadow(color: .black.opacity(color == .t4 ? 0.08 : 0.25), radius: 0.5, y: 0.5)
            .padding(.horizontal, height * 0.42)
            .frame(height: height)
            .background(
                tapeShape.fill(color.color)
                    .overlay(
                        // ぷっくり:上にうすいハイライト、下にうすい影
                        tapeShape.fill(LinearGradient(colors: [.white.opacity(0.22), .clear, .black.opacity(0.12)], startPoint: .top, endPoint: .bottom))
                    )
            )
            .overlay(holes(color: color.color))
            .shadow(color: .black.opacity(selected ? 0 : 0.2), radius: 2, y: 1.5)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .heavy))
            .tracking(fontSize * 0.08)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var tapeShape: RoundedRectangle { RoundedRectangle(cornerRadius: 4, style: .continuous) }

    /// 左右の端の小さい丸(テープの穴)。半分はみ出す。色は背景を少し暗く
    private func holes(color: Color) -> some View {
        HStack {
            hole(color)
            Spacer(minLength: 0)
            hole(color)
        }
        .padding(.horizontal, -3)
        .allowsHitTesting(false)
    }

    private func hole(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .overlay(Circle().fill(Color.black.opacity(0.24)))
            .frame(width: 6, height: 6)
    }
}

/// 子の幅を「理想の幅・maxWidth・親の提案」のいちばん小さい値にする(長いことばは「…」)
struct CappedWidth: Layout {
    let maxWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let ideal = child.sizeThatFits(.unspecified)
        let width = min(ideal.width, maxWidth, proposal.width ?? .infinity)
        return child.sizeThatFits(ProposedViewSize(width: width, height: proposal.height ?? ideal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
                              proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}

// MARK: - 小さいフィルム3枚

struct FilmTriplet: View {
    /// 今日のこり(0〜3)
    let left: Int
    var width: CGFloat = 9
    var height: CGFloat = 12
    var spacing: CGFloat = 3
    var usedColor: Color = CaptureTint.used

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<FilmRoll.shotsPerDay, id: \.self) { index in
                // 灰色=つかった(左から)、オレンジ=のこり
                let used = index < FilmRoll.shotsPerDay - left
                RoundedRectangle(cornerRadius: min(2.5, width * 0.22), style: .continuous)
                    .fill(used ? usedColor : CaptureTint.orange)
                    .frame(width: width, height: height)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - 時刻の判定

enum CaptureClock {
    /// 0:00〜8:59 は、おやすみの時間(撮れない)。撮影の窓(9:00〜24:00)で決める。
    /// 画面の黒(ThemeClock・21:00〜)とは別。21:00〜23:59 は黒い画面のまま撮れる。
    static func isRestTime(_ date: Date = Date()) -> Bool { DailyWindow.isNight(date) }

    /// 「'26 10 31  06:28」(写真には焼きつけない。画面の飾りだけ)
    static func stamp(_ date: Date, withTime: Bool = true) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = withTime ? "''yy MM dd  HH:mm" : "''yy MM dd"
        return formatter.string(from: date)
    }
}
