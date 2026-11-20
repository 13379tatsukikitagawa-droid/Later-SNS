import PhotosUI
import SwiftData
import SwiftUI

/// v106 §5:Trip の 設定(編集の とき だけ ・ 全画面 シート 1枚)。新しく つくる 流れ(NewGroupFlowView)は そのまま。
/// パスの 見本が 下の 項目に 合わせて すぐ 変わる。保存 = 名前 ・ 表紙(`GroupSettingsService.save`)。
/// ぬける / おわる は 今までの 確認 + 演出(GroupLeaveOverlay)に つなぐ。
struct TripSettingsV106Sheet: View {
    let group: LaterGroup
    let isHost: Bool
    var onInvite: () -> Void = {}
    var onLeave: () -> Void = {}
    var onEnd: () -> Void = {}
    var onClose: () -> Void = {}
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var name = ""
    @State private var cover: UIImage?
    @State private var coverData: Data?
    @State private var picker: PhotosPickerItem?
    @State private var chatOn = true
    @State private var hasDates = false
    @State private var color = 0
    @State private var start = Calendar.current.startOfDay(for: Date())
    @State private var end = Calendar.current.startOfDay(for: Date())
    @State private var pulse = false
    @State private var saving = false
    @State private var toast: String?
    @FocusState private var focused: Bool

    private var datesChanged: Bool {
        guard hasDates else { return false }
        let cal = Calendar.current
        guard let s = group.tripStart, let e = group.tripEnd else { return true }
        return !cal.isDate(s, inSameDayAs: start) || !cal.isDate(e, inSameDayAs: end)
    }
    private var colorChanged: Bool { color != resolvedColor }
    private var resolvedColor: Int {
        TripHubRules.resolveColors((try? modelContext.fetch(FetchDescriptor<LaterGroup>())) ?? [group])[group.id] ?? 0
    }
    private var changed: Bool { colorChanged || GroupEditRules.canSave(originalName: group.name, name: name, photoChanged: coverData != nil, colorChanged: false) || datesChanged }
    private var tripPhotos: [LaterPhoto] { Array(group.photos.sorted { $0.captureDate > $1.captureDate }.prefix(24)) }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "0B0B0C").ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        passPreview.frame(maxWidth: .infinity).padding(.top, 6)
                        coverRow
                        nameRow
                        whenRow
                        colorRow
                        membersRow
                        noticeRow
                        redZone
                    }.padding(.horizontal, 16).padding(.bottom, 60)
                }.scrollDismissesKeyboard(.interactively)
            }
            if let toast {
                Text(toast).font(LF.inter(700, 13)).foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.black.opacity(0.85), in: Capsule()).padding(.top, 70).transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            name = group.name
            cover = group.iconImageData.flatMap { UIImage(data: $0) }
            chatOn = !GroupChatStore.shared.isMuted(group.id)
            if let s = group.tripStart, let e = group.tripEnd { hasDates = true; start = s; end = e }
            color = resolvedColor
        }
        .onChange(of: start) { _, v in if end < v { end = v } }
        .onChange(of: name) { _, v in name = GroupNameRules.sanitizeInput(v); bump() }
        .onChange(of: picker) { _, item in
            guard let item else { return }
            Task {
                guard let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) else { return }
                pickedID = nil; select(img)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { Haptics.play(.tick); onClose() } label: { Text("とじる").font(LF.inter(700, 15)).foregroundStyle(.white.opacity(0.8)).frame(minWidth: 64, minHeight: 44, alignment: .leading) }
            Spacer()
            Text("Trip の 設定").font(LF.inter(900, 17)).foregroundStyle(.white)
            Spacer()
            Button { save() } label: {
                Text("保存").font(LF.inter(900, 14)).foregroundStyle(changed ? HV.ink : .white.opacity(0.3)).padding(.horizontal, 16).frame(height: 36, alignment: .center)
                    .background(changed ? HV.lime : Color.white.opacity(0.08), in: Capsule()).frame(minWidth: 64, minHeight: 44, alignment: .trailing)
            }.disabled(!changed || saving)
        }.padding(.horizontal, 16).padding(.top, 14)
    }

    // パスの 見本(250 × 330 ・ -2° ・ 角丸 22)
    private var passPreview: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(hex: "2A2326"))
                .overlay { if let cover { Image(uiImage: cover).resizable().scaledToFill() } }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("TRIP PASS").font(LF.mono(10)).tracking(2.4).foregroundStyle(HV.lime)
                Text(name.isEmpty ? " " : name).font(LF.serif(40)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5)
                Text("\(group.members.count)人").font(LF.mono(11)).foregroundStyle(.white.opacity(0.7))
            }.padding(18)
        }
        .frame(width: 250, height: 330)
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1))
        .rotationEffect(.degrees(-2))
        .scaleEffect(pulse ? 1.02 : 1)
        .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
        .accessibilityHidden(true)
    }

    private func bump() {
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.16)) { pulse = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { withAnimation(.timingCurve(0.3, 1.3, 0.5, 1, duration: 0.2)) { pulse = false } }
    }

    private func label(_ t: String) -> some View { Text(t).font(LF.mono(10.5)).tracking(2).foregroundStyle(.white.opacity(0.45)) }

    private var coverRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("COVER")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    PhotosPicker(selection: $picker, matching: .images) {
                        VStack(spacing: 6) { Image(systemName: "photo.on.rectangle").font(.system(size: 22, weight: .semibold)); Text("写真を えらぶ").font(LF.inter(700, 11)) }
                            .foregroundStyle(.white).frame(width: 84, height: 112).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    ForEach(tripPhotos, id: \.id) { p in
                        let img = V64Images.image(key: "tc\(p.id)", data: p.imageData, maxPixel: 240)
                        Button { if let full = UIImage(data: p.imageData) { select(full); pickedID = p.id } } label: {
                            ZStack { Color(hex: "222222"); if let img { Image(uiImage: img).resizable().scaledToFill() } }
                                .frame(width: 84, height: 112).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(pickedID == p.id && coverData != nil ? HV.lime : .clear, lineWidth: 3))
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }
    @State private var pickedID: UUID?

    private func select(_ img: UIImage) {
        let maxSide: CGFloat = 1200
        let s = min(1, maxSide / max(img.size.width, img.size.height))
        let size = CGSize(width: img.size.width * s, height: img.size.height * s)
        let scaled = UIGraphicsImageRenderer(size: size).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        cover = scaled; coverData = scaled.jpegData(compressionQuality: 0.85)
        Haptics.play(.sel); bump()
    }

    private var nameRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("NAME")
            HStack {
                TextField("", text: $name, prompt: Text("Trip の なまえ").foregroundColor(.white.opacity(0.3))).font(LF.inter(800, 18)).foregroundStyle(.white).focused($focused)
                Text("\(name.count) / \(GroupNameRules.maxLength)").font(LF.mono(11)).foregroundStyle(.white.opacity(0.4))
            }.padding(.horizontal, 16).frame(height: 54).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    /// v110 §5:日にち(週の 帯 ・ いま / これから / おわった に 使う)。なければ「日にちを 入れる」
    private var whenRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("WHEN")
            VStack(spacing: 0) {
                if hasDates {
                    HStack {
                        Text("はじまり").font(LF.inter(700, 14)).foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        DatePicker("", selection: $start, displayedComponents: .date).labelsHidden().tint(HV.lime)
                    }.padding(.horizontal, 16).frame(height: 52)
                    Divider().overlay(.white.opacity(0.08))
                    HStack {
                        Text("おわり").font(LF.inter(700, 14)).foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        DatePicker("", selection: $end, in: start..., displayedComponents: .date).labelsHidden().tint(HV.lime)
                    }.padding(.horizontal, 16).frame(height: 52)
                } else {
                    Button { Haptics.play(.pop); withAnimation(.easeOut(duration: 0.2)) { hasDates = true } } label: {
                        HStack { Image(systemName: "calendar.badge.plus").font(.system(size: 16, weight: .semibold)); Text("日にちを 入れる").font(LF.inter(800, 15)); Spacer() }
                            .foregroundStyle(HV.lime).padding(.horizontal, 16).frame(height: 54)
                    }.buttonStyle(.plain)
                }
            }.background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    /// v110 §3-1:Trip の 色(4つの 丸)。週の 帯の 線 ・ いまの カードの ふち ・ 日の ブロックに 使う
    private var colorRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("COLOR")
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { i in
                    Button { Haptics.play(.sel); withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { color = i } } label: {
                        Circle().fill(PopColor.trip(i)).frame(width: 40, height: 40)
                            .overlay(Circle().strokeBorder(.white, lineWidth: color == i ? 3 : 0))
                            .scaleEffect(color == i ? 1.12 : 1)
                            .frame(width: 48, height: 48).contentShape(Rectangle())
                    }.buttonStyle(PopPressStyle()).accessibilityLabel(["ピンク", "空色", "黄色", "ライム"][i]).accessibilityAddTraits(color == i ? .isSelected : [])
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var membersRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("MEMBERS")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(group.members, id: \.id) { m in
                        VStack(spacing: 6) {
                            ZStack {
                                Circle().fill(LinearGradient(colors: [Color(hex: "61D278"), Color(hex: "EE5E9C")], startPoint: .topLeading, endPoint: .bottomTrailing))
                                if let d = m.profileImageData, let i = UIImage(data: d) { Image(uiImage: i).resizable().scaledToFill() } else { Text(String(m.name.prefix(1))).font(LF.inter(900, 16)).foregroundStyle(.white) }
                            }.frame(width: 40, height: 40).clipShape(Circle())
                            Text(m.name).font(LF.inter(600, 11)).foregroundStyle(.white.opacity(0.8)).lineLimit(1).frame(width: 56)
                        }
                    }
                    Button { Haptics.play(.click); onInvite() } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 16, weight: .bold)).foregroundStyle(HV.lime).frame(width: 40, height: 40)
                                .overlay(Circle().strokeBorder(HV.lime.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                            Text("よぶ").font(LF.inter(700, 11)).foregroundStyle(HV.lime)
                        }.frame(minWidth: 44, minHeight: 44)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var noticeRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("NOTICE")
            Toggle(isOn: $chatOn) { Text("Trip の チャット").font(LF.inter(700, 15)).foregroundStyle(.white) }
                .tint(HV.lime).padding(.horizontal, 16).frame(minHeight: 54).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onChange(of: chatOn) { _, on in GroupChatStore.shared.setMuted(group.id, !on); Haptics.play(.sel) }
        }
    }

    private var redZone: some View {
        VStack(spacing: 10) {
            Button { Haptics.play(.warn); onLeave() } label: { redLabel("Trip を ぬける", "あなた だけ") }.buttonStyle(.plain)
            if isHost { Button { Haptics.play(.warn); onEnd() } label: { redLabel("Trip を おわる", "みんな") }.buttonStyle(.plain) }
        }.padding(.top, 6)
    }
    private func redLabel(_ t: String, _ sub: String) -> some View {
        HStack { Text(t).font(LF.inter(800, 15)); Spacer(); Text(sub).font(LF.inter(600, 12)).opacity(0.7) }
            .foregroundStyle(Color(hex: "FF453A")).padding(.horizontal, 16).frame(height: 54)
            .background(Color(hex: "FF453A").opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func save() {
        guard changed, !saving else { return }
        saving = true; focused = false
        Task { @MainActor in
            defer { saving = false }
            do {
                var ts: Date?? = nil, te: Date?? = nil
                if datesChanged { ts = .some(Calendar.current.startOfDay(for: start)); te = .some(Calendar.current.startOfDay(for: end)) }
                try await GroupSettingsService.save(group: group, name: name, iconData: coverData.map { Optional($0) }, colorIndex: nil, tripStart: ts, tripEnd: te, tripColor: colorChanged ? color : nil, context: modelContext)
                Haptics.play(.success)
                withAnimation { toast = "Trip を 更新しました" }
                try? await Task.sleep(for: .seconds(0.9))
                onClose()
            } catch {
                Haptics.play(.warn)
                withAnimation { toast = "つながって いません。あとで もう一度" }
                try? await Task.sleep(for: .seconds(2))
                withAnimation { toast = nil }
            }
        }
    }
}
