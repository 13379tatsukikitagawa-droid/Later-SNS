import SwiftUI

// v50:Recap プレイヤー。動画みたいに 自動で 流れる(タップで 前/次、押しつづけると 止まる)。
// 書き出し(保存)は RecapExporter が やる、本物の 無音 .mp4。音楽は入れない(でっちあげない)。

struct RecapPlayerView: View {
    let days: [MEDay]
    let images: (MEShot) -> UIImage?
    var onClose: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var style: RecapStyle = .film
    @State private var segments: [RecapSegment] = []
    @State private var index = 0
    @State private var paused = false
    @State private var progress: Double = 0
    @State private var isExporting = false
    @State private var exportedURL: URL?
    @State private var exportError: String?
    @State private var shareItems: [Any]?
    @State private var toast: String?

    private var current: RecapSegment? { segments.indices.contains(index) ? segments[index] : nil }
    private var isEnd: Bool { if case .end = current { return true } else { return false } }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()
                if let current {
                    segmentView(current, width: proxy.size.width, height: proxy.size.height)
                        .id(current.id)
                        .transition(.opacity)
                }
                VStack(spacing: 10) {
                    progressBars
                    topBar
                    Spacer()
                }
                .padding(.top, 54)

                HStack(spacing: 0) {
                    Color.clear.contentShape(Rectangle()).onTapGesture { go(index - 1) }
                    Color.clear.contentShape(Rectangle()).onTapGesture { go(index + 1) }
                }
                .allowsHitTesting(!isEnd)
            }
        }
        .statusBarHidden()
        .onAppear(perform: start)
        .onChange(of: style) { _, _ in rebuild(resetIndex: false) }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in paused = true }
                .onEnded { _ in paused = false }
        )
        .task { await runClock() }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(.white.opacity(0.18)))
                    .padding(.top, 70)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: toast)
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
            ShareSheet(activityItems: shareItems ?? []) { _ in shareItems = nil }
        }
    }

    // MARK: - 進み

    private func start() {
        rebuild(resetIndex: true)
        Haptics.play(.projector)
    }

    private func rebuild(resetIndex: Bool) {
        segments = RecapSequence.build(days: days, image: images)
        if resetIndex { index = 0 }
        progress = 0
    }

    /// 30fps で、いまのコマの進みを足す(Timer/Combine を 使わず、ほかの場所と同じ task + sleep の形)
    private func runClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(33))
            guard !paused, !isEnd, let current else { continue }
            let duration = current.duration(style: style)
            guard duration > 0 else { continue }
            progress += (1.0 / 30) / duration
            if progress >= 1 { go(index + 1) }
        }
    }

    private func go(_ newIndex: Int) {
        guard !segments.isEmpty else { return }
        let clamped = max(0, min(segments.count - 1, newIndex))
        guard clamped != index || progress > 0 else { return }
        index = clamped
        progress = 0
        Haptics.play(isEnd ? .success : .tick)
    }

    // MARK: - 見た目

    private var progressBars: some View {
        HStack(spacing: 4) {
            ForEach(Array(segments.enumerated()).filter { !isEndSegment($0.element) }, id: \.offset) { i, _ in
                Capsule()
                    .fill(.white.opacity(0.28))
                    .overlay(alignment: .leading) {
                        Capsule().fill(.white)
                            .frame(width: barWidth(for: i))
                    }
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity)
                    .frame(height: 2.5)
            }
        }
        .padding(.horizontal, 10)
    }

    private func isEndSegment(_ segment: RecapSegment) -> Bool { if case .end = segment { return true } else { return false } }

    private func barWidth(for i: Int) -> CGFloat {
        guard i <= index else { return 0 }
        if i < index { return 1000 }
        return CGFloat(progress) * 1000
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Text("Your week").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
            Spacer()
            Picker("", selection: $style) {
                ForEach(RecapStyle.allCases) { s in Text(s.label).tag(s) }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .colorScheme(.dark)
            Button {
                Haptics.play(.soft)
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.white.opacity(0.16)))
            }
        }
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private func segmentView(_ segment: RecapSegment, width: CGFloat, height: CGFloat) -> some View {
        switch segment {
        case .day(let day):
            VStack(spacing: 10) {
                Text(MERules.label(ago: day.ago, date: day.date)).font(.system(size: 30, weight: .heavy)).foregroundStyle(.white)
                Text(MERules.dot(day.date)).font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
            }
            .frame(width: width, height: height)
        case .photo(let day, let shot, let image, let kept):
            ZStack(alignment: .bottom) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: width, height: height).clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 4) {
                    if let tag = day.tags.first {
                        Text("#\(tag)").font(.system(size: 14, weight: .black)).foregroundStyle(Color(hex: "FFB27A"))
                    }
                    Text(MERules.dot(day.date) + "  " + shot.takenAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                }
                .padding(.horizontal, 20).padding(.bottom, 36)
                .frame(maxWidth: .infinity, alignment: .leading)
                if kept {
                    Text("★").font(.system(size: 18)).foregroundStyle(Color(hex: "FFD60A"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 54)
                }
            }
            .frame(width: width, height: height)
        case .end(let total, let kept, let range, let covers):
            endView(total: total, kept: kept, range: range, covers: covers, width: width, height: height)
        }
    }

    private func endView(total: Int, kept: Int, range: String, covers: [UIImage], width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 18) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                ForEach(Array(covers.prefix(6).enumerated()), id: \.offset) { _, image in
                    Image(uiImage: image).resizable().scaledToFill().frame(height: width / 3).clipped()
                }
            }
            .frame(width: width)

            VStack(spacing: 8) {
                Text(range).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
                Text("That was\nyour week.").multilineTextAlignment(.center).font(.system(size: 28, weight: .heavy)).foregroundStyle(.white)
                Text("\(total) shots · 7 days · \(kept) kept")
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
            }

            if isExporting {
                ProgressView().tint(.white).padding(.top, 6)
            } else {
                HStack(spacing: 10) {
                    endButton("Save", systemImage: "square.and.arrow.down", action: save)
                    endButton("Share", systemImage: "square.and.arrow.up", prominent: true, action: shareRecap)
                    endButton("", systemImage: "arrow.counterclockwise") { go(0) }
                }
            }
            if let exportError { Text(exportError).font(.system(size: 11)).foregroundStyle(.red.opacity(0.8)) }
        }
        .padding(.horizontal, 24)
        .frame(width: width, height: height)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, height * 0.12)
    }

    private func endButton(_ title: String, systemImage: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).font(.system(size: 13, weight: .bold))
                if !title.isEmpty { Text(title).font(.system(size: 13, weight: .bold)) }
            }
            .foregroundStyle(prominent ? .black : .white)
            .padding(.horizontal, title.isEmpty ? 14 : 18)
            .frame(height: 44)
            .background(Capsule().fill(prominent ? Color.white : Color.white.opacity(0.16)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 保存・共有(すべて 端末の中だけ)

    private func exportIfNeeded() async -> URL? {
        if let exportedURL { return exportedURL }
        isExporting = true
        exportError = nil
        defer { isExporting = false }
        do {
            let url = try await RecapExporter.export(segments: segments, style: style)
            exportedURL = url
            return url
        } catch {
            exportError = "書き出しに失敗しました。もう一度 おためしください。"
            return nil
        }
    }

    private func save() {
        Haptics.play(.tick)
        Task {
            guard let url = await exportIfNeeded() else { return }
            do {
                try await RecapExporter.saveToPhotoLibrary(url: url)
                Haptics.play(.success)
                toast = "写真に 保存しました"
            } catch {
                exportError = "写真への保存が できませんでした(設定 > 写真 を確認)"
            }
        }
    }

    private func shareRecap() {
        Haptics.play(.tick)
        Task {
            guard let url = await exportIfNeeded() else { return }
            shareItems = [url]
        }
    }
}
