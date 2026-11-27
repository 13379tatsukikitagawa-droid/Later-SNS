import SwiftUI

// v136:#レンズを 長押し → 下から 出る 招待カード。自分の きのう(ぼかし)・ # ・ 名前 ・ @ID ・ リンク。
// ボタン:LINEで送る(ライム)/ ストーリー(カードを 縦長の 画像にして 共有シートへ)/ コピー。小さく「写真を変える」→ 今の INVITE 画面。

enum InviteCardRulesV136 {
    /// LINE の 送る 画面を ひらく URL。LINE が 入って いない 端末では nil(→ 共有シートへ)。
    static func lineURL(text: String) -> URL? {
        let enc = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "line://msg/text/\(enc)")
    }
    /// カードに 出す リンク(https:// は かくす)
    static func displayLink(_ url: URL) -> String {
        url.absoluteString.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
    }
    /// 名前が ない 人にも カードは 作れる
    static func shownName(_ name: String) -> String { name.trimmingCharacters(in: .whitespaces).isEmpty ? "ともだち" : name }
}

/// 9:16。ストーリー用の 画像は これを 1080×1920 に 書きだす。
struct InviteCardArtV136: View {
    var name: String
    var handle: String
    var link: String
    var photo: UIImage?
    static let size = CGSize(width: 270, height: 480)

    var body: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill().frame(width: Self.size.width, height: Self.size.height).blur(radius: 28).scaleEffect(1.2)
            } else {
                LinearGradient(colors: [Color(hex6: 0x2A3A12), Color(hex6: 0x0B0B0D)], startPoint: .top, endPoint: .bottom)
            }
            LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.62)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 0) {
                HashLensView(size: 64, glowing: false).padding(.top, 54)
                Spacer()
                Text(InviteCardRulesV136.shownName(name)).font(LTFont.ui(30, weight: .heavy)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                if !handle.isEmpty { Text("@\(handle)").font(LTFont.ui(15, weight: .semibold)).foregroundStyle(.white.opacity(0.7)).padding(.top, 4) }
                Text("いっしょに、きのうを見せあおう").font(LTFont.ui(13)).foregroundStyle(.white.opacity(0.85)).padding(.top, 14)
                Text(link).font(LTFont.ui(11, weight: .semibold)).foregroundStyle(LTColor.limeInk).lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.horizontal, 12).frame(height: 26).background(LTColor.lime, in: Capsule()).padding(.top, 12)
                Spacer().frame(height: 44)
            }.padding(.horizontal, 18)
        }
        .frame(width: Self.size.width, height: Self.size.height).clipped()
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct InviteCardSheetV136: View {
    var name: String
    var handle: String
    var link: URL
    var text: String
    var photo: UIImage?
    var onChangePhoto: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var shareItems: [Any]?
    @State private var copied = false
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            InviteCardArtV136(name: name, handle: handle, link: InviteCardRulesV136.displayLink(link), photo: photo)
                .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                .scaleEffect(appear ? 1 : 0.92).opacity(appear ? 1 : 0)
                .padding(.top, 28)
                .accessibilityElement(children: .ignore).accessibilityLabel("\(InviteCardRulesV136.shownName(name))さんの招待カード")
            Spacer(minLength: 16)
            VStack(spacing: 10) {
                Button { LTHaptics.play(.tap); sendLine() } label: {
                    Label("LINEで送る", systemImage: "paperplane.fill").font(LTFont.ui(17, weight: .heavy)).foregroundStyle(LTColor.limeInk)
                        .frame(maxWidth: .infinity).frame(height: 54).background(LTColor.lime, in: RoundedRectangle(cornerRadius: LTRadius.button, style: .continuous))
                }.buttonStyle(HVPress(scale: 0.97))
                HStack(spacing: 10) {
                    secondary("square.and.arrow.up", "ストーリー") { LTHaptics.play(.tap); shareStory() }
                    secondary(copied ? "checkmark" : "link", copied ? "コピーしました" : "コピー") {
                        LTHaptics.play(.posted); UIPasteboard.general.string = text; copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    }
                }
                Button { LTHaptics.play(.tap); onChangePhoto() } label: {
                    Text("写真を変える").font(LTFont.ui(13, weight: .semibold)).foregroundStyle(LTColor.ink2).frame(height: 44).frame(maxWidth: .infinity)
                }.buttonStyle(.plain)
            }.padding(.horizontal, 18).padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity).background(Color(hex6: 0x0B0B0D).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { appear = true } }
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
            ShareSheet(activityItems: shareItems ?? []) { _ in shareItems = nil }.presentationDetents([.medium, .large])
        }
    }

    private func secondary(_ icon: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(LTFont.ui(15, weight: .heavy)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity).frame(height: 50).background(LTColor.surface3, in: RoundedRectangle(cornerRadius: LTRadius.button, style: .continuous))
        }.buttonStyle(HVPress(scale: 0.97))
    }

    private func sendLine() {
        if let u = InviteCardRulesV136.lineURL(text: text), UIApplication.shared.canOpenURL(u) { UIApplication.shared.open(u) }
        else { shareItems = [text] }
    }

    /// カードを 1080×1920 の 画像にして 共有シートへ(Instagram の ストーリーも ここから)
    private func shareStory() {
        let r = ImageRenderer(content: InviteCardArtV136(name: name, handle: handle, link: InviteCardRulesV136.displayLink(link), photo: photo))
        r.scale = 4
        if let img = r.uiImage { shareItems = [img, text] } else { shareItems = [text] }
    }
}
