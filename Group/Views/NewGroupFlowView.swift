import SwiftUI
import SwiftData
import PhotosUI
import UIKit

// MARK: - グループ作成(3ステップ)

/// グループ作成:① 名前 → ② 顔 → [グループをつくる] → ③ できた+呼ぶ。下から上がる全画面で開く。
/// ①は左上の ✕ で閉じる(入力は破棄・確認なし)。②の左上は「←」(①へ)。
/// グループが CloudKit に作られるのは、②の「グループをつくる」を押した瞬間だけ。③には戻る・✕ がない。
struct NewGroupFlowView: View {
    /// 最初から入れておくグループ名(空の GROUP 画面のステッカーから。nil なら空)
    var initialName: String? = nil
    let onClose: () -> Void

    private enum Step: Int { case name = 1, face, invite }
    private enum FaceTab: String, CaseIterable { case photo, camera, colorOnly }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]

    @State private var step: Step = .name
    @State private var name = ""
    @State private var memberLimit = GroupMembershipPolicy.maxMembersPerGroup
    /// 手で選んだ色(nil なら名前から決める)
    @State private var chosenColor: Int?
    @FocusState private var isNameFocused: Bool
    @State private var discBump = false

    @State private var faceTab: FaceTab = .photo
    @State private var recent = RecentPhotos()
    @State private var sourceImage: UIImage?
    @State private var faceScale: CGFloat = 1
    @State private var faceOffset: CGSize = .zero
    @State private var dragBase: CGSize?
    @State private var tone: FaceTone = .original
    @State private var preview: UIImage?
    @State private var develop: Double = 1
    @State private var isPickingAlbum = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var isShowingCamera = false

    @State private var isCreating = false
    @State private var burst = false
    @State private var burstExpanded = false
    @State private var errorMessage: String?
    @State private var createdGroup: LaterGroup?
    @State private var popStart: Date?
    @State private var popIndex = 0
    @State private var inviteAppeared = false
    @State private var haptics = ExposureHaptics()

    private static let nameSuggestions = ["帰り道の4人", "朝活ぐみ", "しずかな会"]
    private static let warmText = Color(hex: "FFB078")

    private var currentUser: UserProfile? { UserProfile.current(from: profiles) }
    private var finalName: String { GroupNameRules.finalize(name) }
    private var colorIndex: Int { chosenColor ?? GroupPalette.index(forName: finalName) }
    private var initial: String { GroupNameRules.initial(of: name) }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            auraBackground

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    content
                        .id(step)
                        .transition(.opacity)
                        .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollBounceBehavior(.basedOnSize)
            }
            // キーボードが出ていても、ボタンが隠れない(キーボードの上に追従)
            .safeAreaInset(edge: .bottom) { bottomButton }

            if burst {
                Circle()
                    .fill(RadialGradient(colors: [.white, Color(hex: "FFD2AE"), .clear], center: .center, startRadius: 0, endRadius: 40))
                    .frame(width: 80, height: 80)
                    .scaleEffect(burstExpanded ? 20 : 0.5)
                    .opacity(burstExpanded ? 0 : 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .onAppear { haptics.prepare() }
        .onDisappear { haptics.tearDown() }
        .photosPicker(isPresented: $isPickingAlbum, selection: $pickerItem, matching: .images, photoLibrary: .shared())
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    choose(image)
                }
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CircleCameraView(haptics: haptics) { image in
                isShowingCamera = false
                faceTab = .photo
                choose(image)
            } onClose: {
                isShowingCamera = false
                faceTab = sourceImage == nil ? .photo : faceTab
            }
        }
        .onChange(of: createdGroup?.members.count) { old, new in
            // ③を開いている間に、だれかが入った:その点がオレンジで現れて白に(触覚なし)
            guard let old, let new, new > old else { return }
            popIndex = new - 1
            popStart = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { popStart = nil }
        }
    }

    // MARK: - 上部(✕ / ← と、進み具合のバー)

    private var topBar: some View {
        VStack(spacing: 12) {
            HStack {
                switch step {
                case .name:
                    circleButton("xmark", label: "閉じる", action: onClose)
                case .face:
                    circleButton("arrow.left", label: "もどる") { go(to: .name) }
                case .invite:
                    Color.clear.frame(width: 44, height: 44)
                }
                Spacer()
            }
            HStack(spacing: 6) {
                ForEach(1...3, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(index <= step.rawValue ? 0.9 : 0.18))
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 4)
            .accessibilityElement()
            .accessibilityLabel("ステップ \(step.rawValue) / 3")
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private func circleButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var auraBackground: some View {
        let colors = GroupRingMath.auraPalettes[colorIndex]
        return GeometryReader { proxy in
            Ellipse()
                .fill(RadialGradient(colors: [colors[0].opacity(0.32), colors[1].opacity(0.12), .clear], center: .center, startRadius: 0, endRadius: proxy.size.width * 0.7))
                .frame(width: proxy.size.width * 1.5, height: 520)
                .position(x: proxy.size.width / 2, y: 120)
                .blur(radius: 30)
                .animation(.easeInOut(duration: 0.6), value: colorIndex)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .name: nameStep
        case .face: faceStep
        case .invite: inviteStep
        }
    }

    // MARK: - ① 名前

    private var nameStep: some View {
        VStack(spacing: 0) {
            GroupCircle(initial: initial, colorIndex: colorIndex, memberLimit: memberLimit, litCount: 1, diameter: 224,
                        discScale: discBump ? 1.04 : 1)
                .padding(.top, 18)
            heading("グループに、\n名前をつけます。", nil)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("グループの名前")
                    Spacer()
                    Text("\(finalName.count) / \(GroupNameRules.maxLength)").monospacedDigit()
                }
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Color(hex: "8E8E93"))
                TextField("", text: $name, prompt: Text("たとえば「帰り道の4人」").foregroundStyle(.white.opacity(0.25)))
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .lineLimit(1)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onSubmit { isNameFocused = false }
                    .onChange(of: name) { _, value in
                        let clean = GroupNameRules.sanitizeInput(value)
                        if clean != value { name = clean }
                        bumpDisc()
                    }
                    .accessibilityLabel("グループの名前")
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 78)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(isNameFocused ? 0.55 : 0.12), lineWidth: 1))
            .padding(.horizontal, 24)
            .padding(.top, 22)

            limitStepper
                .padding(.horizontal, 24)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 10) {
                Text("思いつかないときは")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(hex: "8E8E93"))
                OnboardingFlowLayout(spacing: 8) {
                    ForEach(Self.nameSuggestions, id: \.self) { suggestion in
                        Button {
                            haptics.playTransient(intensity: 0.25, sharpness: 0.4)
                            name = suggestion
                        } label: {
                            Text(suggestion)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(.white.opacity(0.08)))
                                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Text("みんなに見える名前です。実名や学校名は避けましょう。")
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: "6B6B70"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 20)
        }
        .onAppear {
            if let initialName, name.isEmpty { name = GroupNameRules.sanitizeInput(initialName) }
            isNameFocused = true
        }
    }

    private var limitStepper: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("人数の上限").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text("4〜8人。あとから変えられます").font(.system(size: 11)).foregroundStyle(Color(hex: "8E8E93"))
            }
            Spacer()
            HStack(spacing: 14) {
                stepButton("minus", enabled: memberLimit > GroupMembershipPolicy.memberLimitRange.lowerBound) { memberLimit -= 1 }
                Text("\(memberLimit)人")
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                stepButton("plus", enabled: memberLimit < GroupMembershipPolicy.memberLimitRange.upperBound) { memberLimit += 1 }
            }
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 64)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.05)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("人数の上限、\(memberLimit)人")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if memberLimit < 8 { memberLimit += 1 }
            case .decrement: if memberLimit > 4 { memberLimit -= 1 }
            @unknown default: break
            }
        }
    }

    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            haptics.playTransient(intensity: 0.25, sharpness: 0.4)
            withAnimation(.easeOut(duration: 0.2)) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(.white.opacity(0.1)))
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }

    // MARK: - ② 顔

    private var faceHeading: (String, String) {
        if sourceImage != nil { return ("いい顔です。\nこれでいきますか。", "ドラッグで位置を、つまみで大きさをあわせられます。") }
        if faceTab == .colorOnly { return ("色と頭文字で、\n顔にします。", "写真は、あとからいつでも足せます。") }
        return ("グループの、\n顔になる写真を。", "あとから、いつでも変えられます。")
    }

    private var faceStep: some View {
        VStack(spacing: 0) {
            GroupCircle(image: preview, initial: initial, colorIndex: colorIndex, memberLimit: memberLimit, litCount: 1,
                        diameter: 256, discScale: discBump ? 1.04 : 1, develop: develop)
                .padding(.top, 10)
                .gesture(sourceImage == nil ? nil : dragGesture)
                .accessibilityHint(sourceImage == nil ? "" : "ドラッグで位置をあわせられます")
            heading(faceHeading.0, faceHeading.1)

            tabs
                .padding(.horizontal, 24)
                .padding(.top, 20)

            Group {
                switch faceTab {
                case .photo:
                    if sourceImage != nil { adjustPanel } else { recentRow }
                case .camera:
                    Text("カメラをひらいています…")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color(hex: "8E8E93"))
                        .padding(.top, 20)
                case .colorOnly:
                    swatches
                }
            }
            .padding(.top, 16)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Self.warmText)
                    .padding(.top, 14)
                    .transition(.opacity)
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            tab(.photo, "写真", "photo")
            tab(.camera, "カメラ", "camera")
            tab(.colorOnly, "色だけ", "circle.lefthalf.filled")
        }
    }

    private func tab(_ value: FaceTab, _ title: String, _ icon: String) -> some View {
        let selected = faceTab == value
        return Button {
            switch value {
            case .camera:
                faceTab = .camera
                isShowingCamera = true
            case .colorOnly:
                // 写真を選んでいたら、外れる(色だけの顔になる)
                withAnimation(.easeOut(duration: 0.25)) {
                    faceTab = .colorOnly
                    clearPhoto()
                }
            case .photo:
                withAnimation(.easeOut(duration: 0.25)) { faceTab = .photo }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                Text(title).font(.system(size: 13.5, weight: .semibold))
            }
            .foregroundStyle(selected ? .black : .white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Capsule().fill(selected ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.white.opacity(0.08))))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// 最近の写真(左端は「アルバム」タイル)。許可がないときは「アルバム」だけ
    private var recentRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button(action: openAlbum) {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle").font(.system(size: 20))
                            Text("アルバム").font(.system(size: 11.5, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .frame(width: 74, height: 92)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1))
                    }
                    .buttonStyle(PressScaleStyle())

                    if recent.access == .granted {
                        ForEach(recent.thumbnails, id: \.id) { item in
                            Button { chooseRecent(item.id, thumbnail: item.image) } label: {
                                Image(uiImage: item.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 74, height: 92)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(PressScaleStyle())
                            .accessibilityLabel("最近の写真")
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .mask(HStack(spacing: 0) { Color.black; LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: 30) })

            Text(recent.access == .denied ? "写真の許可がないので、色だけでも作れます" : "顔や名前が写っていない写真が、おすすめです。")
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: "6B6B70"))
                .padding(.horizontal, 24)
        }
    }

    /// 写真を選んだあと:大きさ・色あい・ホームでの見え方
    private var adjustPanel: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Text("大きさ").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(.white)
                Slider(value: $faceScale, in: FaceImageRenderer.scaleRange)
                    .tint(.white)
                    .onChange(of: faceScale) { _, _ in
                        faceOffset = FaceImageRenderer.clampOffset(faceOffset, scale: faceScale)
                        renderPreview()
                    }
                    .accessibilityLabel("大きさ")
            }
            HStack(spacing: 8) {
                ForEach(FaceTone.allCases) { value in
                    Button {
                        haptics.playTransient(intensity: 0.25, sharpness: 0.4)
                        tone = value
                        renderPreview()
                    } label: {
                        Text(value.label)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(tone == value ? .black : .white)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(Capsule().fill(tone == value ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.white.opacity(0.08))))
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityAddTraits(tone == value ? .isSelected : [])
                }
            }
            HStack(spacing: 14) {
                // ホームのグループ列の1つぶん(直径40pt)
                VStack(spacing: 4) {
                    ZStack {
                        GroupFace(iconData: preview?.jpegData(compressionQuality: 0.7), initial: initial, auraIndex: colorIndex, diameter: 30)
                        GroupLightRing(memberCount: memberLimit, posted: 1, diameter: 40)
                    }
                    .frame(width: 40, height: 40)
                    Text(finalName).font(.system(size: 9.5, weight: .medium)).foregroundStyle(.white.opacity(0.88)).lineLimit(1).frame(maxWidth: 56)
                    Text("1 / \(memberLimit)").font(.system(size: 8.5, design: .monospaced)).foregroundStyle(Color(hex: "8E8E93"))
                }
                .accessibilityHidden(true)
                Text("ホームでの見え方")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color(hex: "BCBBC0"))
                Spacer()
                Button {
                    haptics.playTransient(intensity: 0.25, sharpness: 0.4)
                    withAnimation(.easeOut(duration: 0.25)) { clearPhoto() }
                } label: {
                    Text("えらびなおす")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 34)
                        .background(Capsule().fill(.white.opacity(0.1)))
                }
                .buttonStyle(PressScaleStyle())
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.05)))
        .padding(.horizontal, 24)
    }

    private var swatches: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ForEach(0..<GroupPalette.count, id: \.self) { index in
                    let colors = GroupRingMath.auraPalettes[index]
                    let selected = colorIndex == index
                    Button {
                        haptics.playTransient(intensity: 0.25, sharpness: 0.4)
                        withAnimation(.easeOut(duration: 0.2)) { chosenColor = index }
                        bumpDisc()
                    } label: {
                        Circle()
                            .fill(LinearGradient(colors: [colors[0], colors[1]], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 36, height: 36)
                            .overlay(Circle().strokeBorder(.white, lineWidth: selected ? 2 : 0).padding(-4))
                            .scaleEffect(selected ? 1.12 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("色 \(index + 1)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            Text("写真がなくても、色と頭文字で、ちゃんと顔になります。")
                .font(.system(size: 11.5))
                .foregroundStyle(Color(hex: "8E8E93"))
        }
        .padding(.horizontal, 24)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragBase == nil { dragBase = faceOffset }
                guard let base = dragBase else { return }
                // 円板(直径256×0.74)の上の動き → 正方形の一辺に対する割合
                let disc = 256 * 0.74 * faceScale
                faceOffset = FaceImageRenderer.clampOffset(
                    CGSize(width: base.width + value.translation.width / disc, height: base.height + value.translation.height / disc),
                    scale: faceScale
                )
                renderPreview()
            }
            .onEnded { _ in dragBase = nil }
    }

    // MARK: - ③ できた+呼ぶ

    @ViewBuilder
    private var inviteStep: some View {
        if let group = createdGroup {
            let members = max(1, group.members.count)
            let limit = GroupPalette.clampLimit(group.memberLimit)
            VStack(spacing: 0) {
                GroupCircle(image: group.iconImageData.flatMap(UIImage.init(data:)), initial: initial, colorIndex: colorIndex,
                            memberLimit: limit, litCount: members, diameter: 196, popStart: popStart, popIndex: popIndex)
                    .padding(.top, 6)
                HStack(spacing: 8) {
                    (Text("\(members)").bold() + Text(" / \(limit)人"))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: false))
                    Text(members >= limit ? "満員" : "あと\(limit - members)人")
                        .foregroundStyle(members >= limit ? Color(hex: "8E8E93") : Self.warmText)
                }
                .font(.system(size: 13))
                .padding(.top, 10)
                .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.5), value: members)

                heading("グループが、\nできました。", "つぎは、呼ぶ人を。入った人から、点が光ります。")
                    .modifier(InviteStagger(index: 0, appeared: inviteAppeared, reduceMotion: reduceMotion))
                InviteCard(group: group, summary: GroupRingMath.summaries(for: [group], now: Date())[0], haptics: haptics, onShowQR: { url in
                    inviteQR = url
                })
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .modifier(InviteStagger(index: 1, appeared: inviteAppeared, reduceMotion: reduceMotion))
            }
            .onAppear { inviteAppeared = true }
            .overlay {
                if let inviteQR {
                    InviteQROverlay(url: inviteQR, auraIndex: colorIndex) { self.inviteQR = nil }
                }
            }
        }
    }

    @State private var inviteQR: URL?

    // MARK: - 下のボタン

    @ViewBuilder
    private var bottomButton: some View {
        switch step {
        case .name:
            primaryButton("つぎへ", enabled: !finalName.isEmpty) { go(to: .face) }
        case .face:
            primaryButton(isCreating ? "つくっています…" : "グループをつくる", enabled: !isCreating && !finalName.isEmpty, action: create)
        case .invite:
            primaryButton("ホームで、見る", enabled: true, action: onClose)
        }
    }

    private func primaryButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(enabled ? .black : Color(hex: "8E8E93"))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Capsule().fill(enabled ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.white.opacity(0.12))))
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
        .disabled(!enabled)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }

    // MARK: - 共通

    private func heading(_ title: String, _ description: String?) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 27, weight: .bold))
                .tracking(-0.045 * 27)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            if let description {
                Text(description)
                    .font(.system(size: 12.5))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: "BCBBC0"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
    }

    private func go(to next: Step) {
        isNameFocused = false
        errorMessage = nil
        withAnimation(.easeInOut(duration: reduceMotion ? 0.2 : 0.45)) { step = next }
    }

    /// 円板が 1.04 倍にぽんと跳ねて戻る(0.26秒)
    private func bumpDisc() {
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.13)) { discBump = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { withAnimation(.easeIn(duration: 0.13)) { discBump = false } }
    }

    // MARK: - 写真

    private func openAlbum() {
        Task {
            await recent.requestIfNeeded()
            isPickingAlbum = true
        }
    }

    private func chooseRecent(_ id: String, thumbnail: UIImage) {
        haptics.playTransient(intensity: 0.25, sharpness: 0.4)
        choose(thumbnail)
        Task {
            if let full = await recent.fullImage(id: id) {
                sourceImage = full
                renderPreview()
            }
        }
    }

    /// 写真を選んだ:1.5秒で、ぼかし+うす白+低い彩度 → くっきり・色づく(現像)
    private func choose(_ image: UIImage) {
        sourceImage = image
        faceScale = 1
        faceOffset = .zero
        tone = .original
        renderPreview()
        faceTab = .photo
        guard !reduceMotion else { develop = 1; return }
        develop = 0
        withAnimation(.easeOut(duration: 1.5)) { develop = 1 }
        bumpDisc()
    }

    private func clearPhoto() {
        sourceImage = nil
        preview = nil
        faceScale = 1
        faceOffset = .zero
        tone = .original
    }

    private func renderPreview() {
        guard let sourceImage else { preview = nil; return }
        preview = FaceImageRenderer.render(sourceImage, scale: faceScale, offset: faceOffset, tone: tone, side: 512)
    }

    // MARK: - 作成

    /// 「グループをつくる」:強く1回 → 中央から光が広がる(1.1秒)→ 0.52秒後に③(保存が終わっていれば)。
    /// 保存に失敗したら②にとどまり、「つくれませんでした。もういちど」(グループは作られていない)。
    private func create() {
        guard !isCreating, let user = currentUser else { return }
        guard let cloudKitManager = CloudKitManager.current else {
            errorMessage = "つくれませんでした。もういちど"
            return
        }
        guard user.groups.filter({ !$0.isPersonalSpace }).count < GroupMembershipPolicy.maxGroupsPerUser else {
            errorMessage = "グループは、10個までです。"
            return
        }
        isCreating = true
        errorMessage = nil
        haptics.playTransient(intensity: 1.0, sharpness: 0.7)
        if !reduceMotion {
            burstExpanded = false
            burst = true
            DispatchQueue.main.async { withAnimation(.easeOut(duration: 1.1)) { burstExpanded = true } }
            bumpDisc()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) { burst = false; burstExpanded = false }
        }

        let group = LaterGroup(name: finalName, host: user, autoGenerateMission: false, isPrivate: true)
        group.memberLimit = memberLimit
        group.colorIndex = colorIndex
        group.joinedAt = Date()
        if let sourceImage {
            group.iconImageData = FaceImageRenderer.render(sourceImage, scale: faceScale, offset: faceOffset, tone: tone)?.jpegData(compressionQuality: 0.85)
        }
        _ = group.addMember(user)
        modelContext.insert(group)

        let started = Date()
        Task { @MainActor in
            let sharingService = GroupSharingService(container: cloudKitManager.container, modelContext: modelContext, cloudKitManager: cloudKitManager)
            do {
                try await sharingService.createGroup(group, hostProfile: user)
            } catch GroupSharingError.quotaExceeded(groupCreatedWithoutImages: true) {
                // iCloud の容量不足で、写真だけ除いて作れた(グループは作成ずみ)
            } catch {
                modelContext.delete(group)
                try? modelContext.save()
                isCreating = false
                withAnimation { errorMessage = "つくれませんでした。もういちど" }
                return
            }
            createdGroup = group
            let wait = max(0, 0.52 - Date().timeIntervalSince(started))
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
                isCreating = false
                go(to: .invite)
            }
        }
    }
}

/// ③:見出し → 招待カードの順に、80msずつずらして、ぼかしから浮かぶ(0.7秒)
private struct InviteStagger: ViewModifier {
    let index: Int
    let appeared: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        let shown = appeared || reduceMotion
        return content
            .blur(radius: shown ? 0 : 10)
            .offset(y: shown ? 0 : 14)
            .opacity(shown ? 1 : 0)
            .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.7).delay(0.1 + Double(index) * 0.08), value: appeared)
    }
}
