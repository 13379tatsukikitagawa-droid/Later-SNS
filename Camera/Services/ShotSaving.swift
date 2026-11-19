// ShotSaving.swift
// 撮った1枚を「画面を待たせずに」保存するための部品(v11 7章)。
// - CapturedShot:カメラから返った写真(保存用の元画像と、画面用の小さく・先にデコードした画像)
// - ShotEncoder:重い処理(JPEG・縮小・色・サムネイル)を、メインの外で、写真が返った時点から始めておく
// - PendingShotStore:保存が終わるまで、端末のファイルに写真をおいておく。失敗・アプリ終了のときは、次の起動で再試行
//
// 画面は、送信(CloudKit)を待たない。端末への保存(SwiftData)だけを先に行う。

import Foundation
import ImageIO
import UIKit

// MARK: - カメラから返った1枚

nonisolated struct CapturedShot: @unchecked Sendable {
    /// 保存に使う元の画像
    let full: UIImage
    /// 画面用(縦3:4に切りとり・長辺 1200px・デコード済み)。凍結した絵と、切りとり・向き・比率を同じにする
    let display: UIImage
    /// カメラが返したファイルのデータ(あれば、保存のときに再エンコードしない)
    let sourceData: Data?

    /// 画面の写真の比率(幅 / 高さ)。凍結した絵も、これに切りそろえる
    static let displayAspect: CGFloat = 3.0 / 4.0
    static let displayMaxPixel: CGFloat = 1200

    /// カメラのデータから作る(メインの外で呼ぶ)
    static func make(from data: Data) -> CapturedShot? {
        guard let full = UIImage(data: data) else { return nil }
        let display = displayImage(fromData: data) ?? full
        return CapturedShot(full: full, display: display, sourceData: data)
    }

    /// 画面用:縮めて(向きも直して)から、中央を 3:4 に切りそろえ、先にデコードする
    static func displayImage(fromData data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(displayMaxPixel * 1.34),
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let cropped = cropToAspect(thumb, aspect: displayAspect) ?? thumb
        let image = UIImage(cgImage: cropped)
        return image.preparingForDisplay() ?? image
    }

    /// 中央を aspect(幅/高さ)に切りとる
    static func cropToAspect(_ image: CGImage, aspect: CGFloat) -> CGImage? {
        let rect = centeredCropRect(width: CGFloat(image.width), height: CGFloat(image.height), aspect: aspect)
        return image.cropping(to: rect.integral)
    }

    static func centeredCropRect(width: CGFloat, height: CGFloat, aspect: CGFloat) -> CGRect {
        guard width > 0, height > 0, aspect > 0 else { return CGRect(x: 0, y: 0, width: width, height: height) }
        if width / height > aspect {
            let w = height * aspect
            return CGRect(x: (width - w) / 2, y: 0, width: w, height: height)
        } else {
            let h = width / aspect
            return CGRect(x: 0, y: (height - h) / 2, width: width, height: h)
        }
    }
}

// MARK: - 保存の前の、重い処理

/// SwiftData に入れる直前までに作っておくもの
nonisolated struct EncodedShot: Sendable {
    /// LaterPhoto.imageData(長辺 1600px・JPEG 0.8。CapturedImageCompressor と同じ決め)
    let imageData: Data
    /// 「預けた日々」の記録(ExposureDay)に使う値
    let colorHex: String?
    let thumbnailData: Data?
    let toneHexes: [String]
    /// v107:撮った 時に 焼いた しるし(2)。焼けなかった 時は nil
    var filmVersion: Int? = nil
}

nonisolated enum ShotEncoder {
    static let maxDimension: CGFloat = 1600

    private static let lock = NSLock()
    nonisolated(unsafe) private static var tasks: [ObjectIdentifier: Task<EncodedShot?, Never>] = [:]

    /// 写真が返った時点で呼ぶ(待たない)。あとで encoded(for:) が同じ結果を受けとる
    @discardableResult
    static func prepare(_ image: UIImage, sourceData: Data? = nil) -> Task<EncodedShot?, Never> {
        let key = ObjectIdentifier(image)
        lock.lock(); defer { lock.unlock() }
        if let task = tasks[key] { return task }
        // 受けとられなかった古い準備は捨てる(写真を持ちつづけない)
        if tasks.count >= 3 { tasks.removeAll() }
        let box = UncheckedImage(image: image)
        let task = Task.detached(priority: .userInitiated) { () -> EncodedShot? in
            encode(box.image, sourceData: sourceData)
        }
        tasks[key] = task
        return task
    }

    /// 保存の直前に呼ぶ。準備が終わっていれば、すぐ返る
    static func encoded(for image: UIImage) async -> EncodedShot? {
        let task = prepare(image)
        let result = await task.value
        forget(ObjectIdentifier(image))
        return result
    }

    private static func forget(_ key: ObjectIdentifier) {
        lock.lock(); tasks[key] = nil; lock.unlock()
    }

    /// メインの外で呼ぶ
    static func encode(_ image: UIImage, sourceData: Data?) -> EncodedShot? {
        // v107:撮った 時に 1回 だけ チェキを 焼く(1440px ・ EXIF なし)。以降は この ファイルだけ を 保存 ・ 送る。
        // ぼかし(ロック ・ ウィジェット)も この 焼いた ファイルから 作る。焼けなかった 時だけ 従来の 形(filmVersion なし)
        var data: Data?
        var film: Int?
        if let sourceData, let baked = FilmLook.shared.chekiJPEG(from: sourceData, seed: FilmLook.seed(for: sourceData)) {
            data = baked; film = FilmLook.version
        } else if let baked = FilmLook.shared.chekiJPEG(from: image, seed: FilmLook.seed(for: image.pngData()?.prefix(4096) ?? Data())) {
            data = baked; film = FilmLook.version
        } else if let sourceData, let resized = resizedJPEG(fromData: sourceData) {
            data = resized
        } else {
            data = resizedJPEG(from: image)
        }
        guard let imageData = data else { return nil }
        let extras = dayExtras(from: imageData)
        return EncodedShot(imageData: imageData, colorHex: extras.colorHex, thumbnailData: extras.thumbnailData, toneHexes: extras.toneHexes, filmVersion: film)
    }

    /// 端末に残っていた写真(再試行)からも、同じ値を作る
    static func dayExtras(from imageData: Data) -> (colorHex: String?, thumbnailData: Data?, toneHexes: [String]) {
        guard let image = UIImage(data: imageData)?.preparingForDisplay() else { return (nil, nil, []) }
        // サムネイルは元のデータから作る(向きを落とさない)
        let thumbnail = PhotoColor.thumbnailData(fromData: imageData) ?? PhotoColor.thumbnailData(of: image)
        return (PhotoColor.centerColorHex(of: image), thumbnail, PhotoColor.toneHexes(of: image))
    }

    private static func resizedJPEG(fromData data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension),
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: 0.8)
    }

    private static func resizedJPEG(from image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }

    private struct UncheckedImage: @unchecked Sendable { let image: UIImage }
}

// MARK: - 保存が終わるまで、ファイルにおいておく

nonisolated enum PendingShotStore {
    struct Meta: Codable, Sendable {
        let id: UUID
        let captureDate: Date
        let tags: [String]
        let place: String?
        /// v22 L-4:撮ったときの 1曲(古い保存には ない)
        var music: MusicPick? = nil
        /// v107:焼いた しるし(古い 保存には ない)
        var filmVersion: Int? = nil
    }

    struct Item: Sendable {
        let meta: Meta
        let imageData: Data
    }

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("PendingShots", isDirectory: true)
    }

    /// 書いておく(メインの外で)。書けなかったときは nil
    static func write(imageData: Data, meta: Meta) -> Bool {
        let dir = directory
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try imageData.write(to: dir.appendingPathComponent("\(meta.id.uuidString).jpg"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            let json = try JSONEncoder().encode(meta)
            try json.write(to: dir.appendingPathComponent("\(meta.id.uuidString).json"), options: [.atomic])
            return true
        } catch {
            print("[PendingShot] 一時保存に失敗: \(error)")
            return false
        }
    }

    static func remove(_ id: UUID) {
        let dir = directory
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(id.uuidString).jpg"))
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(id.uuidString).json"))
    }

    /// 残っているもの(古い順)。こわれたものは消す
    static func loadAll() -> [Item] {
        let dir = directory
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return [] }
        var items: [Item] = []
        for name in names where name.hasSuffix(".json") {
            let jsonURL = dir.appendingPathComponent(name)
            guard let json = try? Data(contentsOf: jsonURL),
                  let meta = try? JSONDecoder().decode(Meta.self, from: json),
                  let data = try? Data(contentsOf: dir.appendingPathComponent("\(meta.id.uuidString).jpg")) else {
                try? FileManager.default.removeItem(at: jsonURL)
                continue
            }
            items.append(Item(meta: meta, imageData: data))
        }
        return items.sorted { $0.meta.captureDate < $1.meta.captureDate }
    }
}

// MARK: - 背面に行っても、保存を最後まで

/// 保存の途中でアプリが背面に行っても、終わるまで少し時間をもらう
@MainActor
final class BackgroundTaskBox {
    private var id: UIBackgroundTaskIdentifier = .invalid

    static func begin(name: String) -> BackgroundTaskBox {
        let box = BackgroundTaskBox()
        box.id = UIApplication.shared.beginBackgroundTask(withName: name) { [weak box] in
            MainActor.assumeIsolated { box?.end() }
        }
        return box
    }

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}
