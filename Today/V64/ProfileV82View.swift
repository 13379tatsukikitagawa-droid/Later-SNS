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
    /// 先週の Recap(ME の カードに 出す)
    var recapPhotos: [UIImage?] = []
    var recapRange = ""
    var weekHas: [Bool] = Array(repeating: false, count: 7)
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
    var onMe: () -> Void = {}
    var onCopyID: () -> Void = {}
    /// DEBUG
    var debugScrollY: CGFloat? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollY: CGFloat = 0
    @State private var shown = false
    @State private var gearSpin = false
    @State private var pos = ScrollPosition()
    @State private var lastTick = Date.distantPast

    private var compactBar: Bool { scrollY > 300 }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "0B0C0D").ignoresSafeArea()
            glow
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 104)
                    ProfileChekiArea(name: data.name, avatar: data.avatar, tags: data.tags, onPhoto: onPhoto).rise(shown, 0)
                    VStack(spacing: 10) {
                        HStack(spacing: 10) { Text("SINCE").font(LF.mono(12)).tracking(3).foregroundStyle(.white.opacity(0.55)); Text(data.since).font(LF.serif(22, italic: true)).foregroundStyle(HV.lime) }
                    }.frame(maxWidth: .infinity).padding(.top, 8).rise(shown, 1)
                    stats.padding(.horizontal, 16).padding(.top, 22).rise(shown, 2)
                    buttons.padding(.horizontal, 16).padding(.top, 10).rise(shown, 3)
                    recapCard.padding(.horizontal, 16).padding(.top, 10).rise(shown, 4)
                    yearCard.padding(.horizontal, 16).padding(.top, 10).rise(shown, 5)
                    Color.clear.frame(height: 70)
                }
            }
            .scrollPosition($pos)
            .onScrollGeometryChange(for: CGFloat.self) { max(0, $0.contentOffset.y + $0.contentInsets.top) } action: { old, v in
                let was = old > 300
                scrollY = v
                if (v > 300) != was, Date().timeIntervalSince(lastTick) > 0.3 { lastTick = Date(); Haptics.play(.tick) }
            }
            topBar
        }
        .ignoresSafeArea(edges: .top)
        .environment(\.colorScheme, .dark)
        .onAppear {
            withAnimation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.52)) { shown = true }
            if let y = debugScrollY { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { pos.scrollTo(y: y) } }
        }
    }

    private var glow: some View {
        GeometryReader { g in
            ZStack {
                Ellipse().fill(RadialGradient(colors: [HV.lime.opacity(0.16), .clear], center: .center, startRadius: 0, endRadius: g.size.width * 0.5)).frame(width: g.size.width * 0.7, height: 250).position(x: g.size.width / 2, y: 140)
                Ellipse().fill(RadialGradient(colors: [Color(hex: "24A03C").opacity(0.34), .clear], center: .center, startRadius: 0, endRadius: g.size.width * 0.55)).frame(width: g.size.width, height: 240).position(x: g.size.width / 2, y: g.size.height)
            }.frame(width: g.size.width, height: g.size.height).clipped()
        }.ignoresSafeArea().allowsHitTesting(false)
    }

    // 上の 帯(高さ 104 ・ 固定)
    private var topBar: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(.ultraThinMaterial).overlay(Color.black.opacity(0.82)).opacity(compactBar ? 1 : 0).frame(height: 104).ignoresSafeArea(edges: .top)
            HStack(alignment: .center) {
                circle("chevron.down") { onBack() }
                Spacer()
                circle("gearshape") { Haptics.play(.pop); withAnimation(.easeInOut(duration: 0.42)) { gearSpin.toggle() }; onSettings() }.rotationEffect(.degrees(gearSpin ? 90 : 0))
            }.padding(.horizontal, 16).padding(.top, 50)
            ZStack {
                if compactBar {
                    HStack(spacing: 8) {
                        ZStack { if let a = data.avatar { Image(uiImage: a).resizable().scaledToFill() } else { Circle().fill(LinearGradient(colors: [Color(hex: "61D278"), Color(hex: "EE5E9C")], startPoint: .topLeading, endPoint: .bottomTrailing)) } }.frame(width: 28, height: 28).clipShape(Circle())
                        Text(data.name).font(LF.inter(800, 16)).foregroundStyle(.white)
                    }.transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Button { Haptics.play(.tick); onCopyID() } label: { Text("@\(data.username)").font(LF.mono(11)).tracking(1.5).foregroundStyle(.white.opacity(0.6)) }.buttonStyle(.plain).transition(.move(edge: .top).combined(with: .opacity))
                }
            }.padding(.top, 62).animation(.easeOut(duration: 0.35), value: compactBar)
        }.frame(height: 104, alignment: .top)
    }

    private func circle(_ icon: String, _ a: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); a() } label: { Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white).frame(width: 44, height: 44).background(.white.opacity(0.1), in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1)) }.buttonStyle(HVPress(scale: 0.92))
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat(data.streak, "DAY STREAK", HV.lime, 0); Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 44)
            stat(data.shots, "SHOTS", .white, 1); Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 44)
            stat(data.kept, "KEPT", .white, 2)
        }.padding(.vertical, 16).background(Color(hex: "121315"), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    private func stat(_ n: Int, _ l: String, _ c: Color, _ i: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(shown ? n : 0)").font(LF.inter(900, 28)).foregroundStyle(c).contentTransition(.numericText()).monospacedDigit()
                .animation(.easeOut(duration: 0.62).delay(0.09 * Double(i)), value: shown)
            Text(l).font(LF.mono(9)).tracking(1.6).foregroundStyle(.white.opacity(0.5))
        }.frame(maxWidth: .infinity)
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            tile("qrcode", "QR", green: true, onQR); tile("pencil", "Edit", green: false, onEdit); tile("square.and.arrow.up", "Share", green: false, onShare); tile("viewfinder", "Scan", green: false, onScan)
        }
    }
    private func tile(_ icon: String, _ t: String, green: Bool, _ a: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); a() } label: {
            VStack(spacing: 8) { Image(systemName: icon).font(.system(size: 21, weight: .semibold)); Text(t).font(LF.inter(800, 12.5)) }.foregroundStyle(green ? HV.ink : .white).frame(maxWidth: .infinity).frame(height: 76)
                .background(green ? HV.lime : Color(hex: "121315"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }.buttonStyle(HVPress(scale: 0.96))
    }

    // ME = Recap の カード(押すと ME)
    private var recapCard: some View {
        Button { Haptics.play(.projector); onMe() } label: {
            ZStack(alignment: .topLeading) {
                Color(hex: "2A2326")
                if let p = data.recapPhotos.first, let p { Image(uiImage: p).resizable().scaledToFill() }
                LinearGradient(colors: [.black.opacity(0.5), .clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                HStack(spacing: 8) {
                    Text("ME").font(LF.inter(900, 11)).foregroundStyle(HV.ink).padding(.horizontal, 10).frame(height: 24).background(HV.lime, in: Capsule())
                    Text("RECAP ・ \(data.recapRange)").font(LF.mono(10)).tracking(1.5).foregroundStyle(.white)
                }.padding(16)
                VStack(alignment: .leading, spacing: -4) {
                    Spacer()
                    Text("Your").font(LF.serif(40)).foregroundStyle(.white)
                    Text("week.").font(LF.serif(40, italic: true)).foregroundStyle(HV.lime)
                    HStack(spacing: 4) { ForEach(0..<7, id: \.self) { i in Capsule().fill(data.weekHas[i] ? HV.lime : .white.opacity(0.25)).frame(height: 4) } }.padding(.top, 10).padding(.trailing, 70)
                }.padding(16)
                Image(systemName: "play.fill").font(.system(size: 18)).foregroundStyle(.white).frame(width: 52, height: 52).background(.ultraThinMaterial, in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1.2)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(16)
            }.frame(height: 206).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }.buttonStyle(HVPress(scale: 0.985))
    }

    private var yearCard: some View {
        Button { Haptics.play(.tick); onShelf() } label: {
            HStack { Text("1 YEAR ・ KEPT").font(LF.mono(12)).tracking(2).foregroundStyle(Color(hex: "FF9F43")); Spacer(); Text("\(data.kept) ★").font(LF.inter(800, 15)).foregroundStyle(.white.opacity(0.7)); Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.4)) }
                .padding(.horizontal, 22).frame(height: 70).background(Color(hex: "121315"), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }.buttonStyle(HVPress(scale: 0.985))
    }
}

/// 本物の データを つなぐ(今ある ProfileShelfView は ☀ と ME ・ 7 DAYS から ひらく)
struct ProfileV82Host: View {
    var onBack: () -> Void
    var onShoot: () -> Void
    var onMe: () -> Void = {}
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var editing = false
    @State private var showsSettings = false
    @State private var toast: String?
    @Query private var blocked: [BlockedUser]
    @State private var showsIcon = false
    @State private var showsQR = false
    @State private var showsScan = false
    @State private var shareItems: [Any]?

    private var me: UserProfile? { UserProfile.current(from: profiles) }
    private var recordName: String? { CloudKitManager.current?.currentUserRecordName }

    var body: some View {
        ProfileV82View(data: data, onBack: onBack, onSettings: { showsSettings = true }, onEdit: { editing = true }, onShare: share, onScan: { showsScan = true }, onQR: { showsQR = true }, onPhoto: { showsIcon = true }, onShelf: { editing = true }, onMe: onMe, onCopyID: { UIPasteboard.general.string = me?.username; Haptics.play(.success); toast = "ID を コピーしました"; DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { toast = nil } })
            .overlay(alignment: .bottom) { if let toast { Text(toast).font(LF.inter(700, 13)).foregroundStyle(HV.ink).padding(.horizontal, 16).frame(height: 36).background(.white, in: Capsule()).padding(.bottom, 60) } }
            .sheet(isPresented: $showsSettings) {
                SettingsV87Sheet(name: me?.name ?? "", username: me?.username ?? "", avatar: me?.profileImageData.flatMap { UIImage(data: $0) }, blockedCount: blocked.count, groupCount: me?.groups.count ?? 0, onEdit: { showsSettings = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { editing = true } }, onPhoto: { showsSettings = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showsIcon = true } }, onClose: { showsSettings = false }, onLoggedOut: { showsSettings = false })
                    .presentationDetents([.large]).presentationDragIndicator(.visible).presentationBackground(Color(hex: "0F1011"))
            }
            .overlay { if editing { ProfileEditV88View(name: me?.name ?? "", tags: me?.selfTags ?? [], avatar: me?.profileImageData.flatMap { UIImage(data: $0) }, onPhoto: { showsIcon = true }, onSave: { saveProfile($0, $1) }, onClose: { withAnimation(.easeOut(duration: 0.25)) { editing = false } }).transition(.opacity) } }
            .fullScreenCover(isPresented: $showsScan) { FriendQRScanView(myName: me?.name ?? "", friendCount: 0) { _ in } }
            .fullScreenCover(isPresented: $showsQR) { SelfQRChekiHost(onScan: { showsQR = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showsScan = true } }, onClose: { showsQR = false }) }
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
        if let r = RecapStore.shared.items.first(where: { $0.kind == .week }) {
            d.recapRange = MEV86View.range(r)
            d.recapPhotos = r.photoIDs.prefix(3).map { id in me.photos.first { $0.id.uuidString == id }.flatMap { V64Images.image(key: "pr\($0.id)", data: $0.imageData, maxPixel: 640) } }
            d.weekHas = (0..<7).map { i in let day = cal.date(byAdding: .day, value: i, to: r.start) ?? r.start; return me.photos.contains { cal.isDate($0.captureDate, inSameDayAs: day) } }
        }
        return d
    }

    private func share() { if let rn = recordName { shareItems = [FriendRules.shareItem(myName: me?.name ?? "", recordName: rn)] } }

    private func saveProfile(_ name: String, _ tags: [String]) {
        guard let p = me else { return }
        p.name = name; p.selfTags = tags; p.profileUpdatedAt = Date(); try? modelContext.save()
        if let cloud = CloudKitManager.current { for g in p.groups { cloud.markForUpload(userProfile: p, in: g) } }
        Task { await UserDirectoryService.publish(p) }
        withAnimation(.easeOut(duration: 0.25)) { editing = false }
        toast = "プロフィールを 保存しました"; DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { toast = nil }
    }

    private func saveIcon(_ data: Data?) {
        guard let user = me else { return }
        user.profileImageData = data; user.profileUpdatedAt = Date(); try? modelContext.save()
        if let cloud = CloudKitManager.current { for g in user.groups { cloud.markForUpload(userProfile: user, in: g) } }
        Task { await UserDirectoryService.publish(user) }
    }
}


/// チェキ(高さ 372)+ 自分の タグの シール 3つ。編集中は シールが ゆれて ×(はずす)・ 名前に 点線 ・ 右上 カメラ / 右下 ペン(v88 B)
struct ProfileChekiArea: View {
    var name: String
    var avatar: UIImage?
    var tags: [String]
    var editing = false
    var onPhoto: () -> Void = {}
    var onName: () -> Void = {}
    var onRemoveTag: (Int) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wobble = false
    /// タグは チェキに 貼る ステッカー(v111 §1):1つ目 lime ・ 2つ目 pink ・ 3つ目 そら
    private let sticker: [(String, String, Double)] = [("C8F25A", "0B0C0D", -8), ("FF7AB6", "0B0C0D", 7), ("6EC8FF", "0B0C0D", -5)]

    var body: some View {
        // 左右の 余白 18pt(幅 いっぱい ・ 最大 340pt)・ 写真 1:1 ・ 下の 余白 74pt ・ -2.5°
        cheki
            .frame(maxWidth: 340)
            .padding(.horizontal, 18)
            .padding(.top, 22).padding(.bottom, 14)
            .frame(maxWidth: .infinity)
            .onAppear { if editing && !reduceMotion { withAnimation(.easeInOut(duration: 0.18).repeatForever(autoreverses: true)) { wobble = true } } }
    }

    private var cheki: some View {
        VStack(spacing: 0) {
            Color.clear.aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let a = avatar { Image(uiImage: a).resizable().scaledToFill() }
                    else { LinearGradient(colors: [Color(hex: "61D278"), Color(hex: "EE5E9C")], startPoint: .topLeading, endPoint: .bottomTrailing).overlay(Text(String(name.prefix(1))).font(LF.inter(900, 120)).foregroundStyle(.white.opacity(0.9))) }
                }
                .clipped()
                .overlay(alignment: .topTrailing) {
                    if editing { Button { Haptics.play(.click); onPhoto() } label: { Image(systemName: "camera.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(Color(hex: "0B0C0D")).frame(width: 44, height: 44).background(HV.lime, in: Circle()) }.buttonStyle(.plain).padding(4) }
                }
                .overlay(alignment: .bottomTrailing) {
                    if !editing { Button { Haptics.play(.click); onPhoto() } label: {
                        HStack(spacing: 5) { Image(systemName: "camera.fill").font(.system(size: 11, weight: .bold)); Text("写真").font(.system(size: 12, weight: .heavy)) }.foregroundStyle(.white).padding(.horizontal, 10).frame(height: 44).background(.black.opacity(0.55), in: Capsule())
                    }.buttonStyle(.plain).padding(4) }
                }
                .padding(.horizontal, 12).padding(.top, 12)
            ZStack {
                Text(name).font(LGFont.mincho(46)).foregroundStyle(Color(hex: "0B0C0D").opacity(0.85)).lineLimit(1).minimumScaleFactor(0.5)
                    .padding(.horizontal, editing ? 6 : 0)
                    .overlay { if editing { RoundedRectangle(cornerRadius: 6).strokeBorder(HV.lime.opacity(0.6), style: StrokeStyle(lineWidth: 1.4, dash: [4, 3])) } }
                if editing {
                    HStack { Spacer(minLength: 0); Button { Haptics.play(.tick); onName() } label: { Image(systemName: "pencil").font(.system(size: 13, weight: .bold)).foregroundStyle(Color(hex: "0B0C0D")).frame(width: 44, height: 44).background(.white, in: Circle()).shadow(radius: 3) }.buttonStyle(.plain) }
                }
            }.frame(height: 74).padding(.horizontal, 16)
        }
        .background(Color(hex: "F6F2EA"), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 16, y: 10)
        .overlay { stickers }
        .overlay(alignment: .top) {
            Rectangle().fill(HV.lime.opacity(0.9)).frame(width: 96, height: 26).rotationEffect(.degrees(-4)).offset(y: -13)
        }
        .rotationEffect(.degrees(-2.5))
    }

    private var stickers: some View {
        GeometryReader { g in
            let w = g.size.width
            let photoBottom = 12 + (w - 24)
            let spots: [CGPoint] = [CGPoint(x: 72, y: 56), CGPoint(x: w - 68, y: photoBottom * 0.5), CGPoint(x: 78, y: photoBottom - 44)]
            ForEach(Array(tags.prefix(3).enumerated()), id: \.offset) { i, t in
                let st = sticker[i]
                ZStack(alignment: .topLeading) {
                    Text("#\(t)").font(.system(size: 17, weight: .heavy)).foregroundStyle(Color(hex: st.1)).lineLimit(1).padding(.horizontal, 14).frame(height: 38).fixedSize()
                        .background(Color(hex: st.0), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white, lineWidth: 2.5))
                        .shadow(color: .black.opacity(0.35), radius: 4, x: 2, y: 3)
                    if editing {
                        Button { Haptics.play(.tick); onRemoveTag(i) } label: { Image(systemName: "xmark").font(.system(size: 9, weight: .black)).foregroundStyle(.white).frame(width: 22, height: 22).background(Color.black, in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1)) }
                            .buttonStyle(.plain).frame(width: 44, height: 44, alignment: .topLeading).contentShape(Rectangle()).padding(-14)
                    }
                }
                .rotationEffect(.degrees(st.2 + (editing && !reduceMotion ? (wobble ? 2 : -2) : 0)))
                .position(spots[i])
            }
        }
    }
}
