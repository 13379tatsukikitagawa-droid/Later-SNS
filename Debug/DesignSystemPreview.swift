#if DEBUG
import SwiftUI

/// 小さな プレビュー画面:書体 6つ ・ バイブ 15種類 ・ ガラス ・ 押せる ボタン を 確かめる。
struct DesignSystemPreview: View {
    private let kinds: [Haptics.Kind] = [.tick, .sel, .pop, .click, .soft, .thud, .warn, .success, .shutter, .land, .heart, .projector, .buzz, .rumble, .vui]
    @State private var big = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("書体").font(LGFont.mono(11)).foregroundStyle(.secondary)
                Text(Brand.name).font(LGFont.inter(900, 32)).tracking(-2.1)
                Text("Yesterday, together.").font(LGFont.serif(28, italic: true))
                Text("放課後クラブ ゆい").font(LGFont.serif(24))
                Text("GROUPS · NOV 12").font(LGFont.mono(12))
                Text("Yui ゆい").font(LGFont.hand(34))
                Text("ゆい").font(LGFont.mincho(30))
                Text("ゆい(Klee One)").font(LGFont.klee(20))
                if !LGFont.missingFonts().isEmpty { Text("未登録: \(LGFont.missingFonts().joined(separator: ", "))").foregroundStyle(.red) }

                Text("バイブ(実機のみ)").font(LGFont.mono(11)).foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(kinds, id: \.rawValue) { k in
                        Button(k.rawValue) { Haptics.play(k, gap: 0) }
                            .buttonStyle(.lgPressable(.sink, haptic: nil))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(LGColor.lime, in: Capsule())
                            .foregroundStyle(.black)
                            .font(LGFont.mono(12))
                    }
                }

                Text("ガラス ・ LGPressable").font(LGFont.mono(11)).foregroundStyle(.secondary)
                ZStack {
                    LinearGradient(colors: [LGColor.film, LGColor.lime, Color(hex: "EE5E9C")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    HStack(spacing: 14) {
                        Text("glass").font(LGFont.inter(800, 15)).padding(.horizontal, 22).frame(height: 44).lgGlass(radius: 22)
                        Button { big.toggle() } label: {
                            Text(big ? "pressed" : "press").font(LGFont.inter(800, 15)).padding(.horizontal, 22).frame(height: 44)
                        }
                        .buttonStyle(.lgPressable(.swell))
                        .lgGlass(radius: 22, interactive: true)
                    }
                }
                .frame(height: 140).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                Text("動き").font(LGFont.mono(11)).foregroundStyle(.secondary)
                HStack {
                    ForEach(LGMotion.all, id: \.name) { m in
                        Circle().fill(LGColor.film).frame(width: 26, height: 26)
                            .offset(x: big ? 18 : -18)
                            .animation(.timingCurve(m.curve.0, m.curve.1, m.curve.2, m.curve.3, duration: 0.6), value: big)
                    }
                }
            }
            .padding(16)
        }
    }
}
#endif
