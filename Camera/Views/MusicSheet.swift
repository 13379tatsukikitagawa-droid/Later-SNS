// MusicSheet.swift
// v22 L-4:タグ画面の いちばん上・右の「♪」ボタンと、下から 出る「今日の 1曲を つける」シート。
// 見本:later_v22.html の タグ画面(#msc・#shm)。
// - ボタン:46pt の ガラスの まる + うすい 点線の 輪(14秒で 1周)。曲を つけると 幅 206 に のびて、
//   左に まわる レコード(6秒で 1周)・曲名と アーティストの 2行・右に 白い イコライザー(3本・濃さを かえる。橙は 使わない)
// - シート:Apple Music(MusicKit で 検索。入っていない人は リンクを はる)。Spotify は 使わない
// - 「視差を減らす」:点線の 輪・レコード・イコライザーを 止める

import AVFoundation
import SwiftUI
import UIKit

// MARK: - ♪ ボタン

struct TagMusicButton: View {
    let pick: MusicPick?
    /// 「この曲にする」で はずむ(0.9 → 1.06 → 1)
    var bounce: Int = 0
    let action: () -> Void
    /// v89:曲が ある とき 1回 タップ = 止める / 流す(長押し = えらびなおす)
    var onToggle: (() -> Void)? = nil
    var playing = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let size: CGFloat = 46
    static let expandedWidth: CGFloat = 206

    var body: some View {
        if pick != nil, let onToggle {
            chip.onTapGesture { onToggle() }.onLongPressGesture(minimumDuration: 0.5) { Haptics.play(.pop); action() }
                .accessibilityAddTraits(.isButton)
        } else {
            Button(action: action) { chip }.buttonStyle(SquishButtonStyle(pressedScale: 0.93))
        }
    }

    private var chip: some View {
        Group {
            ZStack(alignment: .leading) {
                Capsule().fill(Color(red: 40 / 255, green: 40 / 255, blue: 44 / 255).opacity(0.72))
                    .background(.ultraThinMaterial.opacity(0.4), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
                if let pick {
                    HStack(spacing: 9) {
                        MusicDisc(artworkURL: pick.artworkURL, seed: pick.title, spinning: !reduceMotion && (onToggle == nil || playing))
                            .frame(width: 34, height: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(pick.title)
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(.white)
                            Text(pick.artist)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        MusicEqualizer(animating: !reduceMotion && (onToggle == nil || playing), lime: onToggle != nil)
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 14)
                    .transition(.opacity)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: Self.size, height: Self.size)
                        .transition(.opacity)
                    DashedRing(spinning: !reduceMotion)
                        .frame(width: Self.size + 2, height: Self.size + 2)
                        .offset(x: -1)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: pick == nil ? Self.size : Self.expandedWidth, height: Self.size)
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .keyframeAnimator(initialValue: CGFloat(1), trigger: bounce) { view, scale in
            view.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(0.9, duration: 0.1)
                SpringKeyframe(1.06, duration: 0.18, spring: .snappy)
                SpringKeyframe(1, duration: 0.26, spring: .bouncy)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.72), value: pick)
        .accessibilityLabel(pick.map { "音楽:\($0.title)、\($0.artist)。かえる" } ?? "音楽を つける")
    }
}

/// うすい 点線の 輪(14秒で 1周)
private struct DashedRing: View {
    let spinning: Bool

    var body: some View {
        TimelineView(.animation(paused: !spinning)) { context in
            let angle = spinning ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 14) / 14 * 360 : 0
            Circle()
                .strokeBorder(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3.5]))
                .rotationEffect(.degrees(angle))
        }
    }
}

/// まわる レコード(ジャケット。なければ 曲名から 決まる 色)。6秒で 1周
struct MusicDisc: View {
    let artworkURL: String?
    let seed: String
    let spinning: Bool

    var body: some View {
        TimelineView(.animation(paused: !spinning)) { context in
            let angle = spinning ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6 * 360 : 0
            ZStack {
                AsyncImage(url: artworkURL.flatMap(URL.init(string:))) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        // ジャケットが ない・まだ:白と灰の グラデ(色は 使わない)
                        AngularGradient(colors: [.white.opacity(0.85), .gray, .white.opacity(0.5), .gray.opacity(0.7), .white.opacity(0.85)],
                                        center: .center, angle: .degrees(Double(abs(seed.hashValue % 360))))
                    }
                }
                Circle().fill(Color(hex: "18181B")).frame(width: 9, height: 9)
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1.5))
            }
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 2))
            .rotationEffect(.degrees(angle))
        }
    }
}

/// 白い イコライザー(3本・濃さを かえる)。900ms で 上下
struct MusicEqualizer: View {
    let animating: Bool
    var lime = false
    private static let opacities: [Double] = [1, 0.7, 0.45]

    var body: some View {
        TimelineView(.animation(paused: !animating)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    let phase = animating ? (sin((t / 0.9 + Double(i) * 0.33) * 2 * .pi) + 1) / 2 : 0.5
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(lime ? HV.lime.opacity(Self.opacities[i] + 0.2) : .white.opacity(Self.opacities[i]))
                        .frame(width: 3, height: 4 + 10 * phase)
                }
            }
            .frame(height: 14, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - シート「今日の 1曲を つける」(v89 D:黒 ・ おすすめ / 最近 / ライブラリ ・ 行を おすと 流れる)

struct MusicSheet: View {
    /// いま つけている 曲
    let current: MusicPick?
    /// 「この曲にする」(nil = はずす)
    let onDone: (MusicPick?) -> Void

    @Environment(\.dismiss) private var dismiss
    private let playback = MusicPlayback.shared
    @State private var access: AppleMusicCatalog.Access = AppleMusicCatalog.access
    @State private var tab = 0
    @State private var term = ""
    @State private var results: [AppleMusicCatalog.Found] = []
    @State private var libraryHits: [AppleMusicCatalog.Found] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var recs: [AppleMusicCatalog.Found] = []
    @State private var charts: [AppleMusicCatalog.Found] = []
    @State private var recent: [AppleMusicCatalog.Found] = []
    @State private var library: [AppleMusicCatalog.Found] = []
    @State private var linkText = ""
    @State private var linkPick: MusicPick?
    @State private var linkLoading = false
    @State private var selected: MusicPick?
    @Namespace private var tabNS

    private let bg = Color(hex: "0F1011"), grey = Color.white.opacity(0.5)
    private let tabs = ["おすすめ", "最近", "ライブラリ"]

    var body: some View {
        ZStack(alignment: .bottom) {
            bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("今日の 1曲").font(LF.inter(900, 22)).foregroundStyle(.white)
                    Spacer()
                    Text("MUSIC").font(LF.mono(10)).tracking(1.5).foregroundStyle(grey)
                }.padding(.top, 26).padding(.horizontal, 20)
                content
            }
            if access == .ready { bottomBar }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large]).presentationCornerRadius(34).presentationDragIndicator(.visible).presentationBackground(bg)
        .onAppear { selected = current }
        .task { await loadAll() }
        .onDisappear { searchTask?.cancel() }   // 曲は とじても 流れつづける
    }

    @ViewBuilder private var content: some View {
        switch access {
        case .ready: readyBody
        case .notDetermined: connectBody
        case .denied: fallback("Apple Music の 許可が ありません。設定アプリの「Lattag」で「メディアと Apple Music」を オンにして ください。")
        case .unavailable: fallback("この 端末では、Apple Music を 使えません。")
        }
    }

    // つなぐ 前(C13)
    private var connectBody: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 20)
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill([Color(hex: "C8F25A"), Color(hex: "EE5E9C"), Color(hex: "9ED8FF")][i]).frame(width: 96, height: 96)
                        .overlay(Image(systemName: "music.note").font(.system(size: 34, weight: .bold)).foregroundStyle(Color(hex: "0B0C0D")))
                        .rotationEffect(.degrees([-12, 0, 12][i])).offset(x: CGFloat(i - 1) * 62, y: i == 1 ? -8 : 0)
                }
            }.frame(height: 130)
            Text("今日の 写真に、1曲").font(LF.inter(900, 24)).foregroundStyle(.white)
            Text("友だちが 写真を ひらくと、この曲が 流れます").font(LF.inter(600, 14)).foregroundStyle(grey).multilineTextAlignment(.center)
            Button {
                Task {
                    let r = await AppleMusicCatalog.requestAccess()
                    Haptics.play(r == .ready ? .success : .warn)
                    withAnimation { access = r }
                    if r == .ready { await loadAll() }
                }
            } label: { Text("Apple Music と つなぐ").font(LF.inter(800, 16)).foregroundStyle(Color(hex: "0B0C0D")).frame(maxWidth: .infinity).frame(height: 56).background(.white, in: Capsule()) }
                .buttonStyle(HVPress(scale: 0.97)).padding(.horizontal, 20)
            Spacer()
        }.frame(maxWidth: .infinity)
    }

    private func fallback(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text).font(LF.inter(600, 13)).foregroundStyle(grey).lineSpacing(4)
            linkField
            if let linkPick { row(linkPick, previewURL: linkPick.previewURL.flatMap(URL.init(string:))) }
        }.padding(20)
    }

    // つないだ あと(C14)
    private var readyBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            searchField.padding(.horizontal, 20).padding(.top, 14)
            if term.isEmpty { tabBar.padding(.horizontal, 20) }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !term.isEmpty {
                        if searching && results.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(.top, 30) }
                        else if results.isEmpty && libraryHits.isEmpty { Text("見つかりませんでした").font(LF.inter(600, 13)).foregroundStyle(grey).padding(20) }
                        list(results)
                        if !libraryHits.isEmpty { head("ライブラリ"); list(libraryHits) }
                    } else if tab == 0 {
                        if !recs.isEmpty { head("あなたへの おすすめ"); recsRow }
                        if !charts.isEmpty { head("いま 人気"); list(charts) }
                        if recs.isEmpty && charts.isEmpty { empty }
                    } else if tab == 1 {
                        head("最近 聴いた 曲"); if recent.isEmpty { empty } else { list(recent) }
                    } else {
                        head("ライブラリ ・ 曲"); if library.isEmpty { empty } else { list(library) }
                    }
                    Color.clear.frame(height: 130)
                }
            }.scrollDismissesKeyboard(.immediately)
        }
    }

    private var empty: some View { Text("まだ ありません").font(LF.inter(600, 13)).foregroundStyle(grey).padding(20) }
    private func head(_ t: String) -> some View { Text(t).font(LF.inter(800, 15)).foregroundStyle(.white).padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 8) }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .bold)).foregroundStyle(grey)
            TextField("曲名・アーティスト", text: $term).font(LF.inter(700, 15)).foregroundStyle(.white).submitLabel(.search).autocorrectionDisabled()
                .onChange(of: term) { _, v in scheduleSearch(v) }.onSubmit { scheduleSearch(term, now: true) }
            if searching { ProgressView().scaleEffect(0.8) }
        }.padding(.horizontal, 16).frame(height: 46).background(.white.opacity(0.08), in: Capsule())
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { i, t in
                Button { Haptics.play(.sel); withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tab = i } } label: {
                    Text(t).font(LF.inter(800, 14)).foregroundStyle(tab == i ? Color(hex: "0B0C0D") : .white.opacity(0.7)).frame(maxWidth: .infinity).frame(height: 40)
                        .background { if tab == i { Capsule().fill(.white).matchedGeometryEffect(id: "tab", in: tabNS) } }
                }.buttonStyle(.plain)
            }
        }.padding(3).background(.white.opacity(0.07), in: Capsule())
    }

    private var recsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(recs) { f in
                    Button { choosePlay(f.pick, f.previewURL) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            art(f.pick, 132, 18, f.id)
                            Text(f.pick.title).font(LF.inter(800, 13)).foregroundStyle(.white).lineLimit(1)
                            Text(f.pick.artist).font(LF.inter(600, 11.5)).foregroundStyle(grey).lineLimit(1)
                        }.frame(width: 132)
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 20)
        }
    }

    private func list(_ items: [AppleMusicCatalog.Found]) -> some View {
        ForEach(items) { f in row(f.pick, previewURL: f.previewURL) }
    }

    private func key(_ p: MusicPick) -> String { p.songID ?? p.title + p.artist }

    private func art(_ p: MusicPick, _ size: CGFloat, _ r: CGFloat, _ id: String) -> some View {
        ZStack {
            AsyncImage(url: p.artworkURL.flatMap(URL.init(string:))) { ph in if let i = ph.image { i.resizable().scaledToFill() } else { Color.white.opacity(0.1) } }
            if playback.isPlaying(key(p)) {
                Color.black.opacity(0.35)
                MusicEqualizer(animating: true, lime: true)
            }
        }.frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
    }

    private func row(_ p: MusicPick, previewURL: URL?) -> some View {
        let on = selected == p, playing = playback.isPlaying(key(p))
        return Button { choosePlay(p, previewURL) } label: {
            HStack(spacing: 12) {
                art(p, 52, 12, key(p))
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.title).font(LF.inter(800, 15)).foregroundStyle(on ? HV.lime : .white)
                    Text(p.artist).font(LF.inter(600, 12.5)).foregroundStyle(grey)
                }.lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: playing ? "pause.fill" : "play.fill").font(.system(size: 14, weight: .bold))
                    .foregroundStyle(playing ? Color(hex: "0B0C0D") : .white).frame(width: 44, height: 44)
                    .background(playing ? HV.lime : .white.opacity(0.1), in: Circle())
            }.padding(.horizontal, 20).padding(.vertical, 6).contentShape(Rectangle())
        }.buttonStyle(.plain)
        .accessibilityLabel("\(p.title)、\(p.artist)\(on ? "、選択中" : "")")
    }

    private var linkField: some View {
        HStack(spacing: 8) {
            Image(systemName: "link").foregroundStyle(grey)
            TextField("music.apple.com の リンクを はる", text: $linkText).font(LF.inter(600, 14)).foregroundStyle(.white).textInputAutocapitalization(.never).autocorrectionDisabled()
                .onChange(of: linkText) { _, v in readLink(v) }
            if linkLoading { ProgressView().scaleEffect(0.8) }
        }.padding(.horizontal, 16).frame(height: 46).background(.white.opacity(0.08), in: Capsule())
    }

    // 下:えらんだ 曲の バー + この曲にする
    private var bottomBar: some View {
        VStack(spacing: 10) {
            if let sel = selected {
                HStack(spacing: 10) {
                    art(sel, 40, 9, key(sel))
                    VStack(alignment: .leading, spacing: 2) { Text(sel.title).font(LF.inter(800, 14)).foregroundStyle(.white); Text("プレビュー").font(LF.mono(9)).tracking(1.5).foregroundStyle(grey) }.lineLimit(1)
                    Spacer()
                }.padding(.horizontal, 6)
            }
            Button(action: choose) {
                Text(selected == nil ? "曲を えらんでください" : "この曲にする").font(LF.inter(800, 16)).foregroundStyle(selected == nil ? grey : Color(hex: "0B0C0D"))
                    .frame(maxWidth: .infinity).frame(height: 56).background(selected == nil ? Color.white.opacity(0.08) : HV.lime, in: Capsule())
            }.buttonStyle(HVPress(scale: 0.97)).disabled(selected == nil)
            if current != nil { Button(action: remove) { Text("音楽を はずす").font(LF.inter(700, 13)).foregroundStyle(grey).frame(maxWidth: .infinity).frame(height: 36) }.buttonStyle(.plain) }
        }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 10)
            .background(LinearGradient(colors: [bg.opacity(0), bg, bg], startPoint: .top, endPoint: .bottom))
    }

    // MARK: 動き

    /// 行を おす = えらぶ + すぐ 流れる(もう1回 = 止める)
    private func choosePlay(_ p: MusicPick, _ url: URL?) {
        Haptics.play(.sel)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = p }
        playback.toggle(key: key(p), url: url ?? p.previewURL.flatMap(URL.init(string:)))
    }

    private func loadAll() async {
        guard access == .ready else { return }
        async let r = AppleMusicCatalog.recommendations()
        async let c = AppleMusicCatalog.charts()
        async let rc = AppleMusicCatalog.recent()
        async let l = AppleMusicCatalog.library()
        let (a, b, d, e) = await (r, c, rc, l)
        recs = a; charts = b; recent = d; library = e
    }

    private func scheduleSearch(_ value: String, now: Bool = false) {
        searchTask?.cancel()
        let q = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { results = []; libraryHits = []; searching = false; return }
        searchTask = Task {
            if !now { try? await Task.sleep(for: .milliseconds(400)); guard !Task.isCancelled else { return } }
            searching = true
            let found = (try? await Task.detached { try await AppleMusicCatalog.search(q) }.value) ?? []
            let lib = await AppleMusicCatalog.library(term: q)
            guard term.trimmingCharacters(in: .whitespacesAndNewlines) == q else { return }
            searching = false; results = found; libraryHits = lib
        }
    }

    private func readLink(_ text: String) {
        guard let f = MusicLink.find(in: text) else { linkPick = nil; return }
        linkLoading = true
        Task {
            let p = await MusicLink.pick(from: f.url, service: f.service)
            linkLoading = false
            guard linkText == text else { return }
            linkPick = p; Haptics.play(.detent); selected = p
        }
    }

    private func choose() {
        guard let selected else { return }
        Haptics.play(.success)
        // えらんだ 曲が まだ 流れて いなければ 流す(決めた あとも 流れる)
        if !playback.isPlaying(key(selected)), let u = selected.previewURL.flatMap(URL.init(string:)) { playback.start(key: key(selected), url: u) }
        onDone(selected)
        dismiss()
    }

    private func remove() {
        Haptics.play(.soft)
        playback.stop()
        onDone(nil)
        dismiss()
    }
}
