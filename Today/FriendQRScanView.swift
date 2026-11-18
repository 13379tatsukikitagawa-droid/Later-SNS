import SwiftUI
import UIKit
import PhotosUI
import SwiftData

/// v94 D:QR を 読む = Lattag の カメラ(F10 F35 ・ M36)。
/// 友だちの QR(later://friend?u=… / https://lattag.app/u/<id>)を 読む → 下から プロフィールの カード → 申請する。
/// Lattag の QR では ない ものは 断る。グループ参加の QRScanView には さわらない。
struct FriendQRScanView: View {
    let myName: String
    let friendCount: Int
    var friendIDs: Set<String> = []
    var myUsername = ""
    var onSearchID: (() -> Void)? = nil
    let onToast: (String) -> Void
    @Query private var profiles: [UserProfile]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var camera = QRScanCamera()
    @State private var found: UserDirectoryService.DirectoryProfile?
    @State private var foundRecord: String?
    @State private var locked = false
    @State private var showsCard = false
    @State private var showsMine = false
    @State private var notLattag = false
    @State private var lastRejected: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var sent = false
    @State private var sending = false

    private let lime = HV.lime
    private let side: CGFloat = 282   // v95-5:上 206 ・ 282 × 282

    var body: some View {
        GeometryReader { g in
            ZStack {
                if camera.access == .denied || camera.access == .unavailable { deniedView }
                else {
                    QRCameraPreview(camera: camera).ignoresSafeArea()
                    dim(g)
                    frame.position(x: g.size.width / 2, y: 206 + side / 2)
                    status.position(x: g.size.width / 2, y: 206 + side + 24 + 10)
                    VStack { topBar; Spacer(); bottomButtons }.padding(.horizontal, 16).padding(.top, 54).padding(.bottom, 40)
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .background(Color.black).ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.code) { _, code in checkCode(code) }
        .onChange(of: photoItem) { _, item in readPhoto(item) }
        .fullScreenCover(isPresented: $showsMine) { SelfQRChekiHost(onScan: { showsMine = false }, onClose: { showsMine = false }) }
        .sheet(isPresented: $showsCard, onDismiss: { if !sent { locked = false; found = nil; camera.isPaused = false } }) { card }
    }

    // MARK: 上

    private var topBar: some View {
        HStack {
            glass("xmark") { Haptics.play(.tick); dismiss() }.accessibilityLabel("とじる")
            Spacer()
            Text("QR を 読む").font(LF.inter(800, 17)).foregroundStyle(.white)
            Spacer()
            if camera.hasTorch { glass(camera.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill", tint: camera.isTorchOn) { Haptics.play(.click); camera.setTorch(!camera.isTorchOn) }.accessibilityLabel("ライト") }
            else { Color.clear.frame(width: 46, height: 46) }
        }
    }

    private func glass(_ icon: String, tint: Bool = false, _ a: @escaping () -> Void) -> some View {
        Button(action: a) { Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(tint ? HV.ink : .white).frame(width: 46, height: 46).background(tint ? AnyShapeStyle(lime) : AnyShapeStyle(.ultraThinMaterial), in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1)) }.buttonStyle(HVPress(scale: 0.92))
    }

    // MARK: わく

    private func dim(_ g: GeometryProxy) -> some View {
        Color.black.opacity(0.55).ignoresSafeArea()
            .mask { Rectangle().ignoresSafeArea().overlay { RoundedRectangle(cornerRadius: 40, style: .continuous).frame(width: side, height: side).position(x: g.size.width / 2, y: 206 + side / 2).blendMode(.destinationOut) }.compositingGroup() }
            .allowsHitTesting(false)
    }

    private var frame: some View {
        let inset: CGFloat = locked ? 42 : 0
        return ZStack {
            LensCorners().stroke(lime, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)).shadow(color: lime.opacity(0.7), radius: 8)
                .frame(width: side - inset * 2, height: side - inset * 2)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: locked)
            if !locked {
                HashOutlineShape().stroke(lime.opacity(0.16), lineWidth: 6).blur(radius: 1.5).frame(width: side * 0.62, height: side * 0.62)
                TimelineView(.animation(paused: reduceMotion)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.6) / 3.6
                    let k = reduceMotion ? 0.5 : (t < 0.5 ? t * 2 : (1 - t) * 2)
                    LinearGradient(colors: [.clear, lime.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom).frame(width: side - 36, height: 46).offset(y: (k - 0.5) * (side - 46 - 20))
                }.frame(width: side, height: side).clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            } else {
                Image(systemName: "checkmark").font(.system(size: 26, weight: .black)).foregroundStyle(HV.ink).frame(width: 64, height: 64).background(lime, in: Circle()).transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }.frame(width: side, height: side).animation(.spring(response: 0.4, dampingFraction: 0.6), value: locked)
    }

    private var status: some View {
        HStack(spacing: 8) {
            if !notLattag { PulseDot(color: lime) }
            Text(notLattag ? "Lattag の QR では ありません" : (locked ? "見つけた" : "友だちの QR を わくに")).font(LF.inter(700, 14)).foregroundStyle(notLattag ? Color(hex: "FF453A") : .white)
        }
    }

    private var bottomButtons: some View {
        VStack(spacing: 18) {
            Text("画面 でも 紙 でも 読めます ・ 暗い 時は ライト").font(LF.inter(500, 12)).foregroundStyle(.white.opacity(0.55))
            HStack(alignment: .center) {
                PhotosPicker(selection: $photoItem, matching: .images) { roundLabel("photo", "写真から") }
                Spacer()
                Button { Haptics.play(.click); showsMine = true } label: { miniCheki }.buttonStyle(HVPress(scale: 0.95)).accessibilityLabel("自分の QR")
                Spacer()
                Button { Haptics.play(.click); if let onSearchID { dismiss(); onSearchID() } else { onToast("Friends の さがすで @ID") } } label: { roundLabel("at", "@ID") }.buttonStyle(HVPress(scale: 0.92))
            }
            .padding(.horizontal, 24)
        }
    }

    private func roundLabel(_ icon: String, _ t: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(.white).frame(width: 56, height: 56)
                .background(.ultraThinMaterial, in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
            Text(t).font(LF.inter(700, 11)).foregroundStyle(.white.opacity(0.7))
        }
    }

    /// 小さな チェキ(84 × 96 ・ -4°)の 中に 本物の QR
    private var miniCheki: some View {
        let me = UserProfile.current(from: profiles)
        let rn = CloudKitManager.current?.currentUserRecordName ?? me?.cloudKitUserRecordName ?? me?.username ?? ""
        let m = QRMatrix.make(FriendRules.link(recordName: rn).absoluteString)
        return VStack(spacing: 4) {
            Group { if let m { StyledQRView(matrix: m, side: 64) } else { Color.clear } }.frame(width: 64, height: 64)
            Text("自分の QR").font(LF.inter(800, 9.5)).foregroundStyle(Color(hex: "1A1A1C"))
        }
        .padding(10).frame(width: 84, height: 96)
        .background(Color(hex: "F4F1EA"), in: RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
        .rotationEffect(.degrees(-4))
    }

    private func bigButton(_ icon: String, _ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) { HStack(spacing: 8) { Image(systemName: icon).font(.system(size: 16, weight: .bold)); Text(t).font(LF.inter(800, 15)) }.foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 56).background(.ultraThinMaterial, in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1)) }.buttonStyle(HVPress(scale: 0.97))
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            HStack { glass("xmark") { dismiss() }; Spacer() }.padding(.horizontal, 16).padding(.top, 54)
            Spacer()
            Image(systemName: "video.slash").font(.system(size: 30)).foregroundStyle(.white.opacity(0.85))
            Text("カメラが つかえません").font(LF.inter(800, 18)).foregroundStyle(.white)
            Text("友だちの QR を 読むには カメラの 許可が いります").font(LF.inter(600, 13)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center).padding(.horizontal, 30)
            Button { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } } label: { Text("設定を ひらく").font(LF.inter(800, 15)).foregroundStyle(HV.ink).padding(.horizontal, 24).frame(height: 48).background(lime, in: Capsule()) }.buttonStyle(.plain)
            Spacer()
        }
    }

    // MARK: 見つけた → カード

    private var card: some View {
        let p = found
        let isFriend = p.flatMap { $0.cloudKitUserRecordName }.map { friendIDs.contains($0) } ?? false
        let ink = Color(hex: "0B0C0D")
        return VStack(spacing: 0) {
            ZStack {
                if let d = p?.avatarData, let i = UIImage(data: d) { Image(uiImage: i).resizable().scaledToFill() }
                else { Circle().fill(LinearGradient(colors: [Color(hex: "61D278"), Color(hex: "EE5E9C")], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay(Text(String((p?.name ?? "?").prefix(1))).font(LF.inter(900, 34)).foregroundStyle(.white)) }
            }.frame(width: 84, height: 84).clipShape(Circle()).overlay(Circle().strokeBorder(lime, lineWidth: 2).padding(-4)).overlay(Circle().strokeBorder(Color(hex: "F4F1EA"), lineWidth: 5).padding(-9)).padding(.top, 38)
            Text(p?.name ?? "").font(ChekiFont.hand(30)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.6).padding(.top, 20)
            Text("@\(p?.username ?? "")").font(LF.mono(13)).foregroundStyle(ink.opacity(0.55)).padding(.top, 2)
            Text("QR から").font(LF.inter(600, 12.5)).foregroundStyle(ink.opacity(0.45)).padding(.top, 8)
            Button { request() } label: {
                Text(isFriend ? "もう 友だち" : (sent ? "✓ 申請しました" : (sending ? "送って います…" : "申請する"))).font(LF.inter(800, 17)).foregroundStyle(sent ? HV.ink : lime).frame(maxWidth: .infinity).frame(height: 56)
                    .background(sent ? lime : ink, in: Capsule())
            }.buttonStyle(HVPress(scale: 0.97)).disabled(isFriend || sent || sending || found?.cloudKitUserRecordName == nil).padding(.horizontal, 24).padding(.top, 20)
            Button { Haptics.play(.tick); showsCard = false } label: { Text("とじる").font(LF.inter(700, 15)).foregroundStyle(ink.opacity(0.55)).frame(height: 44) }.buttonStyle(.plain).padding(.top, 4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity).background(Color(hex: "F4F1EA").ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .presentationDetents([.height(380)]).presentationCornerRadius(36).presentationDragIndicator(.hidden)
    }

    private func request() {
        guard let rn = found?.cloudKitUserRecordName, let name = found?.name else { return }
        sending = true; Haptics.play(.click)
        Task {
            let ok = await FriendRequests.send(to: rn, toName: name, myName: myName, myUsername: myUsername)
            await MainActor.run {
                sending = false
                if ok { sent = true; Haptics.play(.success); DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { showsCard = false; dismiss(); onToast("\(name) に 申請を 送りました") } }
                else { Haptics.play(.warn); onToast("送れませんでした") }
            }
        }
    }

    // MARK: 読んだ 文字

    private func checkCode(_ code: String?) {
        guard !locked, let code else { return }
        resolve(code)
    }

    private func resolve(_ code: String) {
        guard let url = URL(string: code) else { reject(code); return }
        if let rn = FriendRules.recordName(from: url) {
            lock(); Task { let p = await UserDirectoryService.fetchProfile(cloudKitUserRecordName: rn); present(p, record: rn) }
        } else if let h = Self.handle(from: url) {
            lock(); Task { let p = await UserDirectoryService.searchUsers(h).first { $0.kind == .exact }?.profile; present(p, record: p?.cloudKitUserRecordName) }
        } else { reject(code) }
    }

    static func handle(from url: URL) -> String? {
        guard let host = url.host?.lowercased(), host == "lattag.app" || host == "www.lattag.app" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, parts[0] == "u" else { return nil }
        let h = HandleRules.normalize(parts[1])
        return HandleRules.validate(h) == nil ? h : nil
    }

    private func lock() { camera.isPaused = true; locked = true; notLattag = false; Haptics.play(.success) }
    private func present(_ p: UserDirectoryService.DirectoryProfile?, record: String?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            if let p { found = p; sent = false; showsCard = true }
            else { locked = false; camera.isPaused = false; Haptics.play(.warn); onToast("プロフィールを 読めませんでした") }
        }
    }
    private func reject(_ code: String) {
        guard lastRejected != code else { return }
        lastRejected = code; notLattag = true; Haptics.play(.warn)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { notLattag = false; lastRejected = nil }
    }

    private func readPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self), let img = CIImage(data: data),
               let det = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]),
               let msg = (det.features(in: img).first as? CIQRCodeFeature)?.messageString {
                await MainActor.run { resolve(msg) }
            } else { await MainActor.run { notLattag = true; Haptics.play(.warn); DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { notLattag = false } } }
            await MainActor.run { photoItem = nil }
        }
    }
}

/// レンズの 角(4すみ ・ 長さ 56)
private struct LensCorners: Shape {
    func path(in r: CGRect) -> Path {
        let l: CGFloat = 56, c: CGFloat = 28
        var p = Path()
        for (sx, sy) in [(CGFloat(0), CGFloat(0)), (1, 0), (0, 1), (1, 1)] {
            let x = r.minX + sx * r.width, y = r.minY + sy * r.height
            let dx: CGFloat = sx == 0 ? 1 : -1, dy: CGFloat = sy == 0 ? 1 : -1
            p.move(to: CGPoint(x: x + dx * l, y: y))
            p.addLine(to: CGPoint(x: x + dx * c, y: y))
            p.addQuadCurve(to: CGPoint(x: x, y: y + dy * c), control: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x, y: y + dy * l))
        }
        return p
    }
}

private struct PulseDot: View {
    let color: Color
    @State private var on = false
    var body: some View {
        Circle().fill(color).frame(width: 8, height: 8).scaleEffect(on ? 1 : 0.7).opacity(on ? 1 : 0.5)
            .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { on = true } }
    }
}
