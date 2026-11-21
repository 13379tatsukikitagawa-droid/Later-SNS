import SwiftUI
import Photos

// v98 ① Trip パス(T16 T17 T18 ・ M39)。パスは 1つの 部品。表紙は clipped + clipShape で 枠の 外へ 出さない。
// 作られる 時(newlyMade)だけ:プリンターの 口から 6段で 出てくる → QR の 点 → ISSUED の はんこ → ボタン。
// 写真に 保存:ImageRenderer(scale 3)→ PHPhotoLibrary(追加 だけ の 許可)。

/// Trip の 招待 URL(`https://later-app-f2606.firebaseapp.com/t/<key>`)。QR の 中身。
enum TripKeyLink {
    static func url(forKey key: String) -> String {
        "https://\(Brand.domain)/t/\(key.hasPrefix("#") ? String(key.dropFirst()) : key)"
    }

    /// `https://later-app-f2606.firebaseapp.com/t/<key>` から key。ちがう URL なら nil
    static func key(from text: String) -> String? {
        guard let url = URL(string: text), case .trip(let token)? = AppLinks.parse(url) else { return nil }   // v108:どの ドメインでも
        return token
    }
}

struct TripPassView: View {
    var data: TripPassData
    var newlyMade = false
    /// 写真に 保存する ための 絵(ボタン ・ 動きなし)
    var forExport = false
    var onStart: () -> Void = {}
    var onClose: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shareItems: [Any]?
    @State private var copied = false
    @State private var saved = false
    @State private var deniedAlert = false
    @State private var flash = false
    @State private var sink = false
    @State private var step = 6            // 0〜6:パスが 出てくる 段
    @State private var qrProgress = 1.0
    @State private var stamped = true
    @State private var stampScale = 1.0
    @State private var lampDone = true
    @State private var buttonsIn = true
    @State private var fade = false        // あとで ひらく 時の ふわっと
    @State private var run: Task<Void, Never>?

    private static let passH: CGFloat = 250 + 170

    private var keyParts: (String, String) {
        let k = data.key.hasPrefix("#") ? String(data.key.dropFirst()) : data.key
        let digits = String(k.reversed().prefix(while: \.isNumber).reversed())
        return ("#" + String(k.dropLast(digits.count)), digits)
    }
    private var passNo: String {
        let h = data.key.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 9000 }
        return "No.\(1000 + h)"
    }
    private var issued: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "MMM dd"
        return f.string(from: Date()).uppercased()
    }
    private var qrText: String { data.key.isEmpty ? data.link : TripKeyLink.url(forKey: data.key) }
    private var animates: Bool { newlyMade && !reduceMotion && !forExport }

    var body: some View {
        ZStack {
            Color(hex: "0B0B0C").ignoresSafeArea()
            RadialGradient(colors: [Color(hex: "C8F25A").opacity(0.14), .clear], center: UnitPoint(x: 0.5, y: 0.12), startRadius: 0, endRadius: 300)
                .frame(maxWidth: .infinity, maxHeight: .infinity).ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 0) {
                header
                slot
                window
                if !forExport {
                    actions
                    startButton
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, forExport ? 24 : 60)
            .padding(.bottom, forExport ? 24 : 30)
            .scaleEffect(sink ? 0.975 : 1)
            .opacity(fade ? 0 : 1)
            .offset(y: fade ? 24 : 0)
            Color.white.opacity(flash ? 0.85 : 0).ignoresSafeArea().allowsHitTesting(false)
        }
        .onAppear(perform: begin)
        .onDisappear { run?.cancel() }
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
            ShareSheet(activityItems: shareItems ?? []) { _ in shareItems = nil }.presentationDetents([.medium, .large])
        }
        .alert("設定で 写真を ゆるして ください", isPresented: $deniedAlert) {
            Button("設定を ひらく") { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
            Button("やめる", role: .cancel) {}
        } message: { Text("Trip の パスを 写真に 保存します") }
    }

    // MARK: 上

    private var header: some View {
        HStack(spacing: 7) {
            Circle().fill(Color(hex: "C8F25A")).frame(width: 6, height: 6)
            Text(newlyMade ? "YOUR TRIP IS READY" : "TRIP PASS").font(LF.mono(10.5)).tracking(2.5).foregroundStyle(Color(hex: "C8F25A"))
        }
    }

    /// プリンターの 口(高さ 26)。ランプは 印刷中 オレンジ → できたら ライム
    private var slot: some View {
        HStack(spacing: 8) {
            Circle().fill(lampDone ? Color(hex: "C8F25A") : Color(hex: "FF7A2F")).frame(width: 7, height: 7)
                .shadow(color: (lampDone ? Color(hex: "C8F25A") : Color(hex: "FF7A2F")), radius: 4)
            Text(lampDone ? "LATTAG" : "PRINTING").font(LF.mono(9)).tracking(2.2).foregroundStyle(Color(hex: "6E6E75"))
        }
        .frame(maxWidth: .infinity).frame(height: 26)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color(hex: "1A1A1D")))
        .shadow(color: .black.opacity(0.6), radius: 7, y: 6)
        .padding(.top, 14)
        .zIndex(3)
    }

    // MARK: パス

    private var window: some View {
        ZStack(alignment: .top) {
            pass
                .offset(y: -Self.passH * (1 - CGFloat(step) / 6))
                .padding(.top, 20)
        }
        .frame(height: Self.passH + 20, alignment: .top)
        .frame(maxWidth: .infinity)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 24, bottomTrailingRadius: 24, topTrailingRadius: 0, style: .continuous))
        .padding(.horizontal, 7)
        .padding(.top, -12)
        .overlay(alignment: .topTrailing) { stamp.padding(.trailing, 13).padding(.top, 46) }
    }

    private var pass: some View {
        VStack(spacing: 0) {
            top
            ZStack {
                Color(hex: "F4F1EA")
                Path { p in p.move(to: CGPoint(x: 14, y: 0)); p.addLine(to: CGPoint(x: 400, y: 0)) }
                    .stroke(Color(hex: "CFC8B8"), style: StrokeStyle(lineWidth: 2, dash: [5, 4])).frame(height: 2).padding(.horizontal, 0)
            }.frame(height: 0).overlay(alignment: .leading) {
                Circle().fill(Color(hex: "0B0B0C")).frame(width: 22, height: 22).offset(x: -11)
            }.overlay(alignment: .trailing) {
                Circle().fill(Color(hex: "0B0B0C")).frame(width: 22, height: 22).offset(x: 11)
            }.zIndex(1)
            bottom
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.9), radius: 24, y: 24)
    }

    private var top: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: "2A2326")
            if let c = data.cover {
                Color.clear.overlay(Image(uiImage: c).resizable().scaledToFill()).clipped()
            } else {
                LinearGradient(colors: [Color(hex: "2A2A2E"), Color(hex: "0E0E10")], startPoint: .top, endPoint: .bottom)
            }
            if data.cover == nil {
                HV72HashShape().fill(Color(hex: "C8F25A").opacity(0.9)).frame(width: 150, height: 150).offset(x: 190, y: 60)
            }
            LinearGradient(stops: [.init(color: .black.opacity(0.45), location: 0), .init(color: .black.opacity(0.05), location: 0.35),
                                   .init(color: .black.opacity(0.2), location: 0.6), .init(color: .black.opacity(0.8), location: 1)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 0) {
                HStack { Text("LATTAG"); Spacer(); Text("TRIP PASS ・ \(passNo)") }
                    .font(LF.mono(9)).tracking(1.8).foregroundStyle(.white.opacity(0.9))
                Text(data.name).font(LF.inter(900, 32)).tracking(-1).lineLimit(1).minimumScaleFactor(0.6).foregroundStyle(.white).padding(.top, 52)
                if !data.sub.isEmpty, data.sub != data.name { Text(data.sub).font(LF.serif(18, italic: true)).foregroundStyle(.white.opacity(0.85)).lineLimit(1) }
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) { Text("FROM").font(LF.mono(8)).tracking(1.4).opacity(0.7); Text(data.from).font(LF.mono(15)) }
                    Image(systemName: "arrow.right").font(.system(size: 13, weight: .regular)).opacity(0.7).padding(.bottom, 3)
                    VStack(alignment: .leading, spacing: 2) { Text("TO").font(LF.mono(8)).tracking(1.4).opacity(0.7); Text(data.to).font(LF.mono(15)) }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 2) { Text("DAYS").font(LF.mono(8)).tracking(1.4).opacity(0.7); Text("\(data.days)").font(LF.inter(900, 26)) }
                }.foregroundStyle(.white)
                HStack(spacing: 8) {
                    HStack(spacing: -6) {
                        ForEach(Array(data.members.prefix(4).enumerated()), id: \.offset) { i, m in
                            TripTicket(draft: TripDraft(), cover: nil, members: []).memberDot(m, data.names[safe: i] ?? "", 24)
                                .overlay(Circle().strokeBorder(Color(hex: "111111"), lineWidth: 2))
                        }
                    }
                    Text("\(data.members.count) / 8 ・ 1日 23枚").font(LF.mono(10))
                }.foregroundStyle(.white).padding(.top, 10)
            }.padding(.horizontal, 18).padding(.vertical, 16)
        }
        .frame(height: 250)
        .clipped()
    }

    private var bottom: some View {
        HStack(spacing: 14) {
            Group {
                if let m = QRMatrix.make(qrText) {
                    StyledQRView(matrix: m, progress: qrProgress, side: 124, paper: Color(hex: "FBFAF6"), coverImage: data.cover)
                } else { Color.clear }
            }
            .frame(width: 124, height: 124).padding(6)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex: "FBFAF6")))
            VStack(alignment: .leading, spacing: 0) {
                Text("KEY").font(LF.mono(9)).tracking(2.2).foregroundStyle(Color(hex: "8A857B"))
                (Text(keyParts.0).foregroundColor(Color(hex: "0B0C0D")) + Text(keyParts.1).foregroundColor(Color(hex: "5E8A12")))
                    .font(LF.inter(900, 26)).tracking(-0.8).lineLimit(2).minimumScaleFactor(0.6).padding(.top, 2)
                Text("SCAN TO JOIN\nあした 9:00 に 現像").font(LF.mono(8.5)).tracking(1).lineSpacing(3).foregroundStyle(Color(hex: "8A857B")).padding(.top, 8)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 18).padding(.trailing, 26).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 170)
        .background(Color(hex: "F4F1EA"))
        .overlay(alignment: .trailing) {
            Canvas { c, s in
                var y: CGFloat = 0, lime = true
                while y < s.height { c.fill(Path(CGRect(x: 0, y: y, width: s.width, height: min(6, s.height - y))), with: .color(Color(hex: lime ? "C8F25A" : "5E8A12"))); y += 6; lime.toggle() }
            }.frame(width: 8)
        }
    }

    private var stamp: some View {
        VStack(spacing: 0) {
            Text("ISSUED").font(LF.mono(9)).tracking(1.8)
            Text(issued).font(LF.inter(900, 13))
        }
        .foregroundStyle(Color(hex: "C8F25A"))
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: "0B0B0C").opacity(0.55)))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color(hex: "C8F25A"), lineWidth: 2.5))
        .rotationEffect(.degrees(-14))
        .scaleEffect(stampScale)
        .opacity(stamped ? 1 : 0)
        .allowsHitTesting(false)
    }

    // MARK: ボタン

    private var actions: some View {
        HStack(spacing: 8) {
            passButton("square.and.arrow.up", "送る", 0) {
                let dates = [ShareTextV108.shortDate(data.from), ShareTextV108.shortDate(data.to)].compactMap { $0 }
                let range = dates.count == 2 ? "\(dates[0])〜\(dates[1])" : nil
                shareItems = data.key.isEmpty ? [LattagShareItem.trip(text: "\(data.name) に きて ね\n\(data.link)", groupName: data.name)] : [LattagShareItem.trip(text: ShareTextV108.trip(host: ShareTextV108.me.name, name: data.name, dates: range, members: data.names.count, key: data.key), groupName: data.name)]
            }
            passButton(saved ? "checkmark" : "arrow.down.to.line", saved ? "保存しました" : "写真に 保存", 1, ok: saved) { Task { await savePass() } }
            passButton("doc.on.doc", copied ? "コピー ずみ" : "KEY を コピー", 2, ok: copied) {
                UIPasteboard.general.string = data.key; copied = true; Haptics.play(.success)
            }
        }
        .padding(.top, 16)
    }

    private func passButton(_ icon: String, _ title: String, _ i: Int, ok: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); action() } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(Color(hex: "C8F25A"))
                Text(title).font(LF.inter(800, 11.5)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(ok ? Color(hex: "C8F25A") : .white)
            .frame(maxWidth: .infinity).frame(height: 64)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(ok ? Color(hex: "C8F25A").opacity(0.12) : Color(hex: "17171A")))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(ok ? Color(hex: "C8F25A").opacity(0.5) : .white.opacity(0.07), lineWidth: ok ? 1.5 : 1))
        }
        .buttonStyle(HVPress(scale: 0.95))
        .opacity(buttonsIn ? 1 : 0).offset(y: buttonsIn ? 0 : 18)
        .animation(reduceMotion ? nil : .timingCurve(0.2, 0.9, 0.25, 1, duration: 0.4).delay(Double(i) * 0.06), value: buttonsIn)
    }

    private var startButton: some View {
        Button { Haptics.play(.click); onStart() } label: {
            Text(newlyMade ? "Trip を はじめる" : "とじる").font(LF.inter(900, 16.5)).foregroundStyle(Color(hex: "111111"))
                .frame(maxWidth: .infinity).frame(height: 58).background(Capsule().fill(Color(hex: "C8F25A")))
        }
        .buttonStyle(HVPress(scale: 0.98)).padding(.top, 10)
        .opacity(buttonsIn ? 1 : 0).offset(y: buttonsIn ? 0 : 18)
        .animation(reduceMotion ? nil : .timingCurve(0.2, 0.9, 0.25, 1, duration: 0.4).delay(0.18), value: buttonsIn)
    }

    // MARK: 動き(M39)

    private func begin() {
        guard !forExport else { return }
        if animates {
            step = 0; qrProgress = 0; stamped = false; stampScale = 2.2; lampDone = false; buttonsIn = false
            run = Task { @MainActor in await runPrint() }
        } else if !reduceMotion {
            // あとで ひらく 時:下から ふわっと(0.52秒)
            fade = true
            withAnimation(.timingCurve(0.2, 0.8, 0.25, 1, duration: 0.52)) { fade = false }
        }
    }

    @MainActor private func runPrint() async {
        func wait(_ s: Double) async -> Bool { try? await Task.sleep(for: .seconds(s)); return !Task.isCancelled }
        Haptics.play(.projector)
        for i in 1...6 {
            guard await wait(0.22) else { return }
            step = i; Haptics.play(.tick)          // 6段で カクカク
        }
        guard await wait(0.0) else { return }
        withAnimation(.linear(duration: 0.55)) { qrProgress = 1 }   // 1.25〜1.8秒の あたり(まんなか から 外へ)
        guard await wait(0.65) else { return }
        stamped = true
        withAnimation(.timingCurve(0.3, 1.4, 0.5, 1, duration: 0.3)) { stampScale = 1 }
        Haptics.play(.thud)
        guard await wait(0.12) else { return }
        lampDone = true
        buttonsIn = true
        Haptics.play(.success)
    }

    // MARK: 写真に 保存

    @MainActor private func savePass() async {
        guard !saved else { return }
        let renderer = ImageRenderer(content: TripPassView(data: data, newlyMade: false, forExport: true).frame(width: 390, height: 520))
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { deniedAlert = true; Haptics.play(.warn); return }
        do {
            try await PHPhotoLibrary.shared().performChanges { PHAssetCreationRequest.creationRequestForAsset(from: image) }
        } catch { deniedAlert = true; Haptics.play(.warn); return }
        Haptics.play(.shutter)
        saved = true
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.05)) { flash = true; sink = true }
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(.easeOut(duration: 0.42)) { flash = false }
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { sink = false }
        }
    }
}
