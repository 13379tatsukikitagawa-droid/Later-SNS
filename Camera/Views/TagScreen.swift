// TagScreen.swift
// 撮影の前のタグ画面(v22 H)。白と黒(と その間の灰)だけ。カラフルな色は使わない。
// - ガラスのカード:# 入力 ・ 0 / 3 ・ つけずに撮る / 撮る。えらんだタグは カードの上に 1行(白と黒を 交互)
// - いま、よく選ばれている:1列で流れる(MarqueeRow・ガラスの まる)
// - 場所は自動(市区町村だけ。緯度経度は持たない・保存しない)
// - タグは3つまで(TagRules.maxCount)。その日の下書きは TagDraft(UserDefaults・日ごと)

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
    static let maxCount = 3
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

// MARK: - 飛んでいるタグ

private struct TapeFlightItem: Identifiable, Equatable {
    let id = UUID()
    let word: String
    let from: CGPoint
    let to: CGPoint
    var launched = false
}

// MARK: - 画面

/// v22 H:撮影前の タグ画面(いまのアプリの形 ・ 白と黒だけ)。見本:later_v22.html の「タグ画面」(390×844)。
/// ✕ → 今日を撮る前に / 今日は、どんな日? / 撮る前に、えらぶ。3つまで。→ ガラスのカード(# 入力・0 / 3・つけずに撮る / 撮る)
/// → いま、よく選ばれている(1列で流れる)。キーボードの すぐ上、右に「追加」。
struct TagScreen: View {
    /// 今日のこり(0 のときは「撮る」「つけずに撮る」を押せない)
    let left: Int
    let haptics: ExposureHaptics
    /// 選んだタグ(# なし)。持ち主は CaptureFlow(2こめ以降の引きつぎ・下書き)
    @Binding var tags: [String]
    let place: String?
    /// 「撮る」でカードがひろがっている間(ほかの部分を上へうすく)
    var leaving = false
    /// カードのコピーを CaptureFlow が上に出している間、もとのカードを隠す
    var hidesCard = false
    /// カードの位置(画面の座標 .global)
    var onCardFrame: (CGRect) -> Void = { _ in }
    /// とじる(Home へ)
    var onClose: () -> Void = {}
    /// 「撮る」(true)/「つけずに撮る」(false)
    var onStart: (_ withTags: Bool) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    @State private var phase: TagScreenPhase = .hidden
    @State private var input = ""
    @FocusState private var inputFocused: Bool
    @State private var popular: [String] = []
    @State private var rowPhase = Double.random(in: 0..<1)
    @State private var shakeCounts: [String: Int] = [:]
    @State private var cardShake = 0
    @State private var sheen = 0
    @State private var incoming: Set<String> = []
    @State private var flights: [TapeFlightItem] = []
    @State private var chipsEnd: CGPoint = .zero
    @State private var showRefuse = false
    @State private var refuseText = ""
    @State private var placeholder = "雨の日"
    @State private var placeholderTask: Task<Void, Never>?

    private static let space = "tagScreen"
    private static let examples = ["雨の日", "放課後", "いい匂い", "部活", "帰り道", "テスト前"]
    private var trimmedInput: String { TagRules.clean(input) }
    private var isFull: Bool { tags.count >= TagRules.maxCount }
    private var canShoot: Bool { left > 0 }
    private var stage: TagScreenPhase { leaving ? .leaving : phase }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TagScreenBackground().ignoresSafeArea()

            GeometryReader { proxy in
                let compact = proxy.size.height < 640
                VStack(alignment: .leading, spacing: 0) {
                    closeButton
                        .padding(.leading, 18)
                        .padding(.top, 7)
                        .modifier(Stagger(phase: stage, inDelay: 0, outIndex: 0, reduceMotion: reduceMotion))

                    Text("今日を撮る前に")
                        .font(.system(size: 10.5, weight: .semibold)).tracking(0.06 * 10.5)
                        .foregroundStyle(Color(hex: "8E8E95"))
                        .padding(.leading, 28)
                        .padding(.top, compact ? 14 : 28)
                        .modifier(Stagger(phase: stage, inDelay: 80, outIndex: 1, reduceMotion: reduceMotion))
                    Text("今日は、どんな日?")
                        .font(.system(size: 30, weight: .black)).tracking(-0.04 * 30)
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .padding(.leading, 26)
                        .padding(.top, 5)
                        .modifier(Stagger(phase: stage, inDelay: 150, outIndex: 2, reduceMotion: reduceMotion))
                        .accessibilityAddTraits(.isHeader)
                    Text("撮る前に、えらぶ。\(TagRules.maxCount)つまで。")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color(hex: "9A9AA2"))
                        .padding(.leading, 28)
                        .padding(.top, 8)
                        .modifier(Stagger(phase: stage, inDelay: 220, outIndex: 3, reduceMotion: reduceMotion))

                    card
                        .padding(.horizontal, 18)
                        .padding(.top, 14)

                    Text("いま、よく選ばれている")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "8E8E95"))
                        .padding(.leading, 28)
                        .padding(.top, 24)
                        .modifier(Stagger(phase: stage, inDelay: 420, outIndex: 5, reduceMotion: reduceMotion))
                    words
                        .padding(.top, 8)
                        .modifier(Stagger(phase: stage, inDelay: 480, outIndex: 6, reduceMotion: reduceMotion, dx: 60, dy: 0))
                    Spacer(minLength: 0)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .clipped()
            }
            // キーボードが出ても、画面の組み立てを押しあげない
            .ignoresSafeArea(.keyboard, edges: .bottom)

            // キーボードの すぐ上、右に「追加」(書いたことばが あるときだけ はっきり)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: commitInput) {
                        Text("追加")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Color(hex: "111111"))
                            .padding(.horizontal, 20)
                            .frame(height: 38)
                            .background(Capsule().fill(.white))
                    }
                    .buttonStyle(SquishButtonStyle(pressedScale: 0.94))
                    .opacity(trimmedInput.isEmpty || isFull ? 0.55 : 1)
                    .accessibilityLabel("タグを追加")
                }
                .padding(.trailing, 18)
                .padding(.bottom, 10)
            }
            .opacity(inputFocused ? 1 : 0)
            .offset(y: inputFocused ? 0 : 12)
            .allowsHitTesting(inputFocused)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: inputFocused)

            // 飛んでいるタグのコピー(いちばん上)
            ForEach(flights) { flight in
                TagGlassChip(text: TagDictionary.display(flight.word), style: .white)
                    .modifier(ArcFlight(progress: flight.launched ? 1 : 0, from: flight.from, to: flight.to))
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            if showRefuse {
                Text(refuseText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "111111"))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(.white))
                    .padding(.bottom, 140)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showRefuse)
        .coordinateSpace(name: Self.space)
        .preferredColorScheme(.dark)
        .onAppear(perform: appear)
        .onDisappear { placeholderTask?.cancel() }
        .onChange(of: inputFocused) { _, focused in
            if focused {
                haptics.captureFeather()
                placeholderTask?.cancel()
                placeholder = ""
            } else if input.isEmpty {
                startPlaceholder()
            }
        }
        .onChange(of: tags.count) { _, _ in
            if isFull { placeholderTask?.cancel(); placeholder = "\(TagRules.maxCount)つ えらびました" }
            else if !inputFocused && input.isEmpty && placeholderTask == nil { startPlaceholder() }
        }
    }

    // MARK: 上

    private var closeButton: some View {
        Button(action: close) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(.white.opacity(0.1)))
                .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.92))
        .accessibilityLabel("とじる")
    }

    // MARK: カード

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return ZStack(alignment: .topLeading) {
            TagGlassCardBackground(sheen: sheen, reduceMotion: reduceMotion)

            if !tags.isEmpty || place != nil {
                TagChipRow(place: place, tags: tags, hidden: incoming, onTapTag: remove)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { rect in
                        chipsEnd = CGPoint(x: min(rect.maxX + 30, rect.minX + 260), y: rect.midY)
                    }
            }

            HStack(spacing: 6) {
                Text("#")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.4))
                TextField("", text: $input, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.28)))
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.02 * 32)
                    .foregroundStyle(.white)
                    .tint(.white)
                    .focused($inputFocused)
                    .submitLabel(.done)
                    .onSubmit(commitInput)
                    .disabled(isFull || leaving)
                    .onChange(of: input) { _, value in
                        if value.count > TagRules.maxLength + 1 { input = String(value.prefix(TagRules.maxLength + 1)) }
                        // 空白か改行で、タグになる
                        if let last = value.last, last == " " || last == "　" || last == "\n" { commitInput() }
                    }
                    .accessibilityLabel("じぶんの言葉で タグ")
            }
            .frame(height: 48)
            .padding(.leading, 22)
            .padding(.trailing, 18)
            .padding(.top, (!tags.isEmpty || place != nil) ? 52 : 36)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(tags.count) / \(TagRules.maxCount)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(0.06 * 11)
                        .foregroundStyle(Color(hex: "8E8E95"))
                        .contentTransition(.numericText())
                    Text("空白か改行で、タグになります")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(hex: "6E6E76"))
                }
                Spacer(minLength: 8)
                shootButton
            }
            .padding(.leading, 22)
            .padding(.trailing, 14)
            .padding(.bottom, 14)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 152)
        .clipShape(shape)
        .contentShape(shape)
        .onTapGesture { if !isFull && !leaving { inputFocused = true } }
        .modifier(ShakeEffect(animatableData: CGFloat(cardShake)))
        .animation(.linear(duration: 0.28), value: cardShake)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onCardFrame($0) }
        .opacity(hidesCard ? 0 : 1)
        .modifier(Stagger(phase: phase, inDelay: 300, outIndex: 4, reduceMotion: reduceMotion))
    }

    /// 右下:「つけずに撮る」(うすいガラス)→ タグを1つ以上えらぶと 白地・黒字の「撮る」(ばねで 少し大きく)
    private var shootButton: some View {
        let has = !tags.isEmpty
        return Button {
            guard canShoot else { return refuseShoot() }
            Haptics.play(.click)
            start(withTags: has || !trimmedInput.isEmpty)
        } label: {
            Text(has ? "撮る" : "つけずに撮る")
                .font(.system(size: 14, weight: .heavy)).tracking(0.02 * 14)
                .foregroundStyle(!canShoot ? Color(hex: "6E6E76") : (has ? Color(hex: "111111") : .white))
                .padding(.horizontal, has ? 30 : 20)
                .frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(!canShoot ? Color.white.opacity(0.06) : (has ? Color.white : Color.white.opacity(0.14))))
                .contentTransition(.opacity)
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.95))
        .animation(.spring(response: 0.32, dampingFraction: 0.55), value: has)
        .accessibilityLabel(!canShoot ? "今日は ここまで" : (has ? "撮る" : "タグを つけずに 撮る"))
    }

    // MARK: よく選ばれている(1列・左右が ふわっと消える)

    @ViewBuilder
    private var words: some View {
        if voiceOver {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10, alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(popular, id: \.self) { word in
                    Button { toggle(word, at: .zero) } label: {
                        TagGlassChip(text: TagDictionary.display(word), style: .glass, large: true).opacity(tags.contains(word) ? 0.3 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tags.contains(word) ? "\(word)、選択中" : word)
                }
            }
            .padding(.horizontal, 28)
        } else {
            MarqueeRow(
                words: popular,
                secondsPerLoop: reduceMotion ? MarqueeMath.reducedSeconds : MarqueeMath.rowSeconds[0],
                reversed: false,
                phase: rowPhase,
                selected: tags,
                shakeCounts: shakeCounts,
                coordinateSpaceName: Self.space,
                glass: true,
                onTap: { word, location in toggle(word, at: location) },
                onHold: { Haptics.play(.tick) }
            )
            .frame(height: 56)
            .mask(
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.08),
                    .init(color: .black, location: 0.92),
                    .init(color: .clear, location: 1),
                ], startPoint: .leading, endPoint: .trailing)
            )
        }
    }

    // MARK: 動きとルール

    private func appear() {
        if popular.isEmpty {
            // 昨日の世界で 多かったことば → たりない分は いつものことば(同じものは 1回だけ)
            var list: [String] = []
            for word in WorldWordsStore.words(now: Date()) + TagDictionary.all.shuffled() {
                let clean = TagRules.clean(word)
                if !clean.isEmpty, !list.contains(clean) { list.append(clean) }
                if list.count >= 14 { break }
            }
            popular = list
        }
        startPlaceholder()
        DispatchQueue.main.async { phase = .shown }
    }

    /// プレースホルダー:「雨の日」→ 例が 打たれては 消える
    private func startPlaceholder() {
        placeholderTask?.cancel()
        guard !isFull else { placeholder = "\(TagRules.maxCount)つ えらびました"; return }
        placeholder = Self.examples[0]
        guard !reduceMotion else { placeholderTask = nil; return }
        placeholderTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            var index = 1
            while !Task.isCancelled {
                let word = Self.examples[index % Self.examples.count]
                for n in 1...word.count {
                    placeholder = String(word.prefix(n))
                    try? await Task.sleep(for: .milliseconds(95))
                    if Task.isCancelled { return }
                }
                try? await Task.sleep(for: .seconds(1.4))
                for n in stride(from: word.count - 1, through: 0, by: -1) {
                    placeholder = String(word.prefix(n))
                    try? await Task.sleep(for: .milliseconds(40))
                    if Task.isCancelled { return }
                }
                try? await Task.sleep(for: .milliseconds(250))
                index += 1
            }
        }
    }

    /// 流れのタグをタップ:カードへ ひゅっと飛んで入る(sel → pop)/ 選び済みなら はずす
    private func toggle(_ word: String, at location: CGPoint) {
        guard !leaving else { return }
        if tags.contains(word) {
            Haptics.play(.warn)
            return
        }
        guard TagRules.canAdd(word, to: tags) else {
            if isFull { refuse(word: word) }
            return
        }
        Haptics.play(.detent)
        if reduceMotion || location == .zero || chipsEnd == .zero {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) { tags.append(word) }
            land()
            return
        }
        incoming.insert(word)
        tags.append(word)
        let flight = TapeFlightItem(word: word, from: location, to: chipsEnd)
        flights.append(flight)
        DispatchQueue.main.async {
            withAnimation(FlowMotion.io(0.42)) {
                if let i = flights.firstIndex(where: { $0.id == flight.id }) { flights[i].launched = true }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) { _ = incoming.remove(word) }
            land()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) {
            flights.removeAll { $0.id == flight.id }
        }
    }

    /// 入った:pop / 3つ そろった:success + 光が すっと なでる + キーボードを とじる
    private func land() {
        if tags.count >= TagRules.maxCount {
            Haptics.play(.success)
            sheen += 1
            inputFocused = false
        } else {
            Haptics.play(.pop)
        }
    }

    private func remove(_ word: String) {
        guard !leaving else { return }
        Haptics.play(.soft)
        incoming.remove(word)
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeIn(duration: 0.26)) {
            tags.removeAll { $0 == word }
        }
    }

    /// 4つ目:warn + カードが ゆれる +「タグは 3つまで」
    private func refuse(word: String?) {
        Haptics.play(.warn)
        showMessage("タグは \(TagRules.maxCount)つまで")
        if let word { shakeCounts[word, default: 0] += 1 }
        cardShake += 1
    }

    private func commitInput() {
        let tag = TagRules.clean(input.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !tag.isEmpty else {
            if !input.isEmpty { input = "" }
            return
        }
        if tags.contains(tag) {
            Haptics.play(.warn)
            cardShake += 1
            input = ""
            return
        }
        guard TagRules.canAdd(tag, to: tags) else {
            refuse(word: nil)
            return
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) {
            tags.append(tag)
            input = ""
        }
        land()
    }

    private func showMessage(_ text: String) {
        refuseText = text
        showRefuse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { if refuseText == text { showRefuse = false } }
    }

    /// のこりが 0 のとき:warn +「今日は、ここまで」+ ゆれる
    private func refuseShoot() {
        Haptics.play(.warn)
        cardShake += 1
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
        Haptics.play(.soft)
        inputFocused = false
        onClose()
    }
}

// MARK: - 白と黒の部品(タグ画面と、撮影画面へ ひろがる カードのコピーで使う)

/// 背景:#0B0B0D に、上だけ ごく うすく #202023
struct TagScreenBackground: View {
    var body: some View {
        ZStack {
            Color(hex: "0B0B0D")
            RadialGradient(colors: [Color(hex: "202023"), Color(hex: "0B0B0D").opacity(0)], center: .top, startRadius: 0, endRadius: 420)
                .scaleEffect(x: 1.8, y: 1, anchor: .top)
        }
    }
}

/// ガラスのカードの地(白 6% ・ 白 14% の細いふち ・ 細かい ノイズ)+ 3つ そろったときの 光の なで
struct TagGlassCardBackground: View {
    var sheen = 0
    var reduceMotion = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        ZStack {
            shape.fill(.white.opacity(0.06))
            TagNoise().opacity(0.07).clipShape(shape)
            shape.strokeBorder(.white.opacity(0.14), lineWidth: 1)
            if sheen > 0 && !reduceMotion {
                TagSheen().id(sheen).clipShape(shape)
            }
        }
        .background(.ultraThinMaterial.opacity(0.4), in: shape)
        .allowsHitTesting(false)
    }
}

private struct TagSheen: View {
    @State private var x: CGFloat = -1
    var body: some View {
        GeometryReader { proxy in
            LinearGradient(colors: [.clear, .white.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: proxy.size.width * 0.5)
                .rotationEffect(.degrees(18))
                .offset(x: x * proxy.size.width * 1.3)
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.7)) { x = 1 } }
    }
}

/// こまかい 白の つぶ(固定の たね)
private struct TagNoise: View {
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: 9)
            var path = Path()
            let count = Int(size.width * size.height / 30)
            for _ in 0..<count {
                let x = Double(rng.next() % 10_000) / 10_000 * size.width
                let y = Double(rng.next() % 10_000) / 10_000 * size.height
                path.addRect(CGRect(x: x, y: y, width: 1, height: 1))
            }
            ctx.fill(path, with: .color(.white))
        }
    }
}

/// タグの まる(白=黒い字 / 黒=白い字・白いふち / ガラス=流れる ことば / 場所=うすい白)
struct TagGlassChip: View {
    enum Style { case white, black, glass, place }
    let text: String
    let style: Style
    var large = false

    var body: some View {
        HStack(spacing: 4) {
            if style == .place {
                Image(systemName: "mappin").font(.system(size: 10, weight: .bold))
            }
            Text(text).lineLimit(1)
        }
        .font(.system(size: large ? 16 : (style == .place ? 12 : 12.5), weight: large ? .bold : .heavy))
        .foregroundStyle(style == .white ? Color(hex: "111111") : .white)
        .padding(.horizontal, large ? 20 : (style == .place ? 9 : 10))
        .frame(height: large ? 44 : 30)
        .background {
            switch style {
            case .white: Capsule().fill(Color(hex: "F4F4F6"))
            case .black: Capsule().fill(Color(hex: "141416")).overlay(Capsule().strokeBorder(.white.opacity(0.55), lineWidth: 1.3))
            case .glass: Capsule().fill(.white.opacity(0.1)).overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1))
            case .place: Capsule().fill(.white.opacity(0.12))
            }
        }
        .fixedSize()
    }
}

/// カードの上の 1行:場所(自動)+ えらんだタグ(白と黒を 交互)
struct TagChipRow: View {
    let place: String?
    let tags: [String]
    var hidden: Set<String> = []
    var onTapTag: ((String) -> Void)?

    var body: some View {
        HStack(spacing: 5) {
            if let place {
                TagGlassChip(text: place, style: .place)
                    .accessibilityLabel("場所 \(place)")
            }
            ForEach(Array(tags.enumerated()), id: \.element) { index, tag in
                TagGlassChip(text: TagDictionary.display(tag), style: index % 2 == 0 ? .white : .black)
                    .opacity(hidden.contains(tag) ? 0 : 1)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .onTapGesture { onTapTag?(tag) }
                    .accessibilityLabel("\(tag)。タップで はずす")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .frame(height: 30)
    }
}

/// 撮影画面へ ひろがる カードのコピー(中身は 見た目だけ)
struct TagCardFace: View {
    let place: String?
    let tags: [String]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: "0B0B0D")
            TagGlassCardBackground()
            TagChipRow(place: place, tags: tags)
                .padding(.horizontal, 18)
                .padding(.top, 14)
        }
    }
}
