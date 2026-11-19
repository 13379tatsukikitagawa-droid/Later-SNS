#if DEBUG
import AVKit
import PhotosUI
import SwiftUI
import UIKit

/// v107 DEBUG:焼いた 写真 ・ 動画の 記録と 見くらべ。リリースには 出ない。
/// 元の 写真(長辺 1440 に 縮めた もの)と 焼いた ファイルを Caches/DebugFilm に 最後の 10枚 / 1本 だけ のこす。
nonisolated enum DebugFilm {
    struct Photo: Codable, Identifiable, Sendable {
        var id = UUID().uuidString
        var date = Date()
        var ms: Double
        var peakMB: Double
        var bytes: Int
        var original: String
        var baked: String
    }
    struct Video: Codable, Sendable {
        var date = Date()
        var seconds: Double
        var clipSeconds: Double
        var peakMB: Double
        var bytes: Int
        var original: String
        var baked: String
    }
    struct Index: Codable, Sendable { var photos: [Photo] = []; var video: Video? }

    private static let lock = NSLock()

    static var folder: URL {
        let u = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("DebugFilm", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    private static var indexURL: URL { folder.appendingPathComponent("index.json") }

    static func load() -> Index {
        lock.lock(); defer { lock.unlock() }
        return (try? Data(contentsOf: indexURL)).flatMap { try? JSONDecoder().decode(Index.self, from: $0) } ?? Index()
    }
    private static func mutate(_ f: (inout Index) -> Void) {
        lock.lock(); defer { lock.unlock() }
        var i = (try? Data(contentsOf: indexURL)).flatMap { try? JSONDecoder().decode(Index.self, from: $0) } ?? Index()
        f(&i)
        try? JSONEncoder().encode(i).write(to: indexURL)
    }

    // MARK: メモリの 山(はかる 間だけ 5ms ごとに phys_footprint を 見る)
    static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
    }

    final class Sampler: @unchecked Sendable {
        private let queue = DispatchQueue(label: "debugfilm.sampler", qos: .utility)
        private var timer: DispatchSourceTimer?
        private var peak: Double
        let base: Double
        init() {
            base = DebugFilm.footprintMB(); peak = base
            let t = DispatchSource.makeTimerSource(queue: queue)
            t.schedule(deadline: .now(), repeating: .milliseconds(5))
            t.setEventHandler { [weak self] in guard let s = self else { return }; s.peak = max(s.peak, DebugFilm.footprintMB()) }
            t.resume(); timer = t
        }
        /// 開始から の 山(MB)
        func stop() -> Double {
            timer?.cancel(); timer = nil
            return queue.sync { max(0, max(peak, DebugFilm.footprintMB()) - base) }
        }
    }

    // MARK: 写真
    /// 焼く 処理を はかって 記録。`bake` は 焼いた JPEG を 返す
    static func recordPhoto(sourceData: Data?, image: UIImage?, bake: () -> Data?) -> Data? {
        let sampler = Sampler()
        let t0 = CFAbsoluteTimeGetCurrent()
        let baked = bake()
        let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        let peak = sampler.stop()
        guard let baked else { return nil }
        let id = UUID().uuidString
        guard let orig = originalJPEG(sourceData: sourceData, image: image) else { return baked }
        let o = "\(id)-o.jpg", b = "\(id)-b.jpg"
        try? orig.write(to: folder.appendingPathComponent(o))
        try? baked.write(to: folder.appendingPathComponent(b))
        mutate { i in
            i.photos.insert(Photo(id: id, ms: ms, peakMB: peak, bytes: baked.count, original: o, baked: b), at: 0)
            for old in i.photos.dropFirst(10) { remove(old.original); remove(old.baked) }
            i.photos = Array(i.photos.prefix(10))
        }
        return baked
    }

    private static func originalJPEG(sourceData: Data?, image: UIImage?) -> Data? {
        if let sourceData, let src = CGImageSourceCreateWithData(sourceData as CFData, nil) {
            let o: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 1440]
            if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, o as CFDictionary) { return UIImage(cgImage: cg).jpegData(compressionQuality: 0.9) }
        }
        return image?.jpegData(compressionQuality: 0.9)
    }

    private static func remove(_ name: String) { try? FileManager.default.removeItem(at: folder.appendingPathComponent(name)) }

    // MARK: 動画
    /// 書き出しの 前に 呼ぶ(元の 映像を コピー)。返した 値を `finishVideo` に わたす
    static func beginVideo(raw: URL) -> (sampler: Sampler, copy: String, start: Date) {
        let name = "video-o-\(UUID().uuidString).mov"
        try? FileManager.default.copyItem(at: raw, to: folder.appendingPathComponent(name))
        return (Sampler(), name, Date())
    }

    static func finishVideo(_ token: (sampler: Sampler, copy: String, start: Date), baked: URL, clipSeconds: Double) {
        let seconds = Date().timeIntervalSince(token.start)
        let peak = token.sampler.stop()
        let b = "video-b-\(UUID().uuidString).mp4"
        try? FileManager.default.copyItem(at: baked, to: folder.appendingPathComponent(b))
        let size = (try? FileManager.default.attributesOfItem(atPath: baked.path)[.size] as? Int) ?? 0
        mutate { i in
            if let old = i.video { remove(old.original); remove(old.baked) }
            i.video = Video(seconds: seconds, clipSeconds: clipSeconds, peakMB: peak, bytes: size, original: token.copy, baked: b)
        }
    }

    static func discardVideo(_ token: (sampler: Sampler, copy: String, start: Date)) {
        _ = token.sampler.stop(); remove(token.copy)
    }
}

// MARK: - 画面

/// 状態メニュー >「焼いた 写真 ・ 動画を すぐ 見る」
struct DebugFilmCompareView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var index = DebugFilm.load()
    @State private var pick: PhotosPickerItem?
    @State private var busy = false
    @State private var selected: String?
    @State private var showOriginalFull = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("焼いた 写真 ・ 動画(filmVersion \(FilmLook.version))").font(.headline)
                    PhotosPicker(selection: $pick, matching: .images) {
                        Label(busy ? "焼いて います…" : "写真を えらんで 今 焼く", systemImage: "photo.badge.plus")
                    }
                    if index.photos.isEmpty { Text("まだ 記録が ありません。撮るか、上で えらぶと ここに 出ます。").font(.footnote).foregroundStyle(.secondary) }
                    ForEach(index.photos) { p in photoRow(p) }
                    if let v = index.video { videoRow(v) } else { Text("動画は まだ 記録が ありません。").font(.footnote).foregroundStyle(.secondary) }
                }.padding(16)
            }
            .navigationTitle("焼いた 写真 ・ 動画")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
            .onChange(of: pick) { _, item in Task { await bake(item) } }
        }
    }

    private func img(_ name: String) -> UIImage? { UIImage(contentsOfFile: DebugFilm.folder.appendingPathComponent(name).path) }

    @ViewBuilder private func photoRow(_ p: DebugFilm.Photo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                column("元", img(p.original))
                column("焼いた", img(p.baked))
            }
            Text(String(format: "%@ ・ %.0f ms ・ 山 +%.0f MB ・ %.2f MB", p.date.formatted(date: .omitted, time: .standard), p.ms, p.peakMB, Double(p.bytes) / 1_048_576))
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    private func column(_ title: String, _ image: UIImage?) -> some View {
        VStack(spacing: 4) {
            Group {
                if let image { Image(uiImage: image).resizable().scaledToFit() } else { Color.gray.opacity(0.2).aspectRatio(3.0 / 4.0, contentMode: .fit) }
            }.clipShape(RoundedRectangle(cornerRadius: 6))
            Text(title).font(.caption)
        }.frame(maxWidth: .infinity)
    }

    @ViewBuilder private func videoRow(_ v: DebugFilm.Video) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("動画").font(.headline)
            HStack(alignment: .top, spacing: 8) {
                VStack { LoopPlayer(url: DebugFilm.folder.appendingPathComponent(v.original)).aspectRatio(3.0 / 4.0, contentMode: .fit); Text("元").font(.caption) }
                VStack { LoopPlayer(url: DebugFilm.folder.appendingPathComponent(v.baked)).aspectRatio(3.0 / 4.0, contentMode: .fit); Text("焼いた").font(.caption) }
            }
            Text(String(format: "%.1f 秒の 動画 ・ 書き出し %.1f 秒 ・ %.2f MB", v.clipSeconds, v.seconds, Double(v.bytes) / 1_048_576))
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    @MainActor private func bake(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        busy = true
        let encoded = await Task.detached(priority: .userInitiated) { ShotEncoder.encode(UIImage(), sourceData: data) }.value
        _ = encoded
        index = DebugFilm.load(); busy = false; pick = nil
    }
}

private struct LoopPlayer: View {
    let url: URL
    @State private var player = AVQueuePlayer()
    @State private var looper: AVPlayerLooper?
    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                if looper == nil { looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url)) }
                player.isMuted = true; player.play()
            }
            .onDisappear { player.pause() }
    }
}

/// 状態メニュー >「質感の 数字」
struct DebugFilmMetricsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var index = DebugFilm.load()

    private var report: String {
        var l = ["写真(新しい 順)ms / 山MB / MB"]
        for p in index.photos { l.append(String(format: "%.0f / %.0f / %.2f", p.ms, p.peakMB, Double(p.bytes) / 1_048_576)) }
        if let v = index.video { l.append(String(format: "動画 %.1fs の 書き出し %.1f 秒 / 山 %.0f MB / %.2f MB", v.clipSeconds, v.seconds, v.peakMB, Double(v.bytes) / 1_048_576)) }
        return l.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            List {
                Section("さいごの 写真(最大 10)") {
                    row("時刻", "焼く(ms)", "山(MB)", "大きさ(MB)", header: true)
                    ForEach(index.photos) { p in
                        row(p.date.formatted(date: .omitted, time: .standard), String(format: "%.0f", p.ms), String(format: "+%.0f", p.peakMB), String(format: "%.2f", Double(p.bytes) / 1_048_576))
                    }
                    if index.photos.isEmpty { Text("記録なし").foregroundStyle(.secondary) }
                    if !index.photos.isEmpty {
                        let ms = index.photos.map(\.ms)
                        row("平均 / 最大", String(format: "%.0f / %.0f", ms.reduce(0, +) / Double(ms.count), ms.max() ?? 0), String(format: "+%.0f", index.photos.map(\.peakMB).max() ?? 0), "", header: true)
                    }
                }
                Section("さいごの 動画") {
                    if let v = index.video {
                        row("動画の 長さ", String(format: "%.1f 秒", v.clipSeconds), "", "")
                        row("書き出し 時間", String(format: "%.1f 秒", v.seconds), "", "")
                        row("メモリの 山", String(format: "+%.0f MB", v.peakMB), "", "")
                        row("大きさ", String(format: "%.2f MB", Double(v.bytes) / 1_048_576), "", "")
                    } else { Text("記録なし").foregroundStyle(.secondary) }
                }
                Section {
                    Button("数字を コピー") { UIPasteboard.general.string = report }
                    Button("記録を 消す", role: .destructive) { try? FileManager.default.removeItem(at: DebugFilm.folder); index = DebugFilm.load() }
                }
            }
            .navigationTitle("質感の 数字")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
            .onAppear { index = DebugFilm.load() }
        }
    }

    private func row(_ a: String, _ b: String, _ c: String, _ d: String, header: Bool = false) -> some View {
        HStack {
            Text(a).frame(maxWidth: .infinity, alignment: .leading)
            Text(b).frame(width: 80, alignment: .trailing)
            Text(c).frame(width: 60, alignment: .trailing)
            Text(d).frame(width: 70, alignment: .trailing)
        }.font(.system(size: 12, weight: header ? .semibold : .regular, design: .monospaced))
    }
}
#endif
