import SwiftUI

// v134 Phase 5:ストーリー(ともだちの 丸から 全画面)。見本 screens/25 ・ 26。
// 全画面の 写真 ・ 上に バー(1枚 4.8秒)・ 名前と「16:42に撮った ・ 16h20m 待った」・ ×。左タップで 前 ・ 右タップで 次。最後まで 行ったら 次の 人。
// まだ ひらいていない 人:写真は 見せず(色の 板を 強く ぼかして)、タグだけ。「◯◯は、まだひらいていません」。
// 返信は 1対1の チャットを ひらく(#で返す は しない)。

struct StoryV134View: View {
    var people: [YesterdayV64Input.Post]
    var startIndex = 0
    var onClose: () -> Void
    var onReply: (_ friendID: String, _ name: String) -> Void

    @State private var person = 0
    @State private var photo = 0
    @State private var progress = 0.0
    @State private var paused = false
    @State private var task: Task<Void, Never>?
    @State private var dragY: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let seconds = 4.8
    private var current: YesterdayV64Input.Post { people[max(0, min(person, people.count - 1))] }
    private var pending: Bool { !current.published || current.photos.isEmpty }
    private var shown: YesterdayV64Input.Photo? { pending ? nil : current.photos[min(photo, current.photos.count - 1)] }
    private var count: Int { pending ? 1 : current.photos.count }

    var body: some View {
        if people.isEmpty { Color.black.ignoresSafeArea().onAppear { onClose() } } else { content }
    }

    private var content: some View {
        GeometryReader { g in
            ZStack {
                LTColor.bg.ignoresSafeArea()
                VStack(spacing: 10) {
                    ZStack {
                        Color(hex6: 0x151517).overlay { photoLayer }.clipped()
                        tapZones
                        VStack(spacing: 0) { top; Spacer(); bottomOverPhoto }.allowsHitTesting(true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .padding(.top, max(g.safeAreaInsets.top, 8))
                    replyRow.padding(.horizontal, 14).padding(.bottom, max(g.safeAreaInsets.bottom, 10))
                }
                .ignoresSafeArea(edges: .top)
            }
            .offset(y: max(0, dragY))
            .gesture(DragGesture(minimumDistance: 16).onChanged { if $0.translation.height > 0 { dragY = $0.translation.height; paused = true } }
                .onEnded { v in if v.translation.height > 140 { close() } else { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { dragY = 0 }; paused = false } })
        }
        .preferredColorScheme(.dark)
        .onAppear { person = min(startIndex, max(0, people.count - 1)); start() }
        .onDisappear { task?.cancel() }
    }

    // MARK: 写真

    @ViewBuilder private var photoLayer: some View {
        ZStack {
            Color(hex6: 0x151517)
            if pending {
                LinearGradient(colors: [Color(hex6: 0x6E6660), Color(hex6: 0x2A2624)], startPoint: .top, endPoint: .bottom).blur(radius: 40)
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill").font(.system(size: 28, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                    Text("\(current.name)は、まだひらいていません").font(LTFont.ui(18, weight: .heavy)).foregroundStyle(.white)
                }
            } else if let p = shown, let img = p.image {
                Image(uiImage: img).resizable().scaledToFill().blur(radius: p.opened ? 0 : 28).saturation(p.opened ? 1 : 0.6)
                if !p.opened { Image(systemName: "lock.fill").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white.opacity(0.85)) }
            }
        }
        .clipped()
        .id("\(person)-\(photo)")
        .transition(.opacity)
    }

    private var top: some View {
        VStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(0..<count, id: \.self) { i in
                    GeometryReader { b in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.35))
                            Capsule().fill(Color.white).frame(width: b.size.width * (i < photo ? 1 : (i == photo ? progress : 0)))
                        }
                    }.frame(height: 3)
                }
            }.padding(.horizontal, 10).padding(.top, 8)
            HStack(spacing: 10) {
                Group { if let a = current.avatar { Image(uiImage: a).resizable().scaledToFill() } else { Circle().fill(HomeV134Parts.color(current.name)).overlay(Text(String(current.name.prefix(1))).font(LTFont.ui(16, weight: .heavy)).foregroundStyle(.white)) } }
                    .frame(width: 38, height: 38).clipShape(Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(current.name).font(LTFont.ui(16, weight: .heavy)).foregroundStyle(.white)
                    if let p = shown, let c = p.captured, p.opened {
                        Text("\(HomeV134Rules.clock(c))に撮った · \(HomeV134Rules.waitedLabel(captured: c)) 待った").font(LTFont.ui(13)).foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()
                Button { close() } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44).background(Color.black.opacity(0.35), in: Circle())
                }.accessibilityLabel("とじる")
            }.padding(.horizontal, 12)
        }
        .padding(.bottom, 24)
        .background(LinearGradient(colors: [.black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
    }

    private var bottomOverPhoto: some View {
        HStack(spacing: 8) {
            if let t = shown?.tag { TagChip(text: t, hashColor: HomeV134Parts.hashColor(t)) }
            Spacer()
            if let p = shown, p.opened, let c = p.captured { DateStamp(text: HomeV134Rules.stamp(c)) }
        }
        .padding(.horizontal, 14).padding(.bottom, 14)
    }

    /// 左 40% = 前 ・ 右 60% = 次(おさえている 間は 止まる)
    private var tapZones: some View {
        HStack(spacing: 0) {
            Color.clear.contentShape(Rectangle()).frame(maxWidth: .infinity).onTapGesture { back() }
            Color.clear.contentShape(Rectangle()).frame(maxWidth: .infinity).frame(maxWidth: .infinity).layoutPriority(1).onTapGesture { next() }
        }
        .padding(.top, 110)
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.2).onChanged { _ in paused = true }.onEnded { _ in paused = false })
        .accessibilityHidden(true)
    }

    private var replyRow: some View {
        Group {
            if !current.friendID.isEmpty {
                Button { LTHaptics.play(.tap); task?.cancel(); let p = current; onClose(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onReply(p.friendID, p.name) } } label: {
                    HStack { Text("\(current.name)に返信").font(LTFont.ui(16)).foregroundStyle(LTColor.ink3); Spacer() }
                        .padding(.horizontal, 20).frame(height: 52).overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1.2))
                }.buttonStyle(HVPress(scale: 0.98)).accessibilityLabel("\(current.name)に返信")
            } else { Color.clear.frame(height: 52) }
        }
    }

    // MARK: 進み

    private func start() {
        task?.cancel()
        progress = 0
        task = Task { @MainActor in
            var last = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                let now = Date(); let dt = now.timeIntervalSince(last); last = now
                if paused { continue }
                progress = min(1, progress + dt / Self.seconds)
                if progress >= 1 { next(); last = Date() }
            }
        }
    }

    private func next() {
        if photo + 1 < count { go(photo: photo + 1) }
        else if person + 1 < people.count { LTHaptics.play(.select); withAnimation(.easeOut(duration: 0.2)) { person += 1; photo = 0; progress = 0 } }
        else { close() }
    }

    private func back() {
        if progress > 0.15 || (photo == 0 && person == 0) { withAnimation(.easeOut(duration: 0.15)) { progress = 0 }; if photo > 0 { go(photo: photo - 1) }; return }
        if photo > 0 { go(photo: photo - 1) }
        else if person > 0 { withAnimation(.easeOut(duration: 0.2)) { person -= 1; photo = 0; progress = 0 } }
    }

    private func go(photo p: Int) { LTHaptics.play(.select); withAnimation(.easeOut(duration: 0.2)) { photo = p; progress = 0 } }

    private func close() { task?.cancel(); onClose() }
}
