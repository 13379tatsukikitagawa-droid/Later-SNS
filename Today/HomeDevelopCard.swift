import SwiftUI

/// 現像カード(自分の1枚)。どれくらい現像されたかを、写真を見せずに伝える。
/// [ 24個の点のリング + 丸い写真(チェキ現像) ] [ タイトル / 補足 ] [ あと 23:44 ]
/// タップで現像シート(night・ready・opened・dawn のときだけ)。
struct HomeDevelopCard: View {
    enum Content: Equatable {
        /// 現像中(night・ready・opened)
        case developing(capturedAt: Date, isNight: Bool)
        /// 現像ずみ(dawn。昨日の1枚)
        case developed(capturedAt: Date)
        /// rest:おやすみの日
        case rest
        /// first:最初の1枚
        case first
    }

    let content: Content
    let now: Date
    /// 強くぼかした色だけの画像(DevelopTexture)
    let texture: UIImage?
    var tones: [Color] = DevelopProgress.defaultTones
    var isAnimating = true
    /// のこりフィルム(3行目)。nilなら出さない。taken は今日撮った枚数、isNight は夜
    var film: (taken: Int, isNight: Bool)?
    var onTap: () -> Void = {}
    /// 白 × シック(撮る前の今日のホーム)の見た目にする
    var chic = false

    @Environment(\.palette) private var palette

    static let height: CGFloat = 88

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 28, style: .continuous) }

    var isTappable: Bool {
        switch content {
        case .developing, .developed: return true
        case .rest, .first: return false
        }
    }

    var body: some View {
        if chic {
            chicBody
        } else {
            darkBody
        }
    }

    private var darkBody: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                photoRing
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color(hex: "8E8E93"))
                    if let film {
                        HStack(spacing: 8) {
                            FilmPips(taken: film.taken, isNight: film.isNight, breathes: isAnimating)
                            Text(FilmPips.caption(taken: film.taken, isNight: film.isNight))
                                .font(.system(size: 10, design: .monospaced))
                                .tracking(0.1 * 10)
                                .foregroundStyle(Color(hex: "a9a9b0"))
                        }
                        .padding(.top, 2)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                trailing
            }
            .padding(.leading, 10)
            .padding(.trailing, 18)
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
            .background(background)
            .contentShape(shape)
        }
        .buttonStyle(DevelopCardButtonStyle())
        .disabled(!isTappable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isTappable ? .isButton : [])
    }

    private var background: some View {
        shape
            .fill(LinearGradient(colors: [.white.opacity(0.10), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .leading) {
                // 左のオレンジのやわらかい光(カードの外にははみ出さない)
                Circle()
                    .fill(HomePalette.orange.opacity(hasOrangeGlow ? 0.22 : 0.06))
                    .frame(width: 120, height: 120)
                    .blur(radius: 34)
                    .offset(x: -20)
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.09), lineWidth: 1))
    }

    private var hasOrangeGlow: Bool {
        switch content {
        case .developing, .developed: return true
        default: return false
        }
    }

    // MARK: - 点のリング + 丸い写真

    private var photoRing: some View {
        ZStack {
            switch content {
            case .developing(let at, _):
                DevelopDotRing(lit: DevelopDensity.litDots(capturedAt: at, now: now), isDeveloped: false, isAnimating: isAnimating)
                roundPhoto(density: DevelopDensity.density(DevelopDensity.fraction(capturedAt: at, now: now)))
            case .developed:
                DevelopDotRing(lit: DevelopDensity.dotCount, isDeveloped: true, isAnimating: isAnimating)
                roundPhoto(density: 1)
            case .rest, .first:
                DevelopDotRing(lit: 0, isDeveloped: false, isAnimating: false)
                Circle()
                    .strokeBorder(.white.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: 44, height: 44)
            }
        }
        .frame(width: 68, height: 68)
    }

    private func roundPhoto(density: Double) -> some View {
        ChekiDevelopImage(texture: texture, tones: tones, density: density, blurScale: 0.5, isAnimating: false)
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            .overlay(
                Circle().fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .topLeading, endPoint: .center))
            )
            .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
    }

    // MARK: - 右の列

    @ViewBuilder
    private var trailing: some View {
        switch content {
        case .developing(let at, _):
            VStack(alignment: .trailing, spacing: 1) {
                Text("あと")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color(hex: "8E8E93"))
                Text(DevelopDensity.remainingText(capturedAt: at, now: now))
                    .font(.system(size: 19, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
        case .developed:
            HStack(spacing: 6) {
                Circle().fill(HomePalette.orange).frame(width: 6, height: 6)
                    .shadow(color: HomePalette.orange, radius: 4)
                Text("READY")
                    .font(.system(size: 11, design: .monospaced))
                    .tracking(0.16 * 11)
                    .foregroundStyle(.white)
            }
        case .rest, .first:
            EmptyView()
        }
    }

    // MARK: - 文言

    var title: String {
        switch content {
        case .developing: return "今日の1枚を、預けました"
        case .developed: return "昨日の1枚、現像ずみ"
        case .rest: return "おやすみの日も、あっていい"
        case .first: return "最初の1枚に、なります"
        }
    }

    var subtitle: String {
        switch content {
        case .developing(_, let isNight): return isNight ? "9:00 に、仕上がります" : "あしたの朝、仕上がります"
        case .developed: return "今日を撮ると、ひらきます"
        case .rest: return "昨日の光は、とじたまま"
        case .first: return "撮ると、あしたの朝に仕上がります"
        }
    }

    var accessibilityText: String {
        let filmText = film.map { "。\(FilmPips.caption(taken: $0.taken, isNight: $0.isNight))" } ?? ""
        switch content {
        case .developing(let at, _):
            return "\(title)。\(subtitle)\(filmText)。あと\(DevelopDensity.remainingText(capturedAt: at, now: now))。タップで現像のようすを見る"
        case .developed:
            return "\(title)。\(subtitle)\(filmText)。タップで現像のようすを見る"
        default:
            return "\(title)。\(subtitle)\(filmText)"
        }
    }
}

private struct DevelopCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - 白 × シック(チェキのカード)

extension HomeDevelopCard {
    /// チェキの印画(62×74):縁は上と左右が5pt・下が17pt、黒い正方形の写真、左上に黄色いテープ、右下に日付
    private var instaxPrint: some View {
        let photoSide: CGFloat = 52
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(ChicColor.instax)
            ZStack(alignment: .bottomTrailing) {
                chicPhoto
                    .frame(width: photoSide, height: photoSide)
                    .clipped()
                Text(Self.stampText(now))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(ChicColor.stamp)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.trailing, 3)
                    .padding(.bottom, 2)
            }
            .padding(.leading, 5)
            .padding(.top, 5)
            ChicTape()
                .rotationEffect(.degrees(-6))
                .offset(x: -8, y: -6)
        }
        .frame(width: 62, height: 74)
        .shadow(color: ChicColor.instaxShadow.opacity(palette.isNight ? 0.6 : 0.45), radius: 14, y: 6)
        .rotationEffect(.degrees(-1.5))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var chicPhoto: some View {
        switch content {
        case .developing(let at, _):
            ChekiDevelopImage(texture: texture, tones: tones, density: DevelopDensity.density(DevelopDensity.fraction(capturedAt: at, now: now)), blurScale: 0.5, isAnimating: false)
        case .developed:
            ChekiDevelopImage(texture: texture, tones: tones, density: 1, blurScale: 0.5, isAnimating: false)
        case .rest, .first:
            ZStack {
                Color.black
                Circle().fill(.white).frame(width: 5, height: 5)
            }
        }
    }

    static func stampText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "M.dd"
        return f.string(from: date)
    }

    var chicBody: some View {
        let night = palette.isNight
        let shape = RoundedRectangle(cornerRadius: night ? 22 : 28, style: .continuous)
        return Button(action: onTap) {
            HStack(spacing: 14) {
                instaxPrint
                    .padding(.leading, 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(palette.ink)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.sub)
                    if let film {
                        HStack(spacing: 8) {
                            ChicFilmFrames(taken: film.taken, isNight: film.isNight)
                            Text(FilmPips.caption(taken: film.taken, isNight: film.isNight))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(night ? palette.sub : Color(hex: "3A3A3C"))
                        }
                        .padding(.top, 2)
                    }
                }
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                chicTrailing
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Self.height)
            .background(shape.fill(palette.fill))
            .overlay {
                if night { shape.strokeBorder(palette.line, lineWidth: 1) }
            }
            .contentShape(shape)
        }
        .buttonStyle(DevelopCardButtonStyle())
        .disabled(!isTappable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isTappable ? .isButton : [])
    }

    @ViewBuilder
    private var chicTrailing: some View {
        switch content {
        case .developing(let at, _):
            VStack(alignment: .trailing, spacing: 1) {
                Text("あと")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(palette.sub)
                Text(DevelopDensity.remainingText(capturedAt: at, now: now))
                    .font(.system(size: 19, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(palette.ink)
                    .contentTransition(.numericText())
            }
        case .developed:
            HStack(spacing: 6) {
                Circle().fill(palette.accent).frame(width: 6, height: 6)
                Text("READY")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(0.16 * 11)
                    .foregroundStyle(palette.ink)
            }
        case .rest, .first:
            EmptyView()
        }
    }
}

/// のこりフィルム(白地用):撮ったこまは濃い塗り、まだのこまは点線の枠(13×17)
struct ChicFilmFrames: View {
    @Environment(\.palette) private var palette
    let taken: Int
    var isNight = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<FilmRoll.shotsPerDay, id: \.self) { index in
                frame(index)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func frame(_ index: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 3.5, style: .continuous)
        if palette.isNight {
            // 夜の見た目:撮ったこま=アクセントの塗り、つぎのこま=アクセントの枠、まだのこま=白22%の点線
            if !isNight && index < taken {
                shape.fill(palette.accent).frame(width: 13, height: 17)
            } else if !isNight && index == taken {
                shape.strokeBorder(palette.accent, lineWidth: 1.2).frame(width: 13, height: 17)
            } else {
                shape
                    .strokeBorder(palette.ink.opacity(0.22), style: StrokeStyle(lineWidth: 1.2, dash: [2, 2]))
                    .frame(width: 13, height: 17)
            }
        } else if !isNight && index < taken {
            shape.fill(ChicColor.ink).frame(width: 13, height: 17)
        } else {
            shape
                .strokeBorder(ChicColor.ink.opacity(isNight ? 0.2 : 0.45), style: StrokeStyle(lineWidth: 1.2, dash: [2, 2]))
                .frame(width: 13, height: 17)
        }
    }
}
