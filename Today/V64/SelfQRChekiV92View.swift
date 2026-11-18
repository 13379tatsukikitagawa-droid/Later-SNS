import SwiftUI
import SwiftData
import MessageUI
import Photos

// v92:自分の QR = チェキ + # の 形。見本 F25 F26 F27 ・ 動き M32。タップで うらがえす(自分の 写真 + タグ)。

struct SelfQRChekiV92View: View {
    var name: String
    var username: String
    var link: String
    var photo: UIImage?
    var tags: [String]
    var since = "2026"
    var onScan: () -> Void = {}
    var onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fall = false
    @State private var dots = 0.0
    @State private var iconPop = false
    @State private var flipped = false
    @State private var tilt = CGSize.zero
    @State private var toast: String?
    @State private var flash = false
    @State private var sinking = false
    @State private var shareItems: [Any]?
    @State private var showsMessage = false
    @State private var rowsShown = false

    private let paper = Color(hex: "F4F1EA"), ink = Color(hex: "0B0C0D")
    private var matrix: [[Bool]] { QRMatrix.make(link) ?? [] }
    private static var dateStamp: String { let f = DateFormatter(); f.dateFormat = "yy MM dd"; return "'" + f.string(from: Date()) }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                HStack {
                    glassButton("xmark") { Haptics.play(.tick); onClose() }.accessibilityLabel("とじる")
                    Spacer()
                    glassButton("qrcode.viewfinder") { Haptics.play(.tick); onScan() }.accessibilityLabel("QR を 読む")
                }.padding(.horizontal, 16).padding(.top, 54)
                Spacer(minLength: 0)
                cheki
                    .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                    .rotation3DEffect(.degrees(Double(tilt.width) * 7), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                    .rotation3DEffect(.degrees(Double(-tilt.height) * 5), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
                    .rotationEffect(.degrees(fall || reduceMotion ? -2 : -9))
                    .scaleEffect(sinking ? 0.96 : (fall || reduceMotion ? 1 : 0.92))
                    .offset(y: fall || reduceMotion ? 8 : -90)
                    .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                        guard !reduceMotion else { return }
                        tilt = CGSize(width: max(-1, min(1, (v.location.x - 155) / 155)), height: max(-1, min(1, (v.location.y - 226) / 226)))
                    }.onEnded { _ in withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { tilt = .zero } })
                    .onTapGesture { Haptics.play(flipped ? .sel : .pop); withAnimation(.easeInOut(duration: 0.55)) { flipped.toggle() } }
                    .accessibilityAddTraits(.isButton).accessibilityLabel("チェキ。タップで うらがえす")
                Text(flipped ? "もう1回 タップで QR" : "タップで うらがえす").font(LF.inter(600, 12)).foregroundStyle(.white.opacity(0.45)).padding(.top, 14)
                ZStack {
                    if let toast { Label(toast, systemImage: "checkmark").font(LF.inter(700, 13)).foregroundStyle(.white).padding(.horizontal, 16).frame(height: 34).background(.ultraThinMaterial, in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1)).transition(.opacity) }
                }.frame(height: 40)
                Spacer(minLength: 0)
                actions.padding(.horizontal, 10).padding(.bottom, 40)
            }
            if flash { Color.white.ignoresSafeArea().allowsHitTesting(false).transition(.opacity) }
        }
        .environment(\.colorScheme, .dark)
        .onAppear(perform: begin)
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) { ShareSheet(activityItems: shareItems ?? []) { _ in shareItems = nil }.presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showsMessage) { MessageComposeV92(body: "Lattag で つながろう \(link)", image: exportImage()) { showsMessage = false }.ignoresSafeArea() }
    }

    private var background: some View {
        GeometryReader { g in
            ZStack {
                Color(hex: "0B0C0D")
                Circle().fill(RadialGradient(colors: [HV.lime.opacity(0.14), .clear], center: .center, startRadius: 0, endRadius: g.size.width * 0.4)).frame(width: g.size.width * 0.8, height: g.size.width * 0.8).scaleEffect(x: 1, y: 0.9).position(x: g.size.width / 2, y: g.size.height * 0.38)
                Circle().fill(RadialGradient(colors: [Color(hex: "24A03C").opacity(0.32), .clear], center: .center, startRadius: 0, endRadius: g.size.width * 0.6)).frame(width: g.size.width * 1.2, height: g.size.width * 1.2).scaleEffect(x: 1, y: 0.55).position(x: g.size.width / 2, y: g.size.height)
            }.frame(width: g.size.width, height: g.size.height).clipped()
        }.ignoresSafeArea()
    }

    private func glassButton(_ icon: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) { Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(.white).frame(width: 48, height: 48).background(.white.opacity(0.1), in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1)) }.buttonStyle(HVPress(scale: 0.92))
    }

    // MARK: チェキ

    private var cheki: some View {
        ZStack {
            front.opacity(flipped ? 0 : 1)
            back.opacity(flipped ? 1 : 0).rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
    }

    private func paperBase(@ViewBuilder _ content: () -> some View) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(paper)
            Canvas { c, s in
                var y: CGFloat = 2
                while y < s.height { var x: CGFloat = 2; while x < s.width { c.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.black.opacity(0.035))); x += 5 }; y += 5 }
            }.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous)).allowsHitTesting(false)
            content()
            Rectangle().fill(HV.lime.opacity(0.85)).frame(width: 92, height: 28).rotationEffect(.degrees(-38))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(.leading, -14).padding(.top, 2).allowsHitTesting(false)
        }
        .frame(width: 310, height: 452)
        .shadow(color: .black.opacity(0.7), radius: 30, y: 24)
    }

    private var front: some View {
        paperBase {
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color(hex: "FBFAF6"))
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
                    StyledQRView(matrix: matrix, progress: reduceMotion ? 1 : dots)
                }.frame(height: 274).padding(.horizontal, 18).padding(.top, 66)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name).font(ChekiFont.hand(30)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.5).rotationEffect(.degrees(-2))
                        Text("@\(username)").font(LF.mono(11)).tracking(0.9).foregroundStyle(ink.opacity(0.55)).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text(Self.dateStamp).font(LF.mono(12)).foregroundStyle(Color(hex: "1F8F37"))
                }.padding(.horizontal, 20).frame(maxHeight: .infinity)
            }
            .overlay(alignment: .top) {
                OPIcon(size: 92, lensScale: 1).clipShape(Circle()).padding(6).background(paper, in: Circle())
                    .scaleEffect(iconPop || reduceMotion ? 1 : 0.01).padding(.top, -52)
            }
        }
    }

    private var back: some View {
        paperBase {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    if let photo { Image(uiImage: photo).resizable().scaledToFill() } else { LinearGradient(colors: [Color(hex: "61D278"), Color(hex: "EE5E9C")], startPoint: .topLeading, endPoint: .bottomTrailing).overlay(Text(String(name.prefix(1))).font(LF.inter(900, 110)).foregroundStyle(.white.opacity(0.9))) }
                    HStack(spacing: 6) { ForEach(Array(tags.prefix(3).enumerated()), id: \.offset) { i, t in
                        Text("#\(t)").font(LF.inter(900, 13)).foregroundStyle(i == 1 ? .white : ink).padding(.horizontal, 10).frame(height: 28).background([HV.lime, Color(hex: "EE5E9C"), Color(hex: "9ED8FF")][i % 3], in: RoundedRectangle(cornerRadius: 10, style: .continuous)).rotationEffect(.degrees([-5, 4, -3][i % 3]))
                    } }.padding(10)
                }.frame(width: 274, height: 300).clipped().padding(.top, 20)
                VStack(alignment: .leading, spacing: 6) {
                    Text(name).font(ChekiFont.hand(30)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.5).rotationEffect(.degrees(-2))
                    Text("LATTAG ・ SINCE \(since)").font(LF.mono(10.5)).tracking(1.5).foregroundStyle(ink.opacity(0.55))
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).frame(maxHeight: .infinity)
            }
        }
    }

    // MARK: 下の 5つ

    private var actions: some View {
        HStack(spacing: 0) {
            action("コピー", "doc.on.doc", nil) { UIPasteboard.general.string = link; Haptics.play(.success); say("コピーしました") }
            action("LINE", "bubble.left.fill", Color(hex: "06C755")) { openLine() }
            action("メッセージ", "message.fill", Color(hex: "34C759")) { if MFMessageComposeViewController.canSendText() { showsMessage = true } else { shareItems = ["Lattag で つながろう \(link)"] } }
            action("保存", "arrow.down.to.line", nil) { save() }
            action("その他", "ellipsis", nil) { shareItems = [exportImage() as Any, URL(string: link) as Any].compactMap { $0 } }
        }
    }

    private func action(_ t: String, _ icon: String, _ tint: Color?, _ a: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); a() } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white).frame(width: 58, height: 58).background(tint ?? Color.white.opacity(0.1), in: Circle())
                Text(t).font(LF.inter(700, 12)).foregroundStyle(.white.opacity(0.85)).lineLimit(1).minimumScaleFactor(0.7)
            }.frame(maxWidth: .infinity)
        }.buttonStyle(HVPress(scale: 0.94))
            .offset(y: rowsShown || reduceMotion ? 0 : 30).opacity(rowsShown || reduceMotion ? 1 : 0)
    }

    private func say(_ m: String) {
        withAnimation { toast = m }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { withAnimation { toast = nil } }
    }

    private func openLine() {
        let enc = "Lattag で つながろう \(link)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let u = URL(string: "line://msg/text/\(enc)"), UIApplication.shared.canOpenURL(u) { UIApplication.shared.open(u) }
        else { shareItems = ["Lattag で つながろう \(link)"] }
    }

    /// チェキ ぜんぶを 画像に(3倍)
    private func exportImage() -> UIImage? {
        let content = front.padding(30).environment(\.colorScheme, .dark)
        let r = ImageRenderer(content: content)
        r.scale = 3
        return r.uiImage
    }

    private func save() {
        guard let img = exportImage() else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else { Haptics.play(.warn); say("写真への 保存が 許可されていません"); return }
                PHPhotoLibrary.shared().performChanges({ PHAssetChangeRequest.creationRequestForAsset(from: img) }) { ok, _ in
                    DispatchQueue.main.async {
                        guard ok else { Haptics.play(.warn); say("保存できませんでした"); return }
                        Haptics.play(.shutter)
                        withAnimation(.easeOut(duration: 0.15)) { sinking = true; flash = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { withAnimation(.easeOut(duration: 0.3)) { flash = false; sinking = false } }
                        say("チェキを 写真に 保存しました")
                    }
                }
            }
        }
    }

    private func begin() {
        guard !reduceMotion else { fall = true; iconPop = true; dots = 1; rowsShown = true; return }
        Haptics.play(.pop)
        withAnimation(.timingCurve(0.3, 1.2, 0.4, 1, duration: 0.62)) { fall = true }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55).delay(0.3)) { iconPop = true }
        withAnimation(.linear(duration: 0.78).delay(0.26)) { dots = 1 }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.38)) { rowsShown = true }
        for t in [0.38, 0.56, 0.74] { DispatchQueue.main.asyncAfter(deadline: .now() + t) { Haptics.play(.tick) } }
    }
}

/// 自分の プロフィールを 読んで チェキを 出す(どこからでも 使える)
struct SelfQRChekiHost: View {
    var onScan: () -> Void = {}
    var onClose: () -> Void
    @Query private var profiles: [UserProfile]
    private var me: UserProfile? { UserProfile.current(from: profiles) }
    private var recordName: String? { CloudKitManager.current?.currentUserRecordName }

    var body: some View {
        let user = me
        let rn = recordName ?? user?.cloudKitUserRecordName ?? user?.username ?? ""
        let since: String = { let f = DateFormatter(); f.dateFormat = "yyyy"; return f.string(from: user?.photos.map(\.captureDate).min() ?? Date()) }()
        SelfQRChekiV92View(name: user?.name ?? "", username: user?.username ?? "", link: FriendRules.link(recordName: rn).absoluteString,
                           photo: user?.profileImageData.flatMap { UIImage(data: $0) }, tags: user?.selfTags ?? [], since: since, onScan: onScan, onClose: onClose)
    }
}

struct MessageComposeV92: UIViewControllerRepresentable {
    var body: String
    var image: UIImage?
    var onDone: () -> Void
    func makeCoordinator() -> Coord { Coord(onDone) }
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let c = MFMessageComposeViewController()
        c.body = body
        if let d = image?.pngData() { c.addAttachmentData(d, typeIdentifier: "public.png", filename: "lattag-qr.png") }
        c.messageComposeDelegate = context.coordinator
        return c
    }
    func updateUIViewController(_ vc: MFMessageComposeViewController, context: Context) {}
    final class Coord: NSObject, MFMessageComposeViewControllerDelegate {
        let done: () -> Void
        init(_ d: @escaping () -> Void) { done = d }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) { done() }
    }
}
