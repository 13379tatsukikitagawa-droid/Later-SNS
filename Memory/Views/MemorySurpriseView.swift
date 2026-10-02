import SwiftUI

/// Home画面のグループセクション直下に表示する、琥珀色グラデーションの振り返りバナー
/// (2026/9 新デザイン仕様「1週間前の今日」振り返りバナー)。offsetLabelは
/// MemorySurpriseManager.findMemoryが返す節目(1週間前/1ヶ月前/半年前...)をそのまま使う。
struct MemorySurpriseCardView: View {
    let match: MemoryMatch
    let onTap: () -> Void

    private static let textColor = Color(hex: "2B1B08")

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "star.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(hex: "FBF0DC"))

                VStack(alignment: .leading, spacing: 2) {
                    Text(match.offsetLabel)
                        .font(.system(size: 13.5, weight: .heavy))
                        .foregroundStyle(Self.textColor)
                    Text("振り返る")
                        .font(.system(size: 11))
                        .foregroundStyle(Self.textColor.opacity(0.75))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Self.textColor)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "E3A93B"), Color(hex: "C9862A")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(hex: "C9862A").opacity(0.3), radius: 12, x: 0, y: 6)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

/// 記憶カードをタップした時の全画面ビューア。「◯◯前の今日」ラベルが先に浮かび上がり、
/// 少し間を置いてから写真・キャプションがフェードインする(めくれるカードと同じ
/// 「段階を置いて表示が変わる」文法だが、全画面での回転は落ち着かないためフェード+スケールで表現)。
struct MemorySurpriseViewerView: View {
    let match: MemoryMatch
    let onClose: () -> Void

    @State private var labelOpacity: Double = 0
    @State private var labelScale: CGFloat = 0.9
    @State private var labelOffset: CGFloat = 0
    @State private var contentOpacity: Double = 0
    @State private var contentScale: CGFloat = 0.95

    var body: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()

            VStack(spacing: 20) {
                Text(match.offsetLabel)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .opacity(labelOpacity)
                    .scaleEffect(labelScale)
                    .offset(y: labelOffset)

                contentView
                    .opacity(contentOpacity)
                    .scaleEffect(contentScale)
            }
            .padding()

            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear { playReveal() }
    }

    private var contentView: some View {
        VStack(spacing: 14) {
            if let uiImage = UIImage(data: match.photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 4) {
                Text(dateString(match.targetDate))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))

                Text("\(match.group.name) ・ \(match.photo.owner?.name ?? match.photo.authorNameCache ?? "不明")")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))

                if let caption = match.photo.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 6)
                }
            }
        }
    }

    private func playReveal() {
        withAnimation(.easeOut(duration: 0.4)) {
            labelOpacity = 1
            labelScale = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.3)) {
                labelOffset = -30
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                contentOpacity = 1
                contentScale = 1.0
            }
        }
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
}
