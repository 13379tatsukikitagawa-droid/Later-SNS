import SwiftUI
import AVFoundation
import Photos

// P29(v86)B:Recap の 再生(ストーリーの 形)。題 1.7秒 → 写真 1枚 1.3秒 → おわり。動画ファイルは 使わず その場で 動かす。
// 右 2/3 = 次 ・ 左 1/3 = 前 ・ 長押し = 止める ・ × = とじる。保存 ・ シェアの 時だけ 動画(1080 × 1920)に する。

struct RecapPlayer: View {
    let recap: RecapManifest
    let data: MEV86Data
    var debugT: Double? = nil
    var onClose: () -> Void
    var onEnd: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var elapsed: Double = 0
    @State private var paused = false
    @State private var ended = false
    @State private var exporting = false
    @State private var exportURL: URL?
    @State private var toast: String?
    @State private var shareItems: [Any]?

    static let titleDur = 1.7, photoDur = 1.3
    private var shots: [MEV86Shot] { recap.photoIDs.compactMap { data.shot($0) } }
    private var total: Double { (reduceMotion ? 0 : Self.titleDur) + Double(shots.count) * Self.photoDur }
    private var titleLen: Double { reduceMotion ? 0 : Self.titleDur }

    var body: some View {
        let t = debugT ?? elapsed
        ZStack {
            Color.black.ignoresSafeArea()
            if t >= total || shots.isEmpty { endCard } else if t < titleLen { title(t) } else { photo(t) }
            // 上の 線(1日 = 1本)
            if t < total, !shots.isEmpty { bars(t).padding(.horizontal, 12).padding(.top, 56).frame(maxHeight: .infinity, alignment: .top) }
            if t < total {
                HStack(spacing: 0) {
                    Color.clear.frame(maxWidth: .infinity).contentShape(Rectangle()).onTapGesture { go(-1) }
                    Color.clear.frame(maxWidth: .infinity).frame(maxWidth: .infinity).contentShape(Rectangle()).onTapGesture { go(1) }
                    Color.clear.frame(maxWidth: .infinity).contentShape(Rectangle()).onTapGesture { go(1) }
                }.simultaneousGesture(LongPressGesture(minimumDuration: 0.24).onChanged { _ in }.onEnded { _ in paused = true }.sequenced(before: DragGesture(minimumDistance: 0)).onEnded { _ in paused = false })
            }
            Button { Haptics.play(.tick); onClose() } label: { Image(systemName: "xmark").font(.system(size: 16, weight: .black)).foregroundStyle(.white).frame(width: 40, height: 40).background(.black.opacity(0.35), in: Circle()) }
                .buttonStyle(.plain).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(.trailing, 14).padding(.top, 78)
            if let toast { Text(toast).font(Typo.ui(700, 13)).foregroundStyle(HV.ink).padding(.horizontal, 16).frame(height: 36).background(.white, in: Capsule()).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 130) }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 33_000_000)
                tick()
            }
        }
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) { ShareSheet(activityItems: shareItems ?? []) { _ in shareItems = nil }.presentationDetents([.medium, .large]) }
        .onAppear { Haptics.play(.projector) }
    }

    private func tick() {
        guard debugT == nil, !paused, scenePhase == .active, elapsed < total else { return }
        let before = elapsed
        elapsed += 1.0 / 30
        if before < total && elapsed >= total { finish() }
        if Int((before - titleLen) / Self.photoDur) != Int((elapsed - titleLen) / Self.photoDur), elapsed > titleLen, elapsed < total { dayChange() }
    }

    private func dayChange() {
        let i = Int((elapsed - titleLen) / Self.photoDur)
        guard shots.indices.contains(i), i > 0 else { return }
        if !Calendar.current.isDate(shots[i].date, inSameDayAs: shots[i - 1].date) { Haptics.play(.soft) }
    }
    private func finish() { guard !ended else { return }; ended = true; Haptics.play(.success); onEnd() }
    private func go(_ d: Int) {
        Haptics.play(.tick)
        let idx = max(0, Int((elapsed - titleLen) / Self.photoDur) + d)
        elapsed = idx < 0 ? 0 : (elapsed < titleLen && d < 0 ? 0 : titleLen + Double(idx) * Self.photoDur + 0.01)
        if d < 0 && elapsed >= total { elapsed = max(0, total - Self.photoDur) }
        ended = elapsed >= total
    }

    // 題(1行ずつ ぼかし → くっきり)
    private func title(_ t: Double) -> some View {
        func line(_ s: String, _ at: Double, size: CGFloat = 84, italic: Bool = false, color: Color = .white, mono: Bool = false) -> some View {
            let u = max(0, min(1, (t - at) / 0.6))
            return Group { if mono { Text(s).font(Typo.label(12)).tracking(3).foregroundStyle(color) } else { Text(s).font(Typo.title(size, italic: italic)).foregroundStyle(color) } }
                .blur(radius: 10 * (1 - u)).opacity(u).offset(y: 24 * (1 - u))
        }
        return VStack(alignment: .leading, spacing: 0) {
            line("LATTAG RECAP", 0, color: .white.opacity(0.6), mono: true)
            line("Your", 0.2).padding(.top, 12)
            line("week.", 0.4, italic: true, color: HV.lime).padding(.top, -12)
            line("\(RecapPlayerFmt.range(recap)) ・ \(recap.shots) SHOTS", 0.9, color: .white.opacity(0.6), mono: true).padding(.top, 14)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).padding(.horizontal, 28)
    }

    // 写真
    private func photo(_ t: Double) -> some View {
        let i = min(shots.count - 1, Int((t - titleLen) / Self.photoDur))
        let u = ((t - titleLen) - Double(i) * Self.photoDur) / Self.photoDur
        let s = shots[i]
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US"); df.dateFormat = "EEE d"
        let tf = DateFormatter(); tf.dateFormat = "HH:mm"
        return ZStack(alignment: .bottomLeading) {
            Color(hex: "1A1614")
            if let im = s.image { Image(uiImage: im).resizable().scaledToFill().scaleEffect(reduceMotion ? 1 : 1.14 - 0.12 * u).offset(x: reduceMotion ? 0 : CGFloat((i % 2 == 0 ? -1 : 1)) * 12 * CGFloat(u)) }
            LinearGradient(colors: [.black.opacity(0.4), .clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Text(df.string(from: s.date).uppercased()).font(Typo.title(64)).foregroundStyle(.white)
                HStack(spacing: 10) { Text(tf.string(from: s.date)).font(Typo.label(13)).foregroundStyle(HV.lime); if let tag = s.tag { Text("#\(tag)").font(Typo.ui(800, 14)).foregroundStyle(.white) } }
            }.padding(.horizontal, 24).padding(.bottom, 60)
        }.clipped().id(i).transition(.opacity)
    }

    // 上の 線:1日 = 1本
    private func bars(_ t: Double) -> some View {
        let cal = Calendar.current
        let days = Dictionary(grouping: shots.indices, by: { cal.startOfDay(for: shots[$0].date) }).sorted { $0.key < $1.key }
        let cur = (t - titleLen) / Self.photoDur
        return HStack(spacing: 4) {
            ForEach(days.indices, id: \.self) { d in
                let idxs = days[d].value
                let p = t < titleLen ? 0 : max(0, min(1, (cur - Double(idxs.first ?? 0)) / Double(max(1, idxs.count))))
                GeometryReader { g in ZStack(alignment: .leading) { Capsule().fill(.white.opacity(0.3)); Capsule().fill(.white).frame(width: g.size.width * p) } }.frame(height: 3)
            }
        }
    }

    // おわり
    private var endCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 110)
            Text("Your").font(Typo.title(64)).foregroundStyle(.white).frame(height: 56, alignment: .leading)
            Text("week.").font(Typo.title(64, italic: true)).foregroundStyle(HV.lime).frame(height: 60, alignment: .leading)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                cell("\(recap.shots)", "SHOTS"); cell("\(recap.days)", "DAYS"); cell("\(recap.kept)", "KEPT ★"); cell(recap.peakHour.map { "\($0):00" } ?? "—", "よく 撮る 時間")
            }.padding(.top, 22)
            if let tag = recap.topTag { HStack { Text("いちばん 多い タグ").font(Typo.ui(700, 13)).foregroundStyle(HV.ink.opacity(0.7)); Spacer(); Text("#\(tag)").font(Typo.ui(900, 18)).foregroundStyle(HV.ink) }.padding(.horizontal, 18).frame(height: 56).background(HV.lime, in: RoundedRectangle(cornerRadius: 18, style: .continuous)).padding(.top, 8) }
            Spacer()
            HStack(spacing: 8) {
                endButton(exporting ? "作って います…" : "保存", white: false) { save() }
                endButton("シェア", white: true) { share() }
                Button { Haptics.play(.sel); elapsed = 0; ended = false } label: { Image(systemName: "arrow.counterclockwise").font(.system(size: 18, weight: .bold)).foregroundStyle(.white).frame(width: 56, height: 56).background(.white.opacity(0.12), in: Circle()) }.buttonStyle(HVPress(scale: 0.92))
            }.padding(.bottom, 48)
        }.padding(.horizontal, 20).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    private func cell(_ n: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(n).font(Typo.ui(900, 34)).foregroundStyle(.white); Text(l).font(Typo.label(10)).tracking(1.5).foregroundStyle(.white.opacity(0.5)) }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Color(hex: "141517"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    private func endButton(_ t: String, white: Bool, _ a: @escaping () -> Void) -> some View {
        Button { Haptics.play(.click); a() } label: { Text(t).font(Typo.ui(800, 16)).foregroundStyle(white ? HV.ink : .white).frame(maxWidth: .infinity).frame(height: 56).background(white ? Color.white : Color.white.opacity(0.12), in: Capsule()) }.buttonStyle(HVPress(scale: 0.97))
    }

    // 保存 ・ シェア(動画に する 時だけ。サーバーには 上げない)
    private func render(_ then: @escaping (URL) -> Void) {
        if let u = exportURL { then(u); return }
        guard !exporting else { return }
        exporting = true
        let r = recap, imgs = shots.map { ($0.image, $0.date, $0.tag) }
        Task {
            let url = try? await RecapVideoExporter.export(recap: r, shots: imgs)
            exporting = false
            if let url { exportURL = url; then(url) } else { flash("動画を つくれませんでした") }
        }
    }
    private func save() {
        render { url in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { st in
                guard st == .authorized || st == .limited else { DispatchQueue.main.async { flash("写真への 追加を 許可して ください") }; return }
                PHPhotoLibrary.shared().performChanges({ PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) }) { ok, _ in DispatchQueue.main.async { if ok { Haptics.play(.success) }; flash(ok ? "写真に 保存しました" : "保存できませんでした") } }
            }
        }
    }
    private func share() { render { url in shareItems = [url] } }
    private func flash(_ s: String) { toast = s; DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { if toast == s { toast = nil } } }
}

enum RecapPlayerFmt {
    static func range(_ r: RecapManifest) -> String { MEV86View.range(r) }
}

/// 1080 × 1920 ・ 30fps ・ H.264(題 → 1枚 1.3秒 → おわり)。Core Graphics で 1コマずつ 描く
enum RecapVideoExporter {
    static func export(recap: RecapManifest, shots: [(UIImage?, Date, String?)]) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("recap-\(recap.id).mp4")
        try? FileManager.default.removeItem(at: url)
        let w = 1080, h = 1920, fps = 30
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: .zero)
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US"); df.dateFormat = "EEE d"
        let sections: [(Int, (CGContext, Double) -> Void)] =
            [(Int(1.7 * Double(fps)), { c, u in drawTitle(c, recap, u, w, h) })]
            + shots.map { s in (Int(1.3 * Double(fps)), { c, u in drawPhoto(c, s.0, df.string(from: s.1).uppercased(), s.2, u, w, h) }) }
            + [(Int(2.0 * Double(fps)), { c, u in drawEnd(c, recap, w, h) })]
        var frame = 0
        for (count, draw) in sections {
            for k in 0..<count {
                while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 4_000_000) }
                var pb: CVPixelBuffer?
                guard let pool = adaptor.pixelBufferPool, CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb) == kCVReturnSuccess, let buf = pb else { continue }
                CVPixelBufferLockBaseAddress(buf, [])
                if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: w, height: h, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) {
                    ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)   // UIKit の 向き
                    UIGraphicsPushContext(ctx)
                    UIColor.black.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
                    draw(ctx, Double(k) / Double(max(1, count)))
                    UIGraphicsPopContext()
                }
                CVPixelBufferUnlockBaseAddress(buf, [])
                adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(fps)))
                frame += 1
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        return url
    }

    private static func text(_ s: String, _ size: CGFloat, _ color: UIColor, at p: CGPoint, bold: Bool = false) {
        (s as NSString).draw(at: p, withAttributes: [.font: bold ? UIFont.systemFont(ofSize: size, weight: .heavy) : UIFont.systemFont(ofSize: size, weight: .regular), .foregroundColor: color])
    }
    private static func drawTitle(_ c: CGContext, _ r: RecapManifest, _ u: Double, _ w: Int, _ h: Int) {
        let a = CGFloat(min(1, u * 3))
        text("LATTAG RECAP", 34, UIColor.white.withAlphaComponent(0.6 * a), at: CGPoint(x: 80, y: 700))
        text("Your", 220, UIColor.white.withAlphaComponent(a), at: CGPoint(x: 70, y: 760), bold: true)
        text("week.", 220, UIColor(red: 0.78, green: 0.95, blue: 0.35, alpha: a), at: CGPoint(x: 70, y: 980), bold: true)
        text("\(MEV86View.range(r)) ・ \(r.shots) SHOTS", 36, UIColor.white.withAlphaComponent(0.6 * a), at: CGPoint(x: 80, y: 1260))
    }
    private static func drawPhoto(_ c: CGContext, _ img: UIImage?, _ date: String, _ tag: String?, _ u: Double, _ w: Int, _ h: Int) {
        if let img {
            let s = max(CGFloat(w) / img.size.width, CGFloat(h) / img.size.height) * CGFloat(1.14 - 0.12 * u)
            let dw = img.size.width * s, dh = img.size.height * s
            img.draw(in: CGRect(x: (CGFloat(w) - dw) / 2, y: (CGFloat(h) - dh) / 2, width: dw, height: dh))
        }
        let grad = CGGradient(colorsSpace: nil, colors: [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.75).cgColor] as CFArray, locations: [0, 1])!
        c.drawLinearGradient(grad, start: CGPoint(x: 0, y: CGFloat(h) * 0.6), end: CGPoint(x: 0, y: CGFloat(h)), options: [])
        text(date, 150, .white, at: CGPoint(x: 70, y: CGFloat(h) - 400), bold: true)
        if let tag { text("#\(tag)", 40, .white, at: CGPoint(x: 80, y: CGFloat(h) - 230), bold: true) }
    }
    private static func drawEnd(_ c: CGContext, _ r: RecapManifest, _ w: Int, _ h: Int) {
        text("Your", 150, .white, at: CGPoint(x: 70, y: 300), bold: true)
        text("week.", 150, UIColor(red: 0.78, green: 0.95, blue: 0.35, alpha: 1), at: CGPoint(x: 70, y: 470), bold: true)
        let items = [("\(r.shots)", "SHOTS"), ("\(r.days)", "DAYS"), ("\(r.kept)", "KEPT ★"), (r.peakHour.map { "\($0):00" } ?? "—", "PEAK")]
        for (i, it) in items.enumerated() {
            let x = 70 + (i % 2) * 480, y = 800 + (i / 2) * 300
            UIColor(white: 0.1, alpha: 1).setFill(); UIBezierPath(roundedRect: CGRect(x: x, y: y, width: 440, height: 260), cornerRadius: 40).fill()
            text(it.0, 100, .white, at: CGPoint(x: x + 36, y: y + 40), bold: true)
            text(it.1, 34, UIColor.white.withAlphaComponent(0.5), at: CGPoint(x: x + 36, y: y + 180))
        }
        if let t = r.topTag { text("#\(t)", 70, UIColor(red: 0.78, green: 0.95, blue: 0.35, alpha: 1), at: CGPoint(x: 80, y: 1480), bold: true) }
    }
}
