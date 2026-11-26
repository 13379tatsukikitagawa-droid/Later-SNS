import SwiftUI

// v134 Phase 3:タグ画面(撮る前)。見本 screens/30。白と黒だけ。
// 開いたら キーボードが 出ている。左上 ×、右上に フィルムの のこり。小さく 日付、大きく 今日の お題(DailyQuestion)。
// えらんだ タグは 白い チップ(× で はずす)。タグは 3つまで(4つ目は warning + 横に ゆれる)。
// 候補は 2列で 横に 流れ続ける。その下に「曲をつける」「場所」。白い 横長の「撮る」。
// ルール(TagRules / TagWords / TagDraft / MusicDraft)は 今までの まま。カードが ひろがる 演出は 使わない(撮影へは フェード)。

struct TagScreenV134: View {
    let left: Int
    @Binding var tags: [String]
    let place: String?
    var onClose: () -> Void = {}
    /// 「撮る」(true:タグあり / false:タグなし)
    var onStart: (_ withTags: Bool) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var input = ""
    @FocusState private var focused: Bool
    @State private var popular: [String] = []
    @State private var popular2: [String] = []
    @State private var rowPhase = Double.random(in: 0..<1)
    @State private var rowPhase2 = Double.random(in: 0..<1)
    @State private var shakeCounts: [String: Int] = [:]
    @State private var fieldShake = 0
    @State private var message: String?
    @State private var music: MusicPick? = MusicDraft.load()
    @State private var showsMusic = false
    @State private var closing = false
    private static let space = "tagScreenV134"

    private var trimmed: String { TagRules.clean(input) }
    private var isFull: Bool { tags.count >= TagRules.maxCount }
    private var canShoot: Bool { left > 0 }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                topRow.padding(.horizontal, 16).padding(.top, 8)
                Text(HomeV134Rules.dayLabel(Date())).font(LTFont.display(19)).tracking(0.5).foregroundStyle(LTColor.ink3)
                    .padding(.horizontal, 22).padding(.top, 26)
                Text(verbatim: DailyQuestion.text())
                    .font(LTFont.ui(32, weight: .heavy)).tracking(-0.8).foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.75).fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 22).padding(.top, 6).accessibilityAddTraits(.isHeader)
                field.padding(.horizontal, 22).padding(.top, 34)
                rows.containerRelativeFrame(.horizontal).clipped().padding(.top, 20)
                extras.padding(.horizontal, 22).padding(.top, 20)
                Spacer(minLength: 0)
            }
            .coordinateSpace(name: Self.space)
            if let message {
                Text(message).font(LTFont.ui(13, weight: .heavy)).foregroundStyle(.white).padding(.horizontal, 16).frame(height: 38)
                    .lgGlass(radius: 19).padding(.top, 70).transition(.opacity)
            }
        }
        .background(LTColor.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { shootButton.padding(.horizontal, 14).padding(.bottom, 8).padding(.top, 6) }
        .sheet(isPresented: $showsMusic) {
            MusicSheet(current: music) { pick in MusicDraft.save(pick); music = pick }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if popular.isEmpty {
                let r = TagWords.rows(world: WorldWordsStore.words(now: Date()))
                popular = r.first; popular2 = r.second
            }
            MusicPlayback.shared.setVolume(0.9)
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "debugNoFocus") { return }
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { focused = true }
        }
    }

    // MARK: 上

    private var topRow: some View {
        HStack {
            Button { close() } label: {
                Image(systemName: "xmark").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(LTColor.surface3, in: Circle())
            }.buttonStyle(HVPress(scale: 0.92)).accessibilityLabel("とじる")
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    let used = i < FilmRoll.shotsPerDay - left
                    RoundedRectangle(cornerRadius: 4, style: .continuous).fill(used ? Color.white : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Color.white.opacity(used ? 0 : 0.35), lineWidth: 1.2))
                        .frame(width: 14, height: 20)
                }
                Text("のこり\(max(0, left))枚").font(LTFont.ui(13, weight: .heavy)).foregroundStyle(LTColor.ink2).padding(.leading, 4)
            }.accessibilityElement(children: .ignore).accessibilityLabel("のこり\(max(0, left))枚")
        }
    }

    // MARK: 入力

    private var field: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { t in
                        Button { remove(t) } label: {
                            HStack(spacing: 6) {
                                Text("#").foregroundStyle(LTColor.ink3); Text(t).foregroundStyle(LTColor.limeInk)
                                Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(LTColor.ink3)
                            }
                            .font(LTFont.ui(15, weight: .heavy)).padding(.horizontal, 12).frame(height: 44).background(Color.white, in: Capsule())
                        }.buttonStyle(.plain).accessibilityLabel("\(t)をはずす")
                    }
                    TextField("", text: $input, prompt: Text(tags.isEmpty ? "ことばを入れる" : "").foregroundColor(Color(hex6: 0x66666E)))
                        .font(LTFont.ui(18, weight: .heavy)).foregroundStyle(.white).tint(.white)
                        .focused($focused).submitLabel(.done)
                        .frame(minWidth: 70, minHeight: 44)
                        .onSubmit { commitInput() }
                        .onChange(of: input) { _, v in if v.contains("\n") { input = v.replacingOccurrences(of: "\n", with: ""); commitInput() } }
                        .accessibilityLabel("タグを入れる")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(Color.white.opacity(0.18)).frame(height: 1).padding(.top, 8)
        }
    }

    private var rows: some View {
        VStack(spacing: 6) {
            MarqueeRow(words: popular, secondsPerLoop: 44, reversed: false, phase: rowPhase, selected: tags, shakeCounts: shakeCounts,
                       coordinateSpaceName: Self.space, glass: true, onTap: { w, _ in add(w) }, onHold: { Haptics.play(.tick) }, rowHeight: 48)
            MarqueeRow(words: popular2, secondsPerLoop: 56, reversed: true, phase: rowPhase2, selected: tags, shakeCounts: shakeCounts,
                       coordinateSpaceName: Self.space, glass: true, onTap: { w, _ in add(w) }, onHold: { Haptics.play(.tick) }, rowHeight: 48)
        }
    }

    private var extras: some View {
        HStack(spacing: 10) {
            Button { LTHaptics.play(.tap); focused = false; showsMusic = true } label: {
                HStack(spacing: 7) { Image(systemName: "music.note"); Text(music.map { $0.shortTitle } ?? "曲をつける").lineLimit(1) }
                    .font(LTFont.ui(15, weight: .heavy)).foregroundStyle(music == nil ? LTColor.ink2 : .white)
                    .padding(.horizontal, 16).frame(height: 44).overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1.2))
            }.buttonStyle(HVPress(scale: 0.96))
            if let place, !place.isEmpty {
                HStack(spacing: 7) { Image(systemName: "mappin.and.ellipse"); Text("場所 \(place)").lineLimit(1) }
                    .font(LTFont.ui(15, weight: .heavy)).foregroundStyle(LTColor.ink2)
                    .padding(.horizontal, 16).frame(height: 44).overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1.2))
                    .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
        }
    }

    private var shootButton: some View {
        Button { start() } label: {
            Text("撮る").font(LTFont.ui(18, weight: .heavy)).foregroundStyle(LTColor.limeInk)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(canShoot ? Color.white : Color.white.opacity(0.3), in: RoundedRectangle(cornerRadius: LTRadius.button, style: .continuous))
        }.buttonStyle(HVPress(scale: 0.98)).accessibilityLabel(canShoot ? "撮る" : "今日は、ここまで")
    }

    // MARK: 動き

    private func add(_ word: String) {
        if tags.contains(word) { LTHaptics.play(.warning); return }
        guard TagRules.canAdd(word, to: tags) else { if isFull { refuse(word) }; return }
        LTHaptics.play(.select)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) { tags.append(word) }
        if tags.count >= TagRules.maxCount { focused = false }
    }

    private func remove(_ word: String) {
        LTHaptics.play(.tap)
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeIn(duration: 0.22)) { tags.removeAll { $0 == word } }
    }

    private func refuse(_ word: String?) {
        LTHaptics.play(.warning)
        flash("タグは \(TagRules.maxCount)つまで")
        if let word { shakeCounts[word, default: 0] += 1 }
        fieldShake += 1
    }

    private func commitInput() {
        let tag = trimmed
        guard !tag.isEmpty else { if !input.isEmpty { input = "" }; return }
        if tags.contains(tag) { LTHaptics.play(.warning); fieldShake += 1; input = ""; return }
        guard TagRules.canAdd(tag, to: tags) else { refuse(nil); return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) { tags.append(tag); input = "" }
        LTHaptics.play(.select)
    }

    private func flash(_ t: String) {
        message = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { if message == t { message = nil } }
    }

    private func start() {
        guard canShoot else { LTHaptics.play(.warning); fieldShake += 1; flash("今日は、ここまで"); return }
        focused = false
        if TagRules.canAdd(trimmed, to: tags) { tags.append(trimmed) }
        input = ""
        LTHaptics.play(.tap)
        onStart(!tags.isEmpty)
    }

    private func close() {
        guard !closing else { return }
        closing = true
        LTHaptics.play(.tap)
        guard focused else { onClose(); return }
        focused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { onClose() }
    }
}
