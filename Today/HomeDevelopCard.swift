import SwiftUI

/// 現像カード(預けた1枚が、時間とともに濃くなって色づく)。見えるのは写真の「色」だけで、
/// 写真そのものはひらくまで絶対に見せない。タップしても何も開かない(表示だけ)。
struct HomeDevelopCard: View {
    /// nilなら「まだ、預けた1枚はありません」(はじめての日)
    let subject: DevelopSubject?
    /// いま表示している濃さ(0〜1)。開いた時に0からのぼる演出は呼び出し側が行う。
    let progress: Double

    static let height: CGFloat = 62

    var body: some View {
        Group {
            if let subject {
                filled(subject)
            } else {
                empty
            }
        }
        .frame(height: Self.height)
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }

    private func filled(_ subject: DevelopSubject) -> some View {
        let p = min(1, max(0, progress))
        let trackColor = DevelopProgress.trackColor(p)
        return HStack(spacing: 12) {
            tonePhoto(subject.tones, p: p)

            VStack(alignment: .leading, spacing: 4) {
                Text(title(subject))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle(subject, p: p))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.opacity)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.09))
                        Capsule()
                            .fill(trackColor)
                            .frame(width: proxy.size.width * p)
                            .shadow(color: trackColor.opacity(0.6), radius: 4)
                    }
                }
                .frame(height: 2)
                .padding(.top, 2)
                .accessibilityHidden(true)
            }

            Text("\(Int((p * 100).rounded(.down)))%")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(trackColor)
                .monospacedDigit()
                .frame(minWidth: 34, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(shape.fill(LinearGradient(colors: [Color(hex: "1D1D20"), Color(hex: "141416")], startPoint: .top, endPoint: .bottom)))
        .overlay(shape.strokeBorder(.white.opacity(0.07), lineWidth: 1))
        .overlay(alignment: .top) { Capsule().fill(.white.opacity(0.1)).frame(height: 1).padding(.horizontal, 18) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(subject, p: p))
    }

    /// 小さな写真(34×44)。中身は写真の3色の丸いぼかし。濃さpで、暗く・くすんだ状態から色づく。
    private func tonePhoto(_ tones: [Color], p: Double) -> some View {
        let colors = tones.count >= 3 ? Array(tones.prefix(3)) : DevelopProgress.defaultTones
        return ZStack {
            Color.black
            Circle().fill(DevelopProgress.developed(colors[0], p)).frame(width: 30, height: 30).offset(x: -8, y: -12)
            Circle().fill(DevelopProgress.developed(colors[1], p)).frame(width: 26, height: 26).offset(x: 10, y: 0)
            Circle().fill(DevelopProgress.developed(colors[2], p)).frame(width: 28, height: 28).offset(x: -2, y: 14)
        }
        .blur(radius: 7)
        .opacity(0.35 + 0.65 * p)
        .frame(width: 34, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var empty: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(.white.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(width: 34, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("まだ、預けた1枚はありません")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text("撮ると、ここで現像がはじまります")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(shape.strokeBorder(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
        .accessibilityElement(children: .combine)
    }

    // MARK: - 文言

    private static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "M/d"
        return formatter
    }()

    private func title(_ subject: DevelopSubject) -> String {
        switch subject.kind {
        case .yesterday: return "あなたの昨日の1枚"
        case .today: return "今日の1枚を、預けました"
        case .waiting(let date): return "あなたの \(Self.monthDay.string(from: date)) の1枚が、待っています"
        }
    }

    private func subtitle(_ subject: DevelopSubject, p: Double) -> String {
        if case .today = subject.kind {
            return p >= 1 ? "現像ずみ ・ 撮るとひらく" : "現像中 ・ 明日 9:00 に仕上がる"
        }
        guard p >= 1 else { return "現像中 ・ 9:00 に仕上がる" }
        if case .waiting = subject.kind { return "現像ずみ ・ 次に撮ったとき、ひらく" }
        return "現像ずみ ・ 撮るとひらく"
    }

    private func accessibilityText(_ subject: DevelopSubject, p: Double) -> String {
        let percent = Int((p * 100).rounded(.down))
        let state = p >= 1 ? "現像ずみ" : "現像中、\(percent)パーセント。9時に仕上がります"
        return "\(title(subject))、\(state)"
    }
}
