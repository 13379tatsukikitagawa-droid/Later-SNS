// TagScreen.swift
// 撮影の前のタグ画面(6章)。昼は白・夜は黒。
// - 主役はカラフルなダイモテープ。ほかは白と黒、うすい文字だけ
// - プレビュー帯(撮影画面では、こう見えます)に、場所テープ+タグ2枠
// - 書く欄(最初から見えている)・3段の横流れ(MarqueeRow)
// - 場所は自動(市区町村だけ。緯度経度は持たない・保存しない)
// - タグは2つまで(TagRules.maxCount)。その日の下書きは TagDraft(UserDefaults・日ごと)

import SwiftUI
import CoreLocation
internal import Combine

// MARK: - 言葉のデータ(感情19こ+場面6こ。感情が8割弱)

enum TagDictionary {
    static let emotions = [
        "ねむい", "わくわく", "ほっとした", "ぼんやり", "がんばった", "しあわせ",
        "だるい", "そわそわ", "さみしい", "むねがいっぱい", "ごきげん", "もやもや",
        "たのしい", "おだやか", "きんちょう", "めんどう", "ふわふわ", "じーん", "ときめき"
    ]
    /// 場面ことば(5〜6こ。増やしすぎない)
    static let scenes = ["朝", "散歩", "コーヒー", "電車", "ごはん", "夕方"]

    static var all: [String] { emotions + scenes }

    /// テープに出す文字。場面ことばだけ「#」をつける(タグの値には # を入れない)
    static func display(_ word: String) -> String {
        scenes.contains(word) ? "#" + word : word
    }
}

// MARK: - ルール

enum TagRules {
    /// 選べるタグの数(場所は別に自動で1つ)。あとで3に戻すときは、ここだけ直す
    static let maxCount = 2
    static let maxLength = 16

    /// 先頭の「#」「＃」と前後の空白を取り、16文字までに切る
    static func clean(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while let first = text.first, first == "#" || first == "＃" {
            text.removeFirst()
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(text.prefix(maxLength))
    }

    /// 追加してよいか(からは追加しない・同じものは追加しない・上限まで)
    static func canAdd(_ tag: String, to tags: [String]) -> Bool {
        !tag.isEmpty && !tags.contains(tag) && tags.count < maxCount
    }
}

// MARK: - その日の下書き(端末の中だけ)

enum TagDraft {
    private static var key: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return "later.tagDraft." + formatter.string(from: Date())
    }

    static func load() -> [String] {
        Array((UserDefaults.standard.stringArray(forKey: key) ?? []).prefix(TagRules.maxCount))
    }

    static func save(_ tags: [String]) {
        UserDefaults.standard.set(tags, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}


// MARK: - 場所(市区町村だけ)

/// 現在地から市区町村の名前だけを取る。緯度経度は、どこにも保存しない(ここでも持ちつづけない)。
/// 許可がない・取れないときは nil のまま(止めない・エラーも出さない)。
final class CapturePlaceProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var placeName: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var requested = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func request() {
        guard !requested else { return }
        requested = true
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default: break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        manager.requestLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.geocoder.reverseGeocodeLocation(location) { placemarks, error in
                guard error == nil, let placemark = placemarks?.first else { return }
                // 市区町村(例:渋谷区・横浜市)。それより細かい住所は使わない
                let name = placemark.locality ?? placemark.subAdministrativeArea
                Task { @MainActor [weak self] in self?.placeName = name }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

// MARK: - 登場・退場のずらし(9章 ①・③)

enum TagScreenPhase: Equatable {
    case hidden, shown, leaving
}

private struct Stagger: ViewModifier {
    let phase: TagScreenPhase
    /// 登場の順番(ms)
    let inDelay: Double
    /// 退場の順番(14ms ずつ)
    let outIndex: Int
    var reduceMotion = false
    var dx: CGFloat = 0
    var dy: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .offset(x: phase == .hidden && !reduceMotion ? dx : 0,
                    y: phase == .leaving ? (reduceMotion ? 0 : -14) : (phase == .hidden && !reduceMotion ? dy : 0))
            .opacity(phase == .shown ? 1 : 0)
            .animation(animation, value: phase)
    }

    private var animation: Animation {
        switch phase {
        case .leaving: FlowMotion.out(0.24).delay(Double(outIndex) * 0.014)
        default: FlowMotion.out(reduceMotion ? 0.25 : 0.6).delay(reduceMotion ? inDelay / 1000 / 8 : inDelay / 1000)
        }
    }
}

/// 弧をえがいて飛ぶ(途中で 44pt 浮く)
private struct ArcFlight: ViewModifier, Animatable {
    var progress: CGFloat
    let from: CGPoint
    let to: CGPoint

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = progress
        let control = CGPoint(x: (from.x + to.x) / 2, y: min(from.y, to.y) - 88)
        let x = (1 - t) * (1 - t) * from.x + 2 * (1 - t) * t * control.x + t * t * to.x
        let y = (1 - t) * (1 - t) * from.y + 2 * (1 - t) * t * control.y + t * t * to.y
        content.position(x: x, y: y)
    }
}

/// はがれて落ちる(少し持ちあがり、右下に傾いて落ちる)
private struct Peel: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(on ? 14 : 0), anchor: .topLeading)
            .offset(x: on ? 10 : 0, y: on ? 26 : 0)
            .opacity(on ? 0 : 1)
    }
}

private struct TapeFlightItem: Identifiable, Equatable {
    let id = UUID()
    let word: String
    let from: CGPoint
    let to: CGPoint
    var launched = false
}

// MARK: - プレビュー帯(主役)

/// 撮影画面では、こう見えます。流れの「カード → ファインダー」のコピーでも同じものを使う
struct TagPreviewCard: View {
    enum Slot: Equatable {
        case tag(String)
        case draft(String)
        case empty
        /// 飛んでいる途中(枠は空のまま見せる)
        case incoming
    }

    let colors: CaptureColors
    let place: String?
    let slots: [Slot]
    var glow: Bool = false
    var wobble: Int = 0
    var showsLabel = true
    var reduceMotion = false
    var onTapTag: (String) -> Void = { _ in }
    var onSlotFrame: (Int, CGRect) -> Void = { _, _ in }
    var coordinateSpaceName: String = "tagScreen"

    @State private var breathe = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        ZStack(alignment: .topLeading) {
            shape.fill(colors.card.color)

            // 下の方の、サンライズ色のにじみ(5秒でゆっくり明るさが上下)
            ZStack {
                RadialGradient(colors: [PaletteHex(rgb: 0xFF6A1A).color.opacity(0.55), .clear], center: UnitPoint(x: 0.3, y: 1.1), startRadius: 0, endRadius: 150)
                RadialGradient(colors: [PaletteHex(rgb: 0xFF7AB6).color.opacity(0.4), .clear], center: UnitPoint(x: 0.75, y: 1.15), startRadius: 0, endRadius: 140)
                RadialGradient(colors: [PaletteHex(rgb: 0xFFD60A).color.opacity(0.25), .clear], center: UnitPoint(x: 0.5, y: 1.3), startRadius: 0, endRadius: 120)
            }
            .opacity(breathe ? 1 : 0.65)
            .clipShape(shape)
            .allowsHitTesting(false)

            if showsLabel {
                Text("撮影画面では、こう見えます")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.leading, 16)
                    .padding(.top, 14)
            }

            // 1行のまま。入りきらないときは横に流せる(折り返さない)
            ScrollView(.horizontal) {
            HStack(spacing: 9) {
                if let place {
                    DymoTape(kind: .place(place))
                        .modifier(WobbleEffect(trigger: wobble, enabled: !reduceMotion))
                }
                ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                    slotView(slot, index: index)
                }
            }
            .fixedSize()
            .padding(.leading, 16)
            .padding(.trailing, 16)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.bottom, 16)
        }
        .overlay(shape.strokeBorder(colors.cardStroke.color, lineWidth: 1))
        .overlay(
            // 貼れた瞬間、ふちが一瞬オレンジに光る(520ms)
            shape.strokeBorder(CaptureTint.orange, lineWidth: 2)
                .shadow(color: CaptureTint.orange.opacity(0.8), radius: 6)
                .opacity(glow ? 1 : 0)
                .animation(glow ? .easeOut(duration: 0.08) : .easeOut(duration: 0.44), value: glow)
                .allowsHitTesting(false)
        )
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { breathe = true }
        }
    }

    @ViewBuilder
    private func slotView(_ slot: Slot, index: Int) -> some View {
        ZStack {
            switch slot {
            case .draft(let text):
                DymoTape(kind: .draft(text))
            case .empty, .incoming:
                DymoTape(kind: .empty)
            case .tag:
                DymoTape(kind: .empty).opacity(0)
            }
            if case .tag(let word) = slot {
                DymoTape(kind: .word(word), maxWidth: 118)
                    .modifier(WobbleEffect(trigger: wobble, enabled: !reduceMotion))
                    .onTapGesture { onTapTag(word) }
                    .id(word)
                    .transition(.asymmetric(
                        insertion: reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity),
                        removal: reduceMotion ? .opacity : .modifier(active: Peel(on: true), identity: Peel(on: false))
                    ))
                    .accessibilityLabel("\(word)、はずす")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .fixedSize()
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(coordinateSpaceName)) } action: { onSlotFrame(index, $0) }
    }
}

/// プレビューのテープが、ぶるっとゆれる(±4°、340ms)
private struct WobbleEffect: ViewModifier {
    let trigger: Int
    let enabled: Bool

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, angle in
            view.rotationEffect(.degrees(enabled ? angle : 0))
        } keyframes: { _ in
            LinearKeyframe(-4, duration: 0.085)
            LinearKeyframe(4, duration: 0.085)
            LinearKeyframe(-2, duration: 0.085)
            LinearKeyframe(0, duration: 0.085)
        }
    }
}

// MARK: - 画面

struct TagScreen: View {
    /// 今日のこり(0 のときは「撮影へ」「つけずに撮る」を押せない)
    let left: Int
    let haptics: ExposureHaptics
    /// 選んだタグ(# なし)。持ち主は CaptureFlow(2こめ以降の引きつぎ・下書き)
    @Binding var tags: [String]
    let place: String?
    /// 「撮影へ」でカードがひろがっている間(ほかの部分を上へうすく)
    var leaving = false
    /// カードのコピーを CaptureFlow が上に出している間、もとのカードを隠す
    var hidesCard = false
    /// プレビュー帯の位置(画面の座標 .global)
    var onCardFrame: (CGRect) -> Void = { _ in }
    /// 戻る(Home へ)
    var onClose: () -> Void = {}
    /// 「撮影へ」(true)/「つけずに撮る」(false)
    var onStart: (_ withTags: Bool) -> Void = { _ in }

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    @State private var phase: TagScreenPhase = .hidden
    @State private var input = ""
    @FocusState private var inputFocused: Bool
    @State private var rows: [[String]] = []
    @State private var rowPhases: [Double] = [0, 0, 0]
    @State private var shakeCounts: [String: Int] = [:]
    @State private var fieldShake = 0
    @State private var wobble = 0
    @State private var glow = false
    @State private var incoming: Set<String> = []
    @State private var flights: [TapeFlightItem] = []
    @State private var slotFrames: [Int: CGRect] = [:]
    @State private var showRefuse = false
    /// 断りの一言(タグが多い / 今日は、ここまで)
    @State private var refuseText = ""

    private static let space = "tagScreen"
    private var colors: CaptureColors { .for(palette) }
    private var trimmedInput: String { TagRules.clean(input) }
    private var isFull: Bool { tags.count >= TagRules.maxCount }
    private var canShoot: Bool { left > 0 }
    private var stage: TagScreenPhase { leaving ? .leaving : phase }

    var body: some View {
        ZStack {
            colors.bg.color.ignoresSafeArea()

            GeometryReader { proxy in
            let compact = proxy.size.height < 560
            VStack(alignment: .leading, spacing: 0) {
                topBar
                    .modifier(Stagger(phase: stage, inDelay: 0, outIndex: 0, reduceMotion: reduceMotion))
                    .padding(.horizontal, 20)

                if !compact {
                Text("today's mood")
                    .font(CaptureFont.serifItalic(19))
                    .foregroundStyle(colors.sub.color)
                    .padding(.top, 12)
                    .padding(.horizontal, 28)
                    .modifier(Stagger(phase: stage, inDelay: 100, outIndex: 1, reduceMotion: reduceMotion))
                }

                headline
                    .padding(.top, 2)
                    .padding(.horizontal, 28)

                if !compact {
                Text("撮る前に、ひとこと。\(TagRules.maxCount)つまで。\n場所は、自動で入ります。")
                    .font(.system(size: 13, weight: .medium))
                    .lineSpacing(3)
                    .foregroundStyle(colors.sub.color)
                    .padding(.top, 10)
                    .padding(.horizontal, 28)
                    .modifier(Stagger(phase: stage, inDelay: 300, outIndex: 4, reduceMotion: reduceMotion))
                }

                previewCard
                    .frame(height: compact ? 92 : 108)
                    .padding(.horizontal, 20)
                    .padding(.top, compact ? 10 : 18)

                writeField
                    .padding(.horizontal, 20)
                    .padding(.top, compact ? 10 : 18)
                    .modifier(Stagger(phase: stage, inDelay: 440, outIndex: 5, reduceMotion: reduceMotion))

                HStack {
                    Text("きぶん・こと")
                        .font(.system(size: 11.5, weight: .bold))
                    Spacer()
                    Text("ながれることばを、さわると止まります")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(colors.sub.color)
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .modifier(Stagger(phase: stage, inDelay: 500, outIndex: 6, reduceMotion: reduceMotion))

                words
                    .padding(.top, 6)
                Spacer(minLength: 0)
            }
            // 幅は画面の幅だけ(流れる帯が長くても、カードや書く欄を右へ押し出さない)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
            }
            // v14 ④:撮影ボタンは画面の下(下端から 46pt)。中身がのびても、キーボードが出ても押し出されない
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ctaButtons
                    .frame(maxWidth: .infinity)
                    .background(colors.bg.color.ignoresSafeArea(edges: .bottom))
            }

            // 飛んでいるテープのコピー(いちばん上)
            ForEach(flights) { flight in
                DymoTape(kind: .word(flight.word))
                    .modifier(ArcFlight(progress: flight.launched ? 1 : 0, from: flight.from, to: flight.to))
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            if showRefuse {
                Text(refuseText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(colors.bg.color)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(colors.ink.color))
                    .padding(.bottom, 200)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showRefuse)
        .coordinateSpace(name: Self.space)
        .foregroundStyle(colors.ink.color)
        // キーボードが出ても、画面の組み立てを押しあげない(書く欄はキーボードより上にある)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear(perform: appear)
    }

    // MARK: 上の行

    private var topBar: some View {
        HStack {
            Button(action: close) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(colors.ink.color)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(colors.fill.color))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("戻る")

            Spacer()

            HStack(spacing: 7) {
                HStack(spacing: 3) {
                    ForEach(0..<FilmRoll.shotsPerDay, id: \.self) { index in
                        let used = index < FilmRoll.shotsPerDay - left
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(used ? CaptureTint.used : CaptureTint.orange)
                            .frame(width: 9, height: 12)
                            .scaleEffect(phase == .hidden && !reduceMotion ? 0.2 : 1)
                            .animation(FlowMotion.spring.delay(0.05 + Double(index) * 0.07), value: phase)
                    }
                }
                Text("のこり \(left)")
                    .font(CaptureFont.mono(11))
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Capsule().fill(colors.fill.color))
            .padding(.trailing, 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("のこり \(left) こま")
        }
        .padding(.top, 4)
    }

    /// 見出し。行ごとに下からマスクで切りあがる
    private var headline: some View {
        VStack(alignment: .leading, spacing: 0) {
            headlineLine("今日は、", delay: 150, outIndex: 2)
            headlineLine("どんな日?", delay: 230, outIndex: 3)
        }
        .accessibilityElement(children: .combine)
    }

    private func headlineLine(_ text: String, delay: Double, outIndex: Int) -> some View {
        Text(text)
            .font(CaptureFont.heading(36))
            .tracking(-1.8)
            .lineLimit(1)
            .frame(height: 42, alignment: .leading)
            .offset(y: stage == .hidden && !reduceMotion ? 44 : (stage == .leaving && !reduceMotion ? -14 : 0))
            .opacity(stage == .shown ? 1 : (stage == .hidden && !reduceMotion ? 1 : 0))
            .animation(stage == .leaving ? FlowMotion.out(0.24).delay(Double(outIndex) * 0.014)
                       : FlowMotion.out(0.6).delay(reduceMotion ? 0 : delay / 1000), value: stage)
            .clipped()
    }

    // MARK: プレビュー帯

    private var previewSlots: [TagPreviewCard.Slot] {
        var slots: [TagPreviewCard.Slot] = []
        var draftShown = false
        for index in 0..<TagRules.maxCount {
            if index < tags.count {
                let word = tags[index]
                slots.append(incoming.contains(word) ? .incoming : .tag(word))
            } else if !draftShown, !trimmedInput.isEmpty {
                slots.append(.draft(trimmedInput))
                draftShown = true
            } else {
                slots.append(.empty)
            }
        }
        return slots
    }

    private var previewCard: some View {
        TagPreviewCard(
            colors: colors,
            place: place,
            slots: previewSlots,
            glow: glow,
            wobble: wobble,
            reduceMotion: reduceMotion,
            onTapTag: { remove($0) },
            onSlotFrame: { index, frame in slotFrames[index] = frame },
            coordinateSpaceName: Self.space
        )
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onCardFrame($0) }
        .opacity(hidesCard ? 0 : 1)
        .modifier(Stagger(phase: phase, inDelay: 360, outIndex: 0, reduceMotion: reduceMotion))
    }

    // MARK: 書く欄

    private var writeField: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return HStack(spacing: 8) {
            Text("#")
                .font(CaptureFont.hand(22))
                .foregroundStyle(CaptureTint.orange)
            TextField("", text: $input, prompt: Text("じぶんの言葉で、かく").foregroundStyle(colors.sub.color.opacity(0.8)))
                .font(CaptureFont.hand(18))
                .foregroundStyle(colors.ink.color)
                .focused($inputFocused)
                .submitLabel(.done)
                .onSubmit(commitInput)
                .onChange(of: input) { _, value in
                    if value.count > TagRules.maxLength + 1 { input = String(value.prefix(TagRules.maxLength + 1)) }
                }
                .onChange(of: inputFocused) { _, focused in
                    if focused { haptics.captureFeather() }
                }
            if !trimmedInput.isEmpty {
                Button(action: commitInput) {
                    Text("追加")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(colors.ctaText.color)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(Capsule().fill(colors.ctaBG.color))
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .frame(height: 54)
        .background(shape.fill(colors.bg.color))
        .overlay(shape.strokeBorder(inputFocused ? colors.ink.color : colors.line.color, lineWidth: 1.5))
        .shadow(color: CaptureTint.orange.opacity(inputFocused ? 0.28 : 0), radius: 4)
        .animation(.easeOut(duration: 0.18), value: inputFocused)
        .animation(.easeOut(duration: 0.18), value: trimmedInput.isEmpty)
        .modifier(ShakeEffect(animatableData: CGFloat(fieldShake)))
        .animation(.linear(duration: 0.28), value: fieldShake)
    }

    // MARK: ことばの流れ

    @ViewBuilder
    private var words: some View {
        if voiceOver {
            // VoiceOver のときは流れを止めて、ふつうの一覧にする
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10, alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(TagDictionary.all, id: \.self) { word in
                    Button {
                        toggle(word, at: .zero)
                    } label: {
                        DymoTape(kind: .word(word), selected: tags.contains(word))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tags.contains(word) ? "\(word)、選択中" : word)
                }
            }
            .padding(.horizontal, 28)
        } else {
            VStack(spacing: 2) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    MarqueeRow(
                        words: row,
                        secondsPerLoop: reduceMotion ? MarqueeMath.reducedSeconds : MarqueeMath.rowSeconds[index % 3],
                        reversed: MarqueeMath.rowReversed[index % 3],
                        phase: rowPhases[index % 3],
                        selected: tags,
                        shakeCounts: shakeCounts,
                        coordinateSpaceName: Self.space,
                        onTap: { word, location in toggle(word, at: location) }
                    )
                    // 上段は右から、中段は左から、下段は右から、すべって入る
                    .modifier(Stagger(phase: stage, inDelay: 520 + Double(index) * 80, outIndex: 7 + index,
                                      reduceMotion: reduceMotion, dx: index == 1 ? -60 : 60, dy: 0))
                }
            }
            .mask(
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.07),
                    .init(color: .black, location: 0.93),
                    .init(color: .clear, location: 1),
                ], startPoint: .leading, endPoint: .trailing)
            )
        }
    }

    // MARK: ボタン

    private var ctaButtons: some View {
        VStack(spacing: 6) {
            CaptureShutterButton(enabled: canShoot, reduceMotion: reduceMotion, ink: colors.ink.color, bg: colors.bg.color, onRefused: refuseShoot) {
                start(withTags: !tags.isEmpty || !trimmedInput.isEmpty)
            }
            .modifier(Stagger(phase: stage, inDelay: 620, outIndex: 10, reduceMotion: reduceMotion))
            Text(canShoot ? "撮る" : "今日は おしまい")
                .font(.system(size: 13, weight: .heavy))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(colors.ink.color)
                .accessibilityHidden(true)
        }
        .padding(.top, 10)
        .padding(.bottom, 46 - 24)
    }

    // MARK: 動きとルール

    private func appear() {
        // ひらくたびに、ならびと各段のはじまり位置をランダムにする
        if rows.isEmpty {
            // v14:流れる帯は 2段(逆向き)
            rows = MarqueeMath.rows(TagDictionary.all.shuffled(), rowCount: 2)
            rowPhases = (0..<3).map { _ in Double.random(in: 0..<1) }
        }
        DispatchQueue.main.async { phase = .shown }
    }

    /// 流れのテープ(または VoiceOver の一覧)をタップ:選ぶ / 選び済みならはずす
    private func toggle(_ word: String, at location: CGPoint) {
        guard !leaving else { return }
        if tags.contains(word) {
            remove(word)
            return
        }
        guard TagRules.canAdd(word, to: tags) else {
            if isFull { refuse(word: word) }
            return
        }
        let index = tags.count
        let isSecond = index == 1
        let target = slotFrames[index].map { CGPoint(x: $0.minX + 40, y: $0.midY) }

        if reduceMotion || target == nil || location == .zero {
            withAnimation(FlowMotion.spring) { tags.append(word) }
            land(isSecond: isSecond)
            return
        }
        incoming.insert(word)
        tags.append(word)
        let flight = TapeFlightItem(word: word, from: location, to: target!)
        flights.append(flight)
        DispatchQueue.main.async {
            withAnimation(FlowMotion.io(0.42)) {
                if let i = flights.firstIndex(where: { $0.id == flight.id }) { flights[i].launched = true }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) { _ = incoming.remove(word) }
            land(isSecond: isSecond)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) {
            flights.removeAll { $0.id == flight.id }
        }
    }

    /// 着地:ふちが一瞬光る + ポン / カチッ
    private func land(isSecond: Bool) {
        // v14:タグを選ぶ = pop / 3つ目 = thud
        Haptics.play(tags.count >= TagRules.maxCount ? .thud : .pop)
        glow = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { glow = false }
    }

    private func remove(_ word: String) {
        guard !leaving else { return }
        haptics.captureFeather()
        incoming.remove(word)
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeIn(duration: 0.36)) {
            tags.removeAll { $0 == word }
        }
    }

    /// 3つ目:震える + プレビューの2枚がぶるっとゆれる + やわらかく2回
    private func refuse(word: String?) {
        // v14:4つ目 = warn +「タグは 3つまで」
        Haptics.play(.warn)
        showMessage("タグは \(TagRules.maxCount)つまで")
        if let word {
            shakeCounts[word, default: 0] += 1
        } else {
            fieldShake += 1
        }
        wobble += 1
    }

    private func commitInput() {
        let tag = trimmedInput
        guard !tag.isEmpty else { return }
        if tags.contains(tag) {
            input = ""
            return
        }
        guard TagRules.canAdd(tag, to: tags) else {
            refuse(word: nil)
            return
        }
        // 点線のテープが、そのまま本物になってぽんと出る
        withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) {
            tags.append(tag)
            input = ""
        }
        land(isSecond: tags.count == 2)
    }

    /// 一言を1.6秒だけ出す
    private func showMessage(_ text: String) {
        refuseText = text
        showRefuse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { if refuseText == text { showRefuse = false } }
    }

    /// のこりが 0 のときの「撮る」:触覚(warn)+「今日は、ここまで」
    private func refuseShoot() {
        Haptics.play(.warn)
        showMessage("今日は、ここまで")
    }

    private func start(withTags: Bool) {
        guard canShoot, !leaving else { return }
        inputFocused = false
        if withTags, TagRules.canAdd(trimmedInput, to: tags) {
            tags.append(trimmedInput)
        }
        input = ""
        onStart(withTags)
    }

    private func close() {
        inputFocused = false
        onClose()
    }
}

// MARK: - 撮影ボタン(v14 ④)

/// 直径 116pt の朝焼けの丸 + 中にレンズ + 外側に呼吸するリング(2.6秒)。
/// 押すと 0.9倍 → 離すと弾む。押した瞬間、光がぶわっと広がる(0.7秒)+ 白いフラッシュ。
struct CaptureShutterButton: View {
    let enabled: Bool
    let reduceMotion: Bool
    let ink: Color
    let bg: Color
    /// のこりがなくて押せないとき(触覚と一言は呼び出し側)
    var onRefused: () -> Void = {}
    let action: () -> Void

    static let diameter: CGFloat = 116
    @State private var burst = false
    @State private var flash = false

    var body: some View {
        Button {
            guard enabled else {
                onRefused()
                return
            }
            Haptics.play(.pop)
            if reduceMotion {
                action()
                return
            }
            withAnimation(.easeOut(duration: 0.7)) { burst = true }
            withAnimation(.easeOut(duration: 0.08)) { flash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { withAnimation(.easeOut(duration: 0.5)) { flash = false } }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { action() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { burst = false }
        } label: {
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let b = reduceMotion ? 0 : (1 - cos(t * 2 * .pi / 2.6)) / 2
                    Circle()
                        .strokeBorder(ink, lineWidth: 3)
                        .scaleEffect(1 + 0.07 * b)
                        .opacity(1 - 0.55 * b)
                }
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: "FFD6A8"), Color(hex: "FF6A1A"), Color(hex: "FF3D7F")], center: UnitPoint(x: 0.32, y: 0.26), startRadius: 0, endRadius: 70))
                    .overlay(Circle().strokeBorder(bg, lineWidth: 3))
                    .padding(10)
                    .shadow(color: Color(hex: "FF503C").opacity(0.55), radius: 15, y: 10)
                    .scaleEffect(burst ? 24 : 1)
                    .opacity(burst ? 0 : 1)
                Circle()
                    .fill(RadialGradient(colors: [.white, Color(hex: "BBCCDD"), Color(hex: "333355")], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 20))
                    .frame(width: 34, height: 34)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 6).padding(-6))
                    .opacity(burst ? 0 : 1)
            }
            .frame(width: Self.diameter, height: Self.diameter)
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.9))
        .overlay {
            Color.white
                .opacity(flash ? 0.95 : 0)
                .frame(width: 2000, height: 3000)
                .allowsHitTesting(false)
        }
        .accessibilityLabel(enabled ? "撮る" : "今日は おしまい")
        .accessibilityHint("撮影の画面へ進みます。タグがなくても撮れます")
    }
}
