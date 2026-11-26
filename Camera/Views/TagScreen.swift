// TagScreen.swift
// 撮影の前のタグ画面(v22 H)。白と黒(と その間の灰)だけ。カラフルな色は使わない。
// - ガラスのカード:# 入力 ・ 0 / 3 ・ つけずに撮る / 撮る。えらんだタグは カードの上に 1行(白と黒を 交互)
// - いま人気:2列で 逆向きに流れる(MarqueeRow・ガラスの まる・L-2)。ことばは TagWords(L-3)
// - ひらくと キーボードが 出る(L-1)。「追加」は「いま人気」の 行の 右端
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
        (scenes.contains(word) || TagWords.all.contains(word)) ? "#" + word : word
    }
}

// MARK: - L-3:いま人気の ことば(2列。あとで サーバーから 配れるよう、ここだけに まとめる)

/// いまの言葉と、ギャルっぽい言葉が中心。人を 傷つける ことば(悪口・見た目いじり・差別)は 入れない
/// (「きもい」ではなく「きもかわ」のように、やさしい形にする)。値には「#」を入れない(表示で つける)
enum TagWords {
    static let row1 = [
        "エモい", "空", "ぴえん", "優勝", "散歩", "雨の日", "きもかわ", "夕焼け", "やばい",
        "放課後", "ごはん", "ねむい", "部活", "帰り道", "コーヒー", "テスト前", "いい匂い",
    ]
    static let row2 = [
        "チル", "尊い", "ガチ", "推ししか勝たん", "しんどい", "映え", "あざとい", "草", "まじむり",
        "ちょうどいい", "神", "わかる", "ウケる", "沼", "いとおかし", "ハピ", "ばえ",
    ]
    static var all: Set<String> { Set(row1 + row2) }

    /// 2列を つくる。毎回 少し ならびを かえる(いつも 同じ ことばが 先頭に ならない)。
    /// 昨日の世界で 多かったことば(world)は、1列目の 前のほうに まぜる(同じものは 1回だけ・両方の列で 重ねない)
    static func rows(world: [String] = [], shuffle: ([String]) -> [String] = { $0.shuffled() }) -> (first: [String], second: [String]) {
        var seen = Set<String>()
        func unique(_ words: [String]) -> [String] {
            words.compactMap { word in
                let clean = TagRules.clean(word)
                guard !clean.isEmpty, !seen.contains(clean) else { return nil }
                seen.insert(clean)
                return clean
            }
        }
        let worldWords = unique(Array(world.prefix(5)))
        let first = shuffle(worldWords + unique(row1))
        let second = shuffle(unique(row2))
        return (first, second)
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
/// ✕ → 今日は、どんな日? → ガラスのカード(# 入力・0 / 3・つけずに撮る / 撮る)
/// → いま人気(右に「追加」)→ 2列で 流れる ことば。
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
    /// v22 A:出かた。撮影画面から もどるときは .instant(時間差なしで すぐ 全部・キーボードは そのあと)
    var entrance: Entrance = .stagger

    enum Entrance: Equatable {
        /// ひらく とき:部品が 順に 出る(最大 約1.1秒)
        case stagger
        /// もどる とき:最初の コマから 全部 見える
        case instant
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    @State private var phase: TagScreenPhase = .hidden
    @State private var input = ""
    @FocusState private var inputFocused: Bool
    @State private var popular: [String] = []
    /// L-2:2列目(1列目と 逆向き・少し ゆっくり)
    @State private var popular2: [String] = []
    @State private var rowPhase = Double.random(in: 0..<1)
    @State private var rowPhase2 = Double.random(in: 0..<1)
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
    /// とじている最中(キーボードを とじてから 画面を とじる・2回目は 無視)
    @State private var closing = false
    /// L-4:今日の 1曲(その日の 下書き。撮ると 写真に つく)
    @State private var music: MusicPick? = MusicDraft.load()
    /// v98:「さっきと 同じ」(2枚目 以降)
    @State private var last: LastShotCaption.Entry? = LastShotCaption.load()
    @State private var showsMusic = false
    @State private var musicBounce = 0
    private let musicPlayback = MusicPlayback.shared

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
                    // 左に ×、右に ♪(同じ 高さ・同じ 大きさ)
                    HStack(alignment: .top) {
                        closeButton
                        Spacer(minLength: 12)
                        TagMusicButton(pick: music, bounce: musicBounce, action: {
                            Haptics.play(.pop)
                            inputFocused = false
                            showsMusic = true
                        }, onToggle: {
                            let g = MusicPlayback.shared
                            if g.isPlaying { Haptics.play(.soft); g.stop() } else if let m = music, let u = m.previewURL.flatMap(URL.init(string:)) { Haptics.play(.tick); g.start(key: m.songID ?? m.title + m.artist, url: u) }
                        }, playing: musicPlayback.isPlaying)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 7)
                    .modifier(Stagger(phase: stage, inDelay: 0, outIndex: 0, reduceMotion: reduceMotion))

                    // L:文字を へらす。見出しだけ(×の すぐ下)
                    Text(verbatim: DailyQuestion.text())
                        .font(.system(size: 28, weight: .black)).tracking(-0.98).lineSpacing(28 * 0.22)   // v89:太い ゴシック 900 ・ 毎日 かわる お題
                        .foregroundStyle(.white)
                        .lineLimit(2).minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 26).padding(.trailing, 70)
                        .padding(.top, compact ? 14 : 22)
                        .modifier(Stagger(phase: stage, inDelay: 120, outIndex: 1, reduceMotion: reduceMotion))
                        .accessibilityAddTraits(.isHeader)

                    card
                        // はじめての 合図(tag):はじめて 開いたとき。ふきだしは カードの 下
                        .firstHint(.tag, eligible: phase == .shown && !leaving && !closing && !showsMusic, edge: .bottom, shape: .rounded(30), onDark: true, gap: 10)
                        .padding(.horizontal, 18)
                        .padding(.top, compact ? 16 : 26)

                    // 「いま人気」+ 右に「追加」(キーボードが 出ている ときだけ。2列目と 重ならない)
                    HStack(alignment: .center) {
                        Text("いま人気")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: "8E8E95"))
                            .modifier(Stagger(phase: stage, inDelay: 420, outIndex: 5, reduceMotion: reduceMotion))
                        Spacer(minLength: 8)
                        if let last, tags.isEmpty, music == nil, trimmedInput.isEmpty { sameAsBeforeCapsule(last) }
                        addButton
                    }
                    .frame(height: 30)
                    .padding(.leading, 28)
                    .padding(.trailing, 18)
                    .padding(.top, compact ? 12 : 20)
                    words
                        .padding(.top, 0)
                        .modifier(Stagger(phase: stage, inDelay: 480, outIndex: 6, reduceMotion: reduceMotion, dx: 60, dy: 0))
                    Spacer(minLength: 0)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .clipped()
            }
            // キーボードが出ても、画面の組み立てを押しあげない
            .ignoresSafeArea(.keyboard, edges: .bottom)

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
        .sheet(isPresented: $showsMusic) {
            MusicSheet(current: music) { pick in
                MusicDraft.save(pick)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { music = pick }
                if pick != nil { musicBounce += 1 }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            MusicPlayback.shared.setVolume(0.9)
            if LastShotCaption.consumeFresh() { resetForNewShot() }
            appear()
        }
        .onReceive(NotificationCenter.default.publisher(for: LastShotCaption.didShoot)) { _ in
            _ = LastShotCaption.consumeFresh()
            resetForNewShot()
        }
        .onDisappear { placeholderTask?.cancel(); MusicPlayback.shared.setVolume(0.45) }   // v89:撮影画面へ 行っても 小さく 流れる
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
            BackTiming.mark("⑥キーボードが 出た", on: .chipToTags)
        }
        .onChange(of: inputFocused) { _, focused in
            if focused {
                // L-1:キーボードが 出た しゅんかんに、ごく軽い tick を 1回
                Haptics.play(.tick)
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
                        if !value.isEmpty { HintCenter.shared.touched(.tag) }
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
                Text("\(tags.count) / \(TagRules.maxCount)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(0.06 * 11)
                    .foregroundStyle(Color(hex: "8E8E95"))
                    .contentTransition(.numericText())
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
                ForEach(popular + popular2, id: \.self) { word in
                    Button { toggle(word, at: .zero) } label: {
                        TagGlassChip(text: TagDictionary.display(word), style: .glass, large: true).opacity(tags.contains(word) ? 0.3 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tags.contains(word) ? "\(word)、選択中" : word)
                }
            }
            .padding(.horizontal, 28)
        } else {
            // L-2:2列。2列目は 逆向きで、1列目の 約1.2倍の 時間(少し ゆっくり)。1列 48pt・あいだ 2pt
            VStack(spacing: Self.rowGap) {
                marquee(popular, seconds: MarqueeMath.rowSeconds[0], reversed: false, phase: rowPhase)
                marquee(popular2, seconds: MarqueeMath.rowSeconds[0] * 1.2, reversed: true, phase: rowPhase2)
            }
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

    static let rowHeight: CGFloat = 48
    static let rowGap: CGFloat = 2

    private func marquee(_ list: [String], seconds: Double, reversed: Bool, phase: Double) -> some View {
        MarqueeRow(
            words: list,
            secondsPerLoop: reduceMotion ? MarqueeMath.reducedSeconds : seconds,
            reversed: reversed,
            phase: phase,
            selected: tags,
            shakeCounts: shakeCounts,
            coordinateSpaceName: Self.space,
            glass: true,
            onTap: { word, location in toggle(word, at: location) },
            onHold: { Haptics.play(.tick) },
            rowHeight: Self.rowHeight
        )
        .frame(height: Self.rowHeight)
    }

    /// 「追加」:「いま人気」の 行の 右端。キーボードが 出ているときだけ。書いた ことばが あるときだけ はっきり
    private var addButton: some View {
        Button(action: commitInput) {
            Text("追加")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Color(hex: "111111"))
                .padding(.horizontal, 16)
                .frame(height: 30)
                .background(Capsule().fill(.white))
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.94))
        .opacity(inputFocused ? (trimmedInput.isEmpty || isFull ? 0.55 : 1) : 0)
        .offset(y: inputFocused ? 0 : 8)
        .allowsHitTesting(inputFocused)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: inputFocused)
        .accessibilityLabel("タグを追加")
        .accessibilityHidden(!inputFocused)
    }

    // MARK: v98 さっきと 同じ

    /// 1枚 撮れた:タグ ・ 音楽 ・ 入力欄を 空に して、再生を 止める(キャプション画面は ひらく たびに 新しい 状態)
    private func resetForNewShot() {
        tags = []
        music = nil
        input = ""
        MusicPlayback.shared.stop()
        last = LastShotCaption.load()
    }

    /// 「いま人気」の 右:ライムの 小さな カプセル。押すと 1枚目の タグ ・ 音楽が 入って、カプセルは 消える
    private func sameAsBeforeCapsule(_ e: LastShotCaption.Entry) -> some View {
        let tagText = e.tags.map { "#" + TagDictionary.display($0) }.joined(separator: " ")
        let text = "↺ さっきと 同じ " + [tagText, e.music.map { "♪ " + $0.shortTitle }].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ・ ")
        return Button {
            Haptics.play(.pop)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                tags = Array(e.tags.prefix(TagRules.maxCount))
                if let m = e.music { MusicDraft.save(m); music = m; musicBounce += 1 }
                last = nil
            }
        } label: {
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: "0B0C0D"))
                .lineLimit(1).minimumScaleFactor(0.75)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Capsule().fill(LattagPalette.lime))
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.94))
        .frame(maxWidth: 250)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .accessibilityLabel("さっきと 同じ タグと 音楽を 入れる")
    }

    // MARK: 動きとルール

    private func appear() {
        if popular.isEmpty {
            // L-3:いま人気の ことば(2列)。昨日の世界で 多かったことばは 1列目に まぜる。数は 出さない
            let rows = TagWords.rows(world: WorldWordsStore.words(now: Date()))
            popular = rows.first
            popular2 = rows.second
        }
        startPlaceholder()
        BackTiming.mark("④タグ画面の onAppear", on: .chipToTags)
        NextFrame.after { BackTiming.mark("⑤タグ画面の 最初の コマ", on: .chipToTags) }
        let focusDelay: Double
        switch entrance {
        case .instant:
            // 時間差の 登場を しない:最初の コマから 全部 見える(暗黙の アニメーションも 切る)
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { phase = .shown }
            // キーボードは、切りかえ(クロスフェード)が おわってから
            focusDelay = CaptureFlow.backFade + 0.05
        case .stagger:
            DispatchQueue.main.async { phase = .shown }
            // いちばん おそい 部品(ことばの 2列):0.48秒 待って 0.6秒
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.31 : 1.08)) {
                BackTiming.mark("⑦動きが おわる(全部 見える)", on: .chipToTags)
            }
            // L-1:ひらく動き(フェードイン)が おわってから、入力欄に フォーカス(キーボードを 出す)。動きの途中だと カクつく
            focusDelay = reduceMotion ? 0.3 : 0.62
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + focusDelay) {
            guard phase == .shown, !closing, !leaving, !isFull, !voiceOver else { return }
            BackTiming.mark("⑥キーボード(たのんだ)", on: .chipToTags)
            inputFocused = true
        }
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

    /// ✕:キーボードを 先に とじてから、画面を とじる(連打は 1回だけ)
    private func close() {
        guard !closing else { return }
        closing = true
        Haptics.play(.soft)
        guard inputFocused else { onClose(); return }
        inputFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { onClose() }
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
    /// 高さを 決めるとき(流れる列が 低いとき)。nil なら いつもの高さ
    var height: CGFloat? = nil

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
        .frame(height: height ?? (large ? 44 : 30))
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
