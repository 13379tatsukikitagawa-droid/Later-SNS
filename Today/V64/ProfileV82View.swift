import SwiftUI
import SwiftData

// P58 B(v132 2章):プロフィール = アーカイブ。小さな チェキ + 名前 → 数字 3つ → 編集 / 送る / QR / 読む → くっつく タブ(毎日 | Trip)→ ひらいた 日が 3列。
// 数え方は `ProfileArchiveRules`。きょうの マスは 写真を 出さない ・ 9:00 まえは きのうの マスも 鍵。
// 設定 ・ 編集 ・ 通報 ・ 削除は 今までの 画面に まかせる。人の 絵は 使わない(写真が 無い 時は 名前の 1文字 + 色)。

struct ProfileTripRow: Identifiable {
    let id: UUID
    var name: String
    var range: String
    var count: Int
    var cover: UIImage?
}

struct ProfileV82Data {
    var name = ""
    var username = ""
    var avatar: UIImage?
    var tags: [String] = []
    var since = ""
    var streak = 0
    var shots = 0
    var opened = 0
    var cells: [ProfileDayCell] = []
    var covers: [Date: UIImage] = [:]
    var trips: [ProfileTripRow] = []
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
    var onCopyID: () -> Void = {}
    var onDay: (Date) -> Void = { _ in }
    var onTrip: (UUID) -> Void = { _ in }
    /// DEBUG
    var debugScrollY: CGFloat? = nil
    var debugTab: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollY: CGFloat = 0
    @State private var shown = false
    @State private var tab = 0
    @State private var gridW: CGFloat = 366
    @State private var gearSpin = false
    @State private var pos = ScrollPosition()
    @State private var lastTick = Date.distantPast

    private var compactBar: Bool { scrollY > 130 }
    private let bg = Color(hex: "0B0C0D")

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    top.padding(.horizontal, 20).padding(.top, 8).rise(shown, 0)
                    stats.padding(.horizontal, 20).padding(.top, 22).rise(shown, 1)
                    buttons.padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14).rise(shown, 2)
                    Section {
                        if tab == 0 { daysGrid } else { tripList }
                    } header: { tabs }
                }
            }
            .scrollPosition($pos)
            .onScrollGeometryChange(for: CGFloat.self) { max(0, $0.contentOffset.y + $0.contentInsets.top) } action: { old, v in
                let was = old > 130
                scrollY = v
                if (v > 130) != was, Date().timeIntervalSince(lastTick) > 0.3 { lastTick = Date(); Haptics.play(.tick) }
            }
        }
        .background(bg.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .environment(\.colorScheme, .dark)
        .onAppear {
            tab = debugTab
            withAnimation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.52)) { shown = true }
            if let y = debugScrollY { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { pos.scrollTo(y: y) } }
        }
    }

    // MARK: 上の 帯(高さ 104 ・ 固定)

    private var topBar: some View {
        ZStack(alignment: .top) {
            bg
            HStack(alignment: .center) {
                circle("chevron.down", "とじる") { onBack() }
                Spacer()
                circle("gearshape", "設定") { Haptics.play(.pop); withAnimation(.easeInOut(duration: 0.42)) { gearSpin.toggle() }; onSettings() }.rotationEffect(.degrees(gearSpin ? 90 : 0))
            }.padding(.horizontal, 16).padding(.top, 50)
            ZStack {
                if compactBar {
                    HStack(spacing: 8) {
                        ZStack {
                            if let a = data.avatar { Image(uiImage: a).resizable().scaledToFill() }
                            else { Color(hex: "3A3A3F").overlay(Text(String(data.name.prefix(1))).font(Typo.ui(900, 14)).foregroundStyle(.white)) }
                        }.frame(width: 30, height: 30).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color(hex: "F6F2EA"), lineWidth: 2))
                        Text(data.name).font(Typo.title(22)).foregroundStyle(.white).lineLimit(1)
                    }.transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Button { Haptics.play(.tick); onCopyID() } label: { Text("@\(data.username)").font(Typo.ui(800, 14)).foregroundStyle(Color(hex: "C9C9CF")).frame(minHeight: 44) }
                        .buttonStyle(.plain).transition(.move(edge: .top).combined(with: .opacity))
                }
            }.padding(.top, 50).frame(height: 104, alignment: .top).animation(.easeOut(duration: 0.25), value: compactBar)
        }.frame(height: 104, alignment: .top)
    }

    private func circle(_ icon: String, _ label: String, _ a: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); a() } label: { Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white).frame(width: 44, height: 44).background(.white.opacity(0.1), in: Circle()) }
            .buttonStyle(HVPress(scale: 0.92)).accessibilityLabel(label)
    }

    // MARK: 1かたまり(チェキ + 名前)

    private var top: some View {
        HStack(alignment: .top, spacing: 20) {
            cheki.frame(width: 104)
            VStack(alignment: .leading, spacing: 6) {
                Text(data.name).font(Typo.title(40)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5)
                Text(data.since).font(Typo.ui(700, 13)).foregroundStyle(Color(hex: "8E8E96"))
                tagRow.padding(.top, 4)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 14)
        }
    }

    private var cheki: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                Group {
                    if let a = data.avatar { Image(uiImage: a).resizable().scaledToFill() }
                    else { LinearGradient(colors: [Color(hex: "61D278"), Color(hex: "EE5E9C")], startPoint: .topLeading, endPoint: .bottomTrailing).overlay(Text(String(data.name.prefix(1))).font(Typo.ui(900, 40)).foregroundStyle(.white)) }
                }.frame(width: 88, height: 88).clipped()
                Color.clear.frame(height: 22)
            }
            .padding(.top, 6).padding(.horizontal, 6)
            .background(Color(hex: "F6F2EA"), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
            .overlay(alignment: .top) { Rectangle().fill(HV.lime.opacity(0.9)).frame(width: 44, height: 14).rotationEffect(.degrees(-4)).offset(y: -7) }
            Button { Haptics.play(.click); onPhoto() } label: {
                Image(systemName: "camera.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.white).frame(width: 30, height: 30).background(Color.black, in: Circle())
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).offset(x: 7, y: 7).accessibilityLabel("写真を かえる")
        }
        .rotationEffect(.degrees(-4))
        .padding(.top, 10)
    }

    private var tagRow: some View {
        let dots = [HV.lime, PopColor.pink, PopColor.sky]
        return HStack(spacing: 6) {
            ForEach(Array(data.tags.prefix(2).enumerated()), id: \.offset) { i, t in
                HStack(spacing: 5) {
                    Circle().fill(dots[i % 3]).frame(width: 7, height: 7)
                    Text("#\(t)").font(Typo.ui(800, 12)).foregroundStyle(.white).lineLimit(1)
                }.padding(.horizontal, 10).frame(height: 26).background(.white.opacity(0.1), in: Capsule())
            }
        }
    }

    // MARK: 数字 3つ(箱 なし)

    private var stats: some View {
        HStack(spacing: 0) {
            stat(data.streak, "日 れんぞく", HV.lime, 0)
            Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 44)
            stat(data.shots, "枚 撮った", .white, 1)
            Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 44)
            stat(data.opened, "日 ひらいた", .white, 2)
        }
    }

    private func stat(_ n: Int, _ label: String, _ c: Color, _ i: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(shown ? n : 0)").font(Typo.title(34)).foregroundStyle(c).contentTransition(.numericText()).monospacedDigit()
                .animation(.easeOut(duration: 0.62).delay(0.09 * Double(i)), value: shown)
            Text(label).font(Typo.ui(700, 12)).foregroundStyle(Color(hex: "8E8E96"))
        }.frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: ボタン(編集 / 送る / QR / 読む)

    private var buttons: some View {
        HStack(spacing: 8) {
            Button { Haptics.play(.tick); onEdit() } label: {
                Text("編集").font(Typo.ui(800, 14)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 48)
            }.containerRelativeFrame(.horizontal) { w, _ in (w - 40 - 96 - 24) / 2.35 }.buttonStyle(HVLedgePress(face: Color(hex: "1A1A1D"), ledge: Color(hex: "060607"), radius: 16, depth: 3))
            Button { Haptics.play(.click); onShare() } label: {
                HStack(spacing: 6) { Image(systemName: "square.and.arrow.up").font(.system(size: 15, weight: .bold)); Text("送る").font(Typo.ui(900, 14)) }
                    .foregroundStyle(HV.ink).frame(maxWidth: .infinity).frame(height: 48)
            }.containerRelativeFrame(.horizontal) { w, _ in (w - 40 - 96 - 24) / 2.35 * 1.35 }.buttonStyle(HVLedgePress(face: HV.lime, ledge: Color(hex: "97C235"), radius: 16, depth: 3))
            square("qrcode", "自分の QR", onQR)
            square("viewfinder", "QR を 読む", onScan)
        }.padding(.bottom, 3)
    }

    private func square(_ icon: String, _ label: String, _ a: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); a() } label: {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).frame(width: 48, height: 48)
        }.buttonStyle(HVLedgePress(face: Color(hex: "1A1A1D"), ledge: Color(hex: "060607"), radius: 16, depth: 3)).accessibilityLabel(label)
    }

    // MARK: くっつく タブ

    private var tabs: some View {
        HStack(spacing: 0) {
            tabButton("square.grid.2x2", "毎日", data.cells.filter { $0.kind == .opened }.count, 0)
            tabButton("airplane", "Trip", data.trips.count, 1)
        }
        .background(bg)
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
        .background(bg)
    }

    private func tabButton(_ icon: String, _ title: String, _ n: Int, _ i: Int) -> some View {
        let on = tab == i
        return Button {
            guard tab != i else { return }
            Haptics.play(.sel)
            withAnimation(.easeOut(duration: 0.18)) { tab = i }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold))
                Text(title).font(Typo.ui(800, 14))
                Text("\(n)").font(Typo.ui(700, 11)).foregroundStyle(.white.opacity(0.5))
            }
            .foregroundStyle(on ? .white : .white.opacity(0.45)).frame(maxWidth: .infinity).frame(height: 48)
            .overlay(alignment: .bottom) { Rectangle().fill(on ? .white : .clear).frame(height: 3).padding(.horizontal, 24) }
        }.buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: 毎日(3列)

    private var side: CGFloat { floor((gridW - 24 - 6) / 3) }

    private var daysGrid: some View {
        let hasOpened = data.cells.contains { $0.kind != .today }
        return VStack(spacing: 0) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: 3), count: 3), spacing: 3) {
                ForEach(data.cells) { c in cell(c) }
            }.padding(.horizontal, 12).padding(.top, 3)
            if !hasOpened {
                VStack(spacing: 8) {
                    Text("ここに ひらいた 日が 並びます").font(Typo.ui(900, 15)).foregroundStyle(.white)
                    Text("きょう 撮った 写真は、あしたの 9:00 に\n友だちと いっしょに ひらきます").font(Typo.ui(700, 12.5)).foregroundStyle(Color(hex: "8E8E96")).multilineTextAlignment(.center)
                }.padding(.top, 36).padding(.horizontal, 24)
            }
            Color.clear.frame(height: 120)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { gridW = $0 }
    }

    @ViewBuilder private func cell(_ c: ProfileDayCell) -> some View {
        let f = DateFormatter()
        switch c.kind {
        case .today:
            VStack(spacing: 2) {
                HStack(spacing: 3) { ForEach(0..<3, id: \.self) { i in Circle().fill(i < c.count ? HV.lime : .white.opacity(0.2)).frame(width: 6, height: 6) } }.padding(.bottom, 2)
                Text("きょう \(min(c.count, 3))/3").font(Typo.ui(900, 13)).foregroundStyle(.white)
                Text("あした 9:00\nに ひらく").font(Typo.ui(700, 10)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
            }
            .frame(width: side, height: side).background(Color(hex: "111113"), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(HV.lime.opacity(0.55), lineWidth: 1.5))
            .accessibilityElement(children: .combine)
        case .locked:
            ZStack {
                Color(hex: "2A2A2E")
                VStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(.white).frame(width: 30, height: 30).background(.black.opacity(0.5), in: Circle())
                    Text("9:00 に ひらく").font(Typo.ui(700, 10.5)).foregroundStyle(.white.opacity(0.75))
                }
            }
            .frame(width: side, height: side).clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(alignment: .bottomLeading) { dateLabel(c.day, f) }
            .accessibilityElement(children: .combine)
        case .opened:
            Button { Haptics.play(.pop); onDay(c.day) } label: {
                Color(hex: "1A1A1D")
                    .overlay { if let img = data.covers[c.day] { Image(uiImage: img).resizable().scaledToFill() } }
                    .overlay(alignment: .topTrailing) {
                        Text("\(c.count)").font(Typo.ui(800, 11)).foregroundStyle(.white).frame(width: 20, height: 20).background(.black.opacity(0.78), in: Circle()).padding(5)
                    }
                    .overlay(alignment: .bottomLeading) { dateLabel(c.day, f) }
                    .frame(width: side, height: side).clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }.buttonStyle(HVPress(scale: 0.97))
            .accessibilityLabel("\(Calendar.current.component(.month, from: c.day))月\(Calendar.current.component(.day, from: c.day))日 \(c.count)枚")
        }
    }

    private func dateLabel(_ d: Date, _ f: DateFormatter) -> some View {
        let cal = Calendar.current
        return Text(String(format: "%d.%02d", cal.component(.month, from: d), cal.component(.day, from: d)))
            .font(Typo.ui(800, 11)).monospacedDigit().foregroundStyle(PopColor.sun).padding(6)
            .shadow(color: .black.opacity(0.6), radius: 2)
    }

    // MARK: Trip

    private var tripList: some View {
        VStack(spacing: 10) {
            if data.trips.isEmpty {
                Text("入った Trip が ここに 並びます").font(Typo.ui(700, 13)).foregroundStyle(Color(hex: "8E8E96")).padding(.top, 36)
            }
            ForEach(data.trips) { t in
                Button { Haptics.play(.pop); onTrip(t.id) } label: {
                    HStack(spacing: 12) {
                        Group { if let c = t.cover { Image(uiImage: c).resizable().scaledToFill() } else { Color(hex: "2A2A2E") } }
                            .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(t.name).font(Typo.ui(800, 16)).foregroundStyle(.white).lineLimit(1)
                            Text("\(t.range) ・ \(t.count)枚").font(Typo.ui(600, 12)).foregroundStyle(Color(hex: "8E8E96")).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.4))
                    }.padding(.horizontal, 16).frame(minHeight: 72).contentShape(Rectangle())
                }.buttonStyle(HVPress(scale: 0.98))
            }
            Color.clear.frame(height: 120)
        }.padding(.top, 8)
    }
}

/// その 日の ひらいた 写真を 1枚ずつ 見る(下へ ドラッグ か ✕ で とじる)
struct ProfileDayPhotosView: View {
    var day: Date
    var photos: [UIImage]
    var onClose: () -> Void
    @State private var page = 0

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            if photos.isEmpty {
                Text("この 日の 写真は まだ ひらいて いません").font(Typo.ui(700, 14)).foregroundStyle(.white.opacity(0.7)).frame(maxHeight: .infinity)
            } else {
                TabView(selection: $page) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { i, img in
                        Image(uiImage: img).resizable().scaledToFit().tag(i)
                    }
                }.tabViewStyle(.page(indexDisplayMode: .never)).ignoresSafeArea()
            }
            HStack {
                Text(String(format: "%d.%02d", Calendar.current.component(.month, from: day), Calendar.current.component(.day, from: day)) + (photos.count > 1 ? "  \(page + 1)/\(photos.count)" : ""))
                    .font(Typo.ui(800, 15)).foregroundStyle(PopColor.sun).monospacedDigit()
                Spacer()
                Button { Haptics.play(.tick); onClose() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44).background(.white.opacity(0.14), in: Circle())
                }.accessibilityLabel("とじる")
            }.padding(.horizontal, 16).padding(.top, 8)
        }
        .preferredColorScheme(.dark)
        .gesture(DragGesture(minimumDistance: 30).onEnded { if $0.translation.height > 90 { onClose() } })
    }
}

/// 本物の データを つなぐ(今ある ProfileShelfView は ☀ と ME ・ 7 DAYS から ひらく)
struct ProfileV82Host: View {
    var onBack: () -> Void
    var onShoot: () -> Void
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
    @State private var openDay: Date?

    private var me: UserProfile? { UserProfile.current(from: profiles) }
    private var recordName: String? { CloudKitManager.current?.currentUserRecordName }

    var body: some View {
        ProfileV82View(data: data, onBack: onBack, onSettings: { showsSettings = true }, onEdit: { editing = true }, onShare: share, onScan: { showsScan = true }, onQR: { showsQR = true }, onPhoto: { showsIcon = true }, onCopyID: { UIPasteboard.general.string = me?.username; Haptics.play(.success); toast = "ID を コピーしました"; DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { toast = nil } }, onDay: { openDay = $0 }, onTrip: { id in onBack(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { NotificationCenter.default.post(name: .chatNotificationTapped, object: id) } })
            .overlay(alignment: .bottom) { if let toast { Text(toast).font(Typo.ui(700, 13)).foregroundStyle(HV.ink).padding(.horizontal, 16).frame(height: 36).background(.white, in: Capsule()).padding(.bottom, 60) } }
            .sheet(isPresented: $showsSettings) {
                SettingsV87Sheet(name: me?.name ?? "", username: me?.username ?? "", avatar: me?.profileImageData.flatMap { UIImage(data: $0) }, blockedCount: blocked.count, groupCount: me?.groups.count ?? 0, onEdit: { showsSettings = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { editing = true } }, onPhoto: { showsSettings = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showsIcon = true } }, onClose: { showsSettings = false }, onLoggedOut: { showsSettings = false })
                    .presentationDetents([.large]).presentationDragIndicator(.visible).presentationBackground(Color(hex: "0F1011"))
            }
            .overlay { if editing { ProfileEditV88View(name: me?.name ?? "", tags: me?.selfTags ?? [], avatar: me?.profileImageData.flatMap { UIImage(data: $0) }, onPhoto: { showsIcon = true }, onSave: { saveProfile($0, $1) }, onClose: { withAnimation(.easeOut(duration: 0.25)) { editing = false } }).transition(.opacity) } }
            .fullScreenCover(isPresented: $showsScan) { FriendQRScanView(myName: me?.name ?? "", friendCount: 0) { _ in } }
            .fullScreenCover(isPresented: $showsQR) { SelfQRChekiHost(onScan: { showsQR = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showsScan = true } }, onClose: { showsQR = false }) }
            .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) { ShareSheet(activityItems: shareItems ?? []) { _ in shareItems = nil }.presentationDetents([.medium, .large]) }
            .fullScreenCover(isPresented: Binding(get: { openDay != nil }, set: { if !$0 { openDay = nil } })) {
                ProfileDayPhotosView(day: openDay ?? Date(), photos: openDay.map { photos(on: $0) } ?? [], onClose: { openDay = nil })
            }
            .sheet(isPresented: $showsIcon) {
                let cur = me?.profileImageData.flatMap { UIImage(data: $0) }
                let recent = (me?.photos ?? []).sorted { $0.captureDate > $1.captureDate }.prefix(8).map { p in (id: p.id.uuidString, image: V64Images.image(key: "ip\(p.id)", data: p.imageData, maxPixel: 240), label: Calendar.current.isDateInYesterday(p.captureDate) ? "きのう" : nil as String?) }
                IconPickerV81Sheet(name: me?.name ?? "", current: cur, recent: Array(recent), onSave: { saveIcon($0) }, onClose: { showsIcon = false }).presentationDetents([.large]).presentationBackground(Color(hex: "141516"))
            }
    }

    private var data: ProfileV82Data {
        var d = ProfileV82Data()
        guard let me else { d.name = "ゲスト"; d.cells = ProfileArchiveRules.cells([], now: Date()); return d }
        d.name = me.name; d.username = me.username; d.avatar = me.profileImageData.flatMap { UIImage(data: $0) }; d.tags = me.selfTags
        let now = Date()
        let photos = me.photos
        let dates = photos.map(\.captureDate)
        d.shots = photos.count
        d.streak = ProfileArchiveRules.streak(dates, now: now)
        d.since = ProfileArchiveRules.sinceLabel(dates.min(), now: now)
        d.cells = ProfileArchiveRules.cells(dates, now: now)
        d.opened = ProfileArchiveRules.openedDays(d.cells)
        for c in d.cells where c.kind == .opened {
            if let i = c.coverIndex { d.covers[c.day] = V64Images.image(key: "pc\(photos[i].id)", data: photos[i].imageData, maxPixel: 360) }
        }
        d.trips = me.groups.filter { !$0.isPersonalSpace }.sorted { ($0.tripStart ?? $0.creationDate) > ($1.tripStart ?? $1.creationDate) }.map { g in
            let f = DateFormatter(); f.dateFormat = "M/d"
            let range = g.tripStart.map { s in g.tripEnd.map { "\(f.string(from: s)) 〜 \(f.string(from: $0))" } ?? f.string(from: s) } ?? f.string(from: g.creationDate)
            return ProfileTripRow(id: g.id, name: g.name, range: range, count: g.photos.count, cover: V64Images.image(key: "tg\(g.id)", data: g.iconImageData, maxPixel: 160))
        }
        d.recordName = recordName
        return d
    }

    /// その 日の ひらいた 写真(古い 順 ・ 表示用に 縮めた 物)
    private func photos(on day: Date) -> [UIImage] {
        let cal = Calendar.current, now = Date()
        return (me?.photos ?? []).filter { cal.isDate($0.captureDate, inSameDayAs: day) && PhotoDevelop.isDeveloped(takenAt: $0.captureDate, now: now, calendar: cal) }
            .sorted { $0.captureDate < $1.captureDate }
            .compactMap { V64Images.image(key: "pd\($0.id)", data: $0.imageData, maxPixel: 1200) }
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
                    else { LinearGradient(colors: [Color(hex: "61D278"), Color(hex: "EE5E9C")], startPoint: .topLeading, endPoint: .bottomTrailing).overlay(Text(String(name.prefix(1))).font(Typo.ui(900, 120)).foregroundStyle(.white.opacity(0.9))) }
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
