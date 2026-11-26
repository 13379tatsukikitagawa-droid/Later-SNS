import SwiftUI

// v134 Phase 6:はじめての設定(Opal 型:1画面に 1問)に 足す 3つの 画面。見本 screens/03 ・ 04 ・ 08 ・ 09。
// 質問(撮った 写真、すぐに 見返す?)→ 理由 → 名前 … 通知 → 長押しで はじめる。順番は 今までの まま(サインイン → 質問 → 理由 → 名前 → ID → タグ → ともだち → 通知 → はじめる)。
// 質問の 答えは 保存しない。上に 5つに 分かれた 進みバーと もどる。

struct OBProgressV134: View {
    var filled: Int
    var onBack: (() -> Void)?
    var body: some View {
        HStack(spacing: 8) {
            if let onBack {
                Button { LTHaptics.play(.tap); onBack() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44).background(LTColor.surface3, in: Circle())
                }.buttonStyle(.plain).accessibilityLabel("もどる")
            }
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in Capsule().fill(i < filled ? Color.white : Color.white.opacity(0.12)).frame(height: 3) }
            }.accessibilityElement(children: .ignore).accessibilityLabel("\(filled) / 5")
        }.padding(.horizontal, 16).padding(.top, 8)
    }
}

struct OBQuestionV134: View {
    var onPick: (Int) -> Void
    @State private var picked: Int?
    private let options = ["毎回すぐ見る", "ときどき見る", "ほとんど見ない"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("撮った写真、\nすぐに見返す？").font(LTFont.ui(34, weight: .heavy)).tracking(-0.8).foregroundStyle(.white).lineSpacing(4)
                .padding(.horizontal, 22).padding(.top, 36).accessibilityAddTraits(.isHeader)
            VStack(spacing: 12) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, t in
                    Button {
                        guard picked == nil else { return }
                        picked = i; LTHaptics.play(.select)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onPick(i) }   // 押したら 0.5秒後に 次へ
                    } label: {
                        HStack(spacing: 14) {
                            Text(["A", "B", "C"][i]).font(LTFont.display(22)).foregroundStyle(picked == i ? LTColor.limeInk : LTColor.ink3)
                                .frame(width: 44, height: 44).background(picked == i ? Color.white : Color.white.opacity(0.07), in: Circle())
                            Text(t).font(LTFont.ui(20, weight: .heavy)).foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 14).frame(height: 76)
                        .background(picked == i ? Color.white.opacity(0.14) : LTColor.surface2, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(picked == i ? Color.white.opacity(0.5) : LTColor.hairline, lineWidth: 1))
                    }.buttonStyle(HVPress(scale: 0.98))
                }
            }.padding(.horizontal, 22).padding(.top, 36)
            Spacer()
        }
    }
}

struct OBWhyV134: View {
    var onNext: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("すぐ見ると、\n自分の顔ばかり\n気になってしまう。").font(LTFont.ui(34, weight: .heavy)).tracking(-0.8).foregroundStyle(.white).lineSpacing(4)
                .padding(.horizontal, 22).padding(.top, 36).accessibilityAddTraits(.isHeader)
            Text("だからLattagは、撮った写真をあしたの9:00まで見せません。撮り直しも、加工もできません。").font(LTFont.ui(17, weight: .heavy)).foregroundStyle(LTColor.ink2).lineSpacing(6)
                .padding(.horizontal, 22).padding(.top, 26)
            Spacer()
            Button { LTHaptics.play(.tap); onNext() } label: {
                Text("つぎへ").font(LTFont.ui(18, weight: .heavy)).foregroundStyle(LTColor.limeInk).frame(maxWidth: .infinity).frame(height: 58)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: LTRadius.button, style: .continuous))
            }.buttonStyle(HVPress(scale: 0.98)).padding(.horizontal, 16).padding(.bottom, 20)
        }
    }
}

/// 長押しで はじめる:大きい #レンズ(176)+ まわりに 刻印の 輪(ゆっくり まわる)+ 1.6秒。振動は だんだん 強く → 「ブイッ」
struct OBGoV134: View {
    var onProgress: (Double) -> Void
    var onFinish: () -> Void
    @State private var p = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let text = "3 SHOTS A DAY · OPENS AT 9:00 · FILM FOR TOMORROW · LATTAG · "

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(RadialGradient(colors: [LTColor.lime.opacity(0.28 + 0.4 * p), .clear], center: .center, startRadius: 0, endRadius: 190)).frame(width: 380, height: 380).allowsHitTesting(false)
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { ctx in
                    ring(angle: reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate * 6)
                }.frame(width: 250, height: 250).accessibilityHidden(true)
                Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1.5).frame(width: 214, height: 214)
                Circle().trim(from: 0, to: max(0.003, p)).stroke(Color.white, style: StrokeStyle(lineWidth: 3.5, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 214, height: 214)
                HashLensView(size: 176).scaleEffect(1 - 0.06 * p)
            }
            .contentShape(Circle())
            .holdToConfirm(duration: 1.6, progress: $p) { LTHaptics.play(.enter); onFinish() }
            .onChange(of: p) { _, v in onProgress(v) }
            .accessibilityElement(children: .ignore).accessibilityLabel("長押しで、はじめる").accessibilityAddTraits(.isButton)
            .accessibilityAction { LTHaptics.play(.enter); onFinish() }
            Text("長押しで、はじめる").font(LTFont.ui(17, weight: .heavy)).foregroundStyle(LTColor.ink2).padding(.top, 20)
            Spacer()
            Spacer()
        }
    }

    private func ring(angle: Double) -> some View {
        let chars = Array(text)
        return ZStack {
            ForEach(0..<chars.count, id: \.self) { i in
                Text(String(chars[i])).font(LTFont.stamp(8)).foregroundStyle(Color.white.opacity(0.32))
                    .offset(y: -118).rotationEffect(.degrees(Double(i) / Double(chars.count) * 360 + angle))
            }
        }
    }
}
