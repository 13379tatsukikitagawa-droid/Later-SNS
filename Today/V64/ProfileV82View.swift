import SwiftUI
import SwiftData

// P07 / P25:プロフィール(あなた)。見本:F08 F12。背景は 自分の 写真を ぼかした 緑 → 紫 → 黒。チェキ + タグの シール + 名前 + 数字 + QR / Edit / Share / Scan。
// 設定 ・ 編集 ・ 通報 ・ 削除は 今までの 画面(ProfileShelfView)に まかせる(右上の ☀ から)。人の 絵は 使わない(写真が 無い 時は 名前の 1文字 + 色)。

struct ProfileV82Data {
    var name = ""
    var username = ""
    var avatar: UIImage?
    var tags: [String] = []
    var since = "Oct 2026"
    var streak = 0
    var shots = 0
    var kept = 0
    var recordName: String?
}

struct ProfileV82View: View {
    var data: ProfileV82Data
    var onBack: () -> Void = {}
    var onSettings: () -> Void = {}
    var onEdit: () -> Void = {}
    var onShare: () -> Void = {}
    var onScan: () -> Void = {}
    var onQR: () -> Void = {}
    var onPhoto: () -> Void = {}
    var onShelf: () -> Void = {}

    private let sticker: [(String, String, Double)] = [("C8F25A", "0B0C0D", -8), ("EE5E9C", "FFFFFF", 8), ("9ED8FF", "0B0C0D", -6), ("FFD60A", "0B0C0D", -9), ("B28CFF", "FFFFFF", -3), ("3BD35A", "0B0C0D", 10)]
    private let spots: [CGPoint] = [CGPoint(x: 73, y: 178), CGPoint(x: 315, y: 212), CGPoint(x: 59, y: 350), CGPoint(x: 326, y: 371), CGPoint(x: 93, y: 472), CGPoint(x: 290, y: 492)]

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .topLeading) {
                background(g.size)
                ZStack(alignment: .topLeading) {
                    cheki.position(x: g.size.width / 2, y: 303)
                    ForEach(Array(data.tags.prefix(6).enumerated()), id: \.offset) { i, t in
                        let st = sticker[i % sticker.count]
                        Text("#\(t)").font(LF.inter(900, 17)).foregroundStyle(Color(hex: st.1)).padding(.horizontal, 16).frame(height: 38)
                            .background(Color(hex: st.0), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: .black.opacity(0.35), radius: 5, x: 3, y: 4).rotationEffect(.degrees(st.2))
                            .position(x: spots[i % spots.count].x * g.size.width / 390, y: spots[i % spots.count].y)
                    }
                    VStack(spacing: 8) {
                        Text(data.name).font(LGFont.mincho(66)).foregroundStyle(.white)
                        HStack(spacing: 10) { Text("SINCE").font(LF.mono(12)).tracking(3).foregroundStyle(.white.opacity(0.55)); Text(data.since).font(LF.serif(22, italic: true)).foregroundStyle(HV.lime) }
                    }.frame(width: g.size.width).position(x: g.size.width / 2, y: 570)
                    stats.padding(.horizontal, 16).frame(width: g.size.width).position(x: g.size.width / 2, y: 665)
                    buttons.padding(.horizontal, 16).frame(width: g.size.width).position(x: g.size.width / 2, y: 755)
                    Button { Haptics.play(.tick); onShelf() } label: {
                        HStack { Text("ME ・ 7 DAYS").font(LF.mono(12)).tracking(2).foregroundStyle(Color(hex: "FF9F43")); Spacer(); Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.5)) }
                            .padding(.horizontal, 28).frame(height: 70).background(Color(hex: "0E0F10"), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }.buttonStyle(HVPress(scale: 0.98)).padding(.horizontal, 16).frame(width: g.size.width).position(x: g.size.width / 2, y: 855)
                }.frame(width: g.size.width, height: g.size.height)
                topBar(g.size.width)
            }
            .frame(width: g.size.width, height: g.size.height)
        }.ignoresSafeArea().environment(\.colorScheme, .dark)
    }

    private func background(_ size: CGSize) -> some View {
        ZStack {
            Color(hex: "0A0A0B")
            if let a = data.avatar { Image(uiImage: V64Images.blurred(key: "pf\(a.hashValue)", source: a, maxPixel: 80, radius: 22, saturation: 1.2, brightness: 0.4)).resizable().scaledToFill().frame(width: size.width, height: 760).clipped().frame(maxHeight: .infinity, alignment: .top) }
            LinearGradient(stops: [.init(color: Color(hex: "1B3320").opacity(0.95), location: 0), .init(color: Color(hex: "2B2A28").opacity(0.55), location: 0.3), .init(color: Color(hex: "3A1B2B").opacity(0.7), location: 0.55), .init(color: Color(hex: "0A0A0B"), location: 0.8)], startPoint: .top, endPoint: .bottom)
        }.ignoresSafeArea()
    }

    private func topBar(_ w: CGFloat) -> some View {
        ZStack {
            Text("@\(data.username)").font(LF.mono(12)).tracking(2).foregroundStyle(.white.opacity(0.6))
            HStack {
                circle("chevron.down") { onBack() }
                Spacer()
                circle("sun.max") { onSettings() }
            }.padding(.horizontal, 18)
        }.frame(width: w).padding(.top, 50)
    }

    private func circle(_ icon: String, _ a: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); a() } label: { Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white).frame(width: 42, height: 42).background(.white.opacity(0.1), in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1)) }.buttonStyle(HVPress(scale: 0.92))
    }

    // チェキ(写真 or 名前の 1文字 + 色 ・ 下の 白い 帯に 名前)
    private var cheki: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    if let a = data.avatar { Image(uiImage: a).resizable().scaledToFill() }
                    else { LinearGradient(colors: [Color(hex: "61D278"), Color(hex: "EE5E9C")], startPoint: .topLeading, endPoint: .bottomTrailing).overlay(Text(String(data.name.prefix(1))).font(LF.inter(900, 90)).foregroundStyle(.white.opacity(0.9))) }
                    Button { Haptics.play(.click); onPhoto() } label: {
                        HStack(spacing: 5) { Image(systemName: "camera.fill").font(.system(size: 11, weight: .bold)); Text("写真").font(.system(size: 12, weight: .heavy)) }.foregroundStyle(.white).padding(.horizontal, 10).frame(height: 28).background(.black.opacity(0.55), in: Capsule())
                    }.buttonStyle(.plain).padding(8)
                }.frame(width: 232, height: 232).clipped().padding(.top, 14)
                Text(data.name).font(LGFont.mincho(32)).foregroundStyle(Color(hex: "0B0C0D").opacity(0.85)).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 26).padding(.top, 6)
                Spacer()
            }.frame(width: 262, height: 332).background(Color(hex: "F6F2EA"), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: .black.opacity(0.45), radius: 16, y: 10)
            Rectangle().fill(HV.lime.opacity(0.85)).frame(width: 100, height: 34).rotationEffect(.degrees(-4)).offset(y: -14)
        }.rotationEffect(.degrees(4))
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat("\(data.streak)", "DAY STREAK"); Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 50)
            stat("\(data.shots)", "SHOTS"); Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 50)
            stat("\(data.kept)", "KEPT")
        }.frame(height: 88).background(Color(hex: "0E0F10"), in: RoundedRectangle(cornerRadius: 28, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
    }
    private func stat(_ n: String, _ l: String) -> some View {
        VStack(spacing: 4) { Text(n).font(LF.serif(46)).foregroundStyle(.white).frame(height: 44); Text(l).font(LF.mono(10.5)).tracking(2).foregroundStyle(.white.opacity(0.5)) }.frame(maxWidth: .infinity)
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            tile("qrcode", "QR", green: true, onQR); tile("pencil", "Edit", green: false, onEdit); tile("square.and.arrow.up", "Share", green: false, onShare); tile("viewfinder", "Scan", green: false, onScan)
        }
    }
    private func tile(_ icon: String, _ t: String, green: Bool, _ a: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); a() } label: {
            VStack(spacing: 10) { Image(systemName: icon).font(.system(size: 22, weight: .semibold)); Text(t).font(LF.serif(21)) }.foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 98)
                .background(green ? Color(hex: "24A03C") : Color(hex: "0E0F10"), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(green ? 0 : 0.1), lineWidth: 1))
        }.buttonStyle(HVPress(scale: 0.96))
    }
}

/// 本物の データを つなぐ(今ある ProfileShelfView は ☀ と ME ・ 7 DAYS から ひらく)
struct ProfileV82Host: View {
    var onBack: () -> Void
    var onShoot: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showsShelf = false
    @State private var showsIcon = false
    @State private var showsQR = false
    @State private var showsScan = false
    @State private var shareItems: [Any]?

    private var me: UserProfile? { UserProfile.current(from: profiles) }
    private var recordName: String? { CloudKitManager.current?.currentUserRecordName }

    var body: some View {
        ProfileV82View(data: data, onBack: onBack, onSettings: { showsShelf = true }, onEdit: { showsShelf = true }, onShare: share, onScan: { showsScan = true }, onQR: { showsQR = true }, onPhoto: { showsIcon = true }, onShelf: { showsShelf = true })
            .fullScreenCover(isPresented: $showsShelf) { ProfileShelfView(onBack: { showsShelf = false }, onShoot: { showsShelf = false; onShoot() }) }
            .fullScreenCover(isPresented: $showsScan) { FriendQRScanView(myName: me?.name ?? "", friendCount: 0) { _ in } }
            .sheet(isPresented: $showsQR) { ProfileSelfQRSheet(name: me?.name ?? "", recordName: recordName) }
            .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) { ShareSheet(activityItems: shareItems ?? []) { _ in shareItems = nil }.presentationDetents([.medium, .large]) }
            .sheet(isPresented: $showsIcon) {
                let cur = me?.profileImageData.flatMap { UIImage(data: $0) }
                let recent = (me?.photos ?? []).sorted { $0.captureDate > $1.captureDate }.prefix(8).map { p in (id: p.id.uuidString, image: V64Images.image(key: "ip\(p.id)", data: p.imageData, maxPixel: 240), label: Calendar.current.isDateInYesterday(p.captureDate) ? "きのう" : nil as String?) }
                IconPickerV81Sheet(name: me?.name ?? "", current: cur, recent: Array(recent), onSave: { saveIcon($0) }, onClose: { showsIcon = false }).presentationDetents([.large]).presentationBackground(Color(hex: "141516"))
            }
    }

    private var data: ProfileV82Data {
        var d = ProfileV82Data()
        guard let me else { d.name = "ゲスト"; return d }
        d.name = me.name; d.username = me.username; d.avatar = me.profileImageData.flatMap { UIImage(data: $0) }; d.tags = me.selfTags
        d.shots = me.photos.count; d.kept = me.pinnedPhotoIDs.count
        let cal = Calendar.current
        let days = Set(me.photos.map { cal.startOfDay(for: $0.captureDate) })
        var s = 0; var day = cal.startOfDay(for: Date())
        if !days.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day) ?? day }
        while days.contains(day) { s += 1; day = cal.date(byAdding: .day, value: -1, to: day) ?? day }
        d.streak = s
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "MMM yyyy"
        d.since = f.string(from: me.photos.map(\.captureDate).min() ?? Date())
        d.recordName = recordName
        return d
    }

    private func share() { if let rn = recordName { shareItems = ["\(me?.name ?? "") と Lattag で つながろう\n\(FriendRules.link(recordName: rn).absoluteString)"] } }

    private func saveIcon(_ data: Data?) {
        guard let user = me else { return }
        user.profileImageData = data; user.profileUpdatedAt = Date(); try? modelContext.save()
        if let cloud = CloudKitManager.current { for g in user.groups { cloud.markForUpload(userProfile: user, in: g) } }
        Task { await UserDirectoryService.publish(user) }
    }
}
