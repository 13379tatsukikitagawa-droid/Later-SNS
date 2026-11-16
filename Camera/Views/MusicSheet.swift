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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let size: CGFloat = 46
    static let expandedWidth: CGFloat = 206

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                Capsule().fill(Color(red: 40 / 255, green: 40 / 255, blue: 44 / 255).opacity(0.72))
                    .background(.ultraThinMaterial.opacity(0.4), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
                if let pick {
                    HStack(spacing: 9) {
                        MusicDisc(artworkURL: pick.artworkURL, seed: pick.title, spinning: !reduceMotion)
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
                        MusicEqualizer(animating: !reduceMotion)
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
        .buttonStyle(SquishButtonStyle(pressedScale: 0.93))
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
    private static let opacities: [Double] = [1, 0.7, 0.45]

    var body: some View {
        TimelineView(.animation(paused: !animating)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    let phase = animating ? (sin((t / 0.9 + Double(i) * 0.33) * 2 * .pi) + 1) / 2 : 0.5
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.white.opacity(Self.opacities[i]))
                        .frame(width: 3, height: 4 + 10 * phase)
                }
            }
            .frame(height: 14, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - シート「今日の 1曲を つける」

struct MusicSheet: View {
    /// いま つけている 曲
    let current: MusicPick?
    /// 「この曲にする」(nil = はずす)
    let onDone: (MusicPick?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var access: AppleMusicCatalog.Access = AppleMusicCatalog.access
    @State private var subscribed = true
    @State private var term = ""
    @State private var results: [AppleMusicCatalog.Found] = []
    @State private var searching = false
    /// 失敗の 本当の 中身(開発用に 小さく 出す)。nil なら 失敗していない
    @State private var searchError: String?
    /// 開発用:許可と サブスクの 状態
    @State private var statusLine = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var linkText = ""
    @State private var linkPick: MusicPick?
    @State private var linkLoading = false
    @State private var selected: MusicPick?
    @State private var player: AVPlayer?
    @State private var playingID: String?

    private static let ink = Color(hex: "111111")
    private static let gray = Color(hex: "8E8E95")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(Color(hex: "D9D8DE")).frame(width: 38, height: 5)
                .frame(maxWidth: .infinity).padding(.top, 8)
            HStack(alignment: .firstTextBaseline) {
                Text("今日の 1曲を つける").font(.system(size: 20, weight: .black)).foregroundStyle(Self.ink)
                Spacer()
                Text("MUSIC").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1).foregroundStyle(Self.gray)
            }
            .padding(.top, 14)

            appleBody
                .frame(maxHeight: .infinity, alignment: .top)

            Button(action: choose) {
                Text(selected == nil ? "曲を えらんでください" : "この曲にする")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(selected == nil ? Self.gray : .white)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(selected == nil ? Color(hex: "F1F0F4") : Self.ink))
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
            .disabled(selected == nil)
            if current != nil {
                Button(action: remove) {
                    Text("音楽を はずす").font(.system(size: 13, weight: .bold)).foregroundStyle(Self.gray)
                        .frame(maxWidth: .infinity).frame(height: 40)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .background(Color.white.ignoresSafeArea())
        .preferredColorScheme(.light)
        .presentationDetents([.large])
        .presentationCornerRadius(32)
        .presentationDragIndicator(.hidden)
        .onAppear { selected = current }
        .task {
            if access == .ready { subscribed = await AppleMusicCatalog.hasSubscription() }
            statusLine = await AppleMusicCatalog.statusLine()
        }
        .onDisappear {
            searchTask?.cancel()
            player?.pause()
        }
    }


    // MARK: Apple Music

    @ViewBuilder
    private var appleBody: some View {
        switch access {
        case .ready:
            VStack(alignment: .leading, spacing: 10) {
                searchField
                if !subscribed {
                    note("Apple Music に 入っていない 場合は、試聴だけに なります。リンクを はる 方法も 使えます。")
                }
                resultList
                if !subscribed { linkField(placeholder: "music.apple.com の リンクを はる") }
            }
            .padding(.top, 14)
        case .notDetermined:
            connect(text: "Apple Music に つなぐと、曲を さがして つけられます。\nその人の ライブラリは 読みません。")
        case .denied:
            VStack(alignment: .leading, spacing: 10) {
                note("Apple Music の 許可が ありません。設定アプリの「Lattag」で「メディアと Apple Music」を オンにしてください。\nApple Music に 入っていない 場合は、リンクを はる 方法を 使ってください。")
                linkField(placeholder: "music.apple.com の リンクを はる")
                linkResult
            }
            .padding(.top, 18)
        case .unavailable:
            VStack(alignment: .leading, spacing: 10) {
                note("この 端末では、Apple Music を 使えません。Apple Music に 入っていない 場合は、リンクを はる 方法を 使ってください。")
                linkField(placeholder: "music.apple.com の リンクを はる")
                linkResult
            }
            .padding(.top, 18)
        }
    }

    private func connect(text: String) -> some View {
        VStack(spacing: 16) {
            Text(text)
                .font(.system(size: 13, weight: .semibold)).lineSpacing(5)
                .foregroundStyle(Color(hex: "6E6E76"))
                .multilineTextAlignment(.center)
            Button {
                Task {
                    let result = await AppleMusicCatalog.requestAccess()
                    if result == .ready {
                        Haptics.play(.success)   // つなぐ(許可が 通った)
                        subscribed = await AppleMusicCatalog.hasSubscription()
                    } else {
                        Haptics.play(.warn)
                    }
                    withAnimation { access = result }
                    statusLine = await AppleMusicCatalog.statusLine()
                }
            } label: {
                Text("つなぐ").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Self.ink))
            }
            .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
        }
        .padding(.top, 26)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .bold)).foregroundStyle(Self.gray)
            TextField("曲名・アーティスト", text: $term)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Self.ink)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onChange(of: term) { _, value in scheduleSearch(value) }
                .onSubmit { scheduleSearch(term, now: true) }
            if searching { ProgressView().scaleEffect(0.8) }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: "F4F3F7")))
    }

    private var resultList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if let searchError {
                    note("さがせませんでした。")
                    debugText(searchError)
                } else if !term.isEmpty, results.isEmpty, !searching {
                    note("見つかりませんでした")
                }
                ForEach(results) { found in
                    row(found.pick, previewURL: found.previewURL, id: found.id)
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom) {
            // 開発用:許可と サブスクの 状態(小さな 灰色の 文字)
            if !statusLine.isEmpty { debugText(statusLine) }
        }
    }

    /// 開発用の 小さな 文字(選んで コピーできる)
    private func debugText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .regular, design: .monospaced))
            .foregroundStyle(Color(hex: "9A9AA2"))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }

    private func linkField(placeholder: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "link").font(.system(size: 14, weight: .bold)).foregroundStyle(Self.gray)
            TextField(placeholder, text: $linkText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Self.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: linkText) { _, value in readLink(value) }
            if linkLoading { ProgressView().scaleEffect(0.8) }
            PasteButton(payloadType: String.self) { strings in
                if let text = strings.first { linkText = text }
            }
            .labelStyle(.titleOnly)
            .buttonBorderShape(.capsule)
            .tint(Self.ink)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: "F4F3F7")))
    }

    @ViewBuilder
    private var linkResult: some View {
        if let linkPick {
            row(linkPick, previewURL: nil, id: "link")
        } else if !linkText.isEmpty, !linkLoading, MusicLink.find(in: linkText) == nil {
            note("曲の リンクが 見つかりません")
        }
    }

    // MARK: 行

    private func row(_ pick: MusicPick, previewURL: URL?, id: String) -> some View {
        let on = selected == pick
        return Button {
            Haptics.play(.detent)   // 曲を えらぶ(コツッ)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = pick }
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: pick.artworkURL.flatMap(URL.init(string:))) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { Color(hex: "E3E2E9") }
                }
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(pick.title).font(.system(size: 14.5, weight: .heavy)).foregroundStyle(Self.ink)
                    Text(pick.artist).font(.system(size: 12, weight: .medium)).foregroundStyle(Self.gray)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                // 30秒の 試聴(えらんだ 行だけ。自動では 流さない)
                if on, let previewURL {
                    Button { togglePreview(previewURL, id: id) } label: {
                        Image(systemName: playingID == id ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(Self.ink)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color(hex: "E3E2E9")))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(playingID == id ? "試聴を とめる" : "試聴する")
                }
                ZStack {
                    Circle().fill(on ? Self.ink : Color(hex: "E3E2E9"))
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .black)).foregroundStyle(.white).opacity(on ? 1 : 0)
                }
                .frame(width: 24, height: 24)
                .scaleEffect(on ? 1 : 0.7)
            }
            .padding(.horizontal, 6).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? Color(hex: "F4F3F7") : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(pick.title)、\(pick.artist)\(on ? "、選択中" : "")")
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold)).lineSpacing(4)
            .foregroundStyle(Color(hex: "6E6E76"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }

    // MARK: 動き

    /// 0.4秒 待ってから 検索(デバウンス)。待っている間に 打ったら、前の 待ちを とりけす。
    /// とりけしは「待ち」の 間だけ。検索を はじめたら、とちゅうで キャンセルしない(結果が 古ければ 捨てるだけ)
    private func scheduleSearch(_ value: String, now: Bool = false) {
        searchTask?.cancel()
        let query = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            results = []
            searching = false
            searchError = nil
            return
        }
        searchTask = Task {
            if !now {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
            }
            searching = true
            let outcome: Result<[AppleMusicCatalog.Found], Error>
            do {
                outcome = .success(try await Task.detached { try await AppleMusicCatalog.search(query) }.value)
            } catch {
                outcome = .failure(error)
            }
            // いまの 入力と ちがう(あとから 打った)結果は 捨てる
            guard term.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }
            searching = false
            switch outcome {
            case .success(let found):
                searchError = nil
                results = found
            case .failure(let error):
                results = []
                searchError = AppleMusicCatalog.describe(error)
                statusLine = await AppleMusicCatalog.statusLine()
            }
        }
    }

    private func readLink(_ text: String) {
        guard let found = MusicLink.find(in: text) else { linkPick = nil; return }
        linkLoading = true
        Task {
            let pick = await MusicLink.pick(from: found.url, service: found.service)
            linkLoading = false
            guard linkText == text else { return }
            linkPick = pick
            Haptics.play(.detent)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = pick }
        }
    }

    private func togglePreview(_ url: URL, id: String) {
        if playingID == id {
            player?.pause()
            playingID = nil
            return
        }
        player?.pause()
        let next = AVPlayer(url: url)
        next.volume = 0.6
        next.play()
        player = next
        playingID = id
    }

    private func choose() {
        guard let selected else { return }
        Haptics.play(.success)
        onDone(selected)
        dismiss()
    }

    private func remove() {
        Haptics.play(.soft)
        onDone(nil)
        dismiss()
    }
}
