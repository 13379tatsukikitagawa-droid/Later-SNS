import Foundation
import SwiftData
import UIKit
import CoreMotion

/// 「預けた日々」の1日分の記録(1日1枚 = 1点)。端末内だけに保存し、CloudKitへは同期しない。
///
/// 写真そのもの(LaterPhoto)は容量のため7日で削除される(LaterApp.pruneExpiredPhotos)が、
/// 点は全期間残したいので、日付・写真の中心の色・市区町村・小さなサムネイルだけをここに残す。
/// 色とサムネイルは撮った時に1度だけ計算し、画面では再計算しない。
@Model
final class ExposureDay {
    /// 「yyyy-MM-dd」(端末のローカル日付)。1日1件。
    @Attribute(.unique) var dayKey: String
    /// その日の1枚の撮影時刻
    var captureDate: Date
    /// 写真の中心の色(彩度・明るさを調整済み)。「RRGGBB」
    var colorHex: String?
    /// 市区町村まで(座標・番地は持たない)
    var locationName: String?
    /// カード用の小さなサムネイル(JPEG)。ひらいている日だけ画面に出す。
    @Attribute(.externalStorage) var thumbnailData: Data?
    /// 写真の主要な3色(「RRGGBB」)。Homeの現像カードと「あなたの1点」に、写真の代わりに出す。
    /// 端末内だけに持ち、写真のレコード(CloudKit)には入れない(他人に届けない)。
    var toneHexes: [String] = []

    init(dayKey: String, captureDate: Date) {
        self.dayKey = dayKey
        self.captureDate = captureDate
    }
}

// MARK: - 記録の作成

@MainActor
enum ExposureDayStore {
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// 撮った1枚から、その日の記録を作る(すでにあれば何もしない)。
    static func record(imageData: Data, captureDate: Date, locationName: String?, context: ModelContext) {
        let key = dayKey(for: captureDate)
        let descriptor = FetchDescriptor<ExposureDay>(predicate: #Predicate { $0.dayKey == key })
        guard (try? context.fetch(descriptor).first) == nil else { return }
        let day = ExposureDay(dayKey: key, captureDate: captureDate)
        day.locationName = locationName
        if let image = UIImage(data: imageData) {
            day.colorHex = PhotoColor.centerColorHex(of: image)
            day.thumbnailData = PhotoColor.thumbnailData(of: image)
            day.toneHexes = PhotoColor.toneHexes(of: image)
        }
        context.insert(day)
        try? context.save()
    }

    /// この仕組みより前に撮った自分の写真(まだ端末に残っている7日分)からも記録を作る。
    /// 写真が削除される前(起動時)に呼ぶ。
    static func backfill(for user: UserProfile, context: ModelContext) {
        let days = (try? context.fetch(FetchDescriptor<ExposureDay>())) ?? []
        // 3色を持つ前に作られた記録には、写真が端末に残っていれば3色を足す。
        for day in days where day.toneHexes.isEmpty {
            if let photo = user.photos.first(where: { dayKey(for: $0.captureDate) == day.dayKey }),
               let image = UIImage(data: photo.imageData) {
                day.toneHexes = PhotoColor.toneHexes(of: image)
            }
        }
        let existing = Set(days.map(\.dayKey))
        var seen = existing
        for photo in user.photos.sorted(by: { $0.captureDate < $1.captureDate }) {
            let key = dayKey(for: photo.captureDate)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            record(imageData: photo.imageData, captureDate: photo.captureDate, locationName: photo.locationName, context: context)
        }
    }
}

// MARK: - 写真の色

nonisolated enum PhotoColor {
    /// 写真の中心部分を小さく縮めて平均色を取り、暗すぎる・明るすぎる・くすんだ色を避けるよう
    /// 彩度と明るさを整える。
    static func centerColorHex(of image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width, height = cgImage.height
        let crop = CGRect(x: width / 4, y: height / 4, width: max(1, width / 2), height: max(1, height / 2))
        guard let center = cgImage.cropping(to: crop) else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(center, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        let average = UIColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255, alpha: 1)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        average.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let adjusted = UIColor(
            hue: hue,
            saturation: min(0.85, max(0.35, saturation * 1.35)),
            brightness: min(0.92, max(0.62, brightness * 1.15)),
            alpha: 1
        )
        return hex(of: adjusted)
    }

    /// 写真を16×16に縮め、色を中央値分割で3つに分けた主要な3色。暗すぎる・くすんだ色は整える。
    /// 色が取れない時は空(呼び出し側が既定の3色を使う)。
    static func toneHexes(of image: UIImage) -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let side = 16
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(
            data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var colors: [(r: Double, g: Double, b: Double)] = []
        for index in stride(from: 0, to: pixels.count, by: 4) {
            colors.append((Double(pixels[index]) / 255, Double(pixels[index + 1]) / 255, Double(pixels[index + 2]) / 255))
        }
        // 中央値分割:いちばん幅の広い色の軸で、箱を2つに割ることを3箱になるまでくり返す。
        var boxes = [colors]
        while boxes.count < 3 {
            guard let widestIndex = boxes.indices.max(by: { spread(boxes[$0]) < spread(boxes[$1]) }),
                  boxes[widestIndex].count > 1 else { break }
            let box = boxes.remove(at: widestIndex)
            let axis = widestAxis(box)
            let sorted = box.sorted { component($0, axis) < component($1, axis) }
            let middle = sorted.count / 2
            boxes.append(Array(sorted[..<middle]))
            boxes.append(Array(sorted[middle...]))
        }
        return boxes
            .sorted { $0.count > $1.count }
            .map { box -> String in
                let count = Double(max(1, box.count))
                let average = UIColor(
                    red: box.reduce(0) { $0 + $1.r } / count,
                    green: box.reduce(0) { $0 + $1.g } / count,
                    blue: box.reduce(0) { $0 + $1.b } / count,
                    alpha: 1
                )
                var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
                average.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
                let adjusted = UIColor(
                    hue: hue,
                    saturation: min(0.9, max(0.35, saturation * 1.4)),
                    brightness: min(0.95, max(0.6, brightness * 1.2)),
                    alpha: 1
                )
                return hex(of: adjusted)
            }
    }

    private static func component(_ color: (r: Double, g: Double, b: Double), _ axis: Int) -> Double {
        axis == 0 ? color.r : axis == 1 ? color.g : color.b
    }

    private static func widestAxis(_ box: [(r: Double, g: Double, b: Double)]) -> Int {
        let ranges = (0..<3).map { axis -> Double in
            let values = box.map { component($0, axis) }
            return (values.max() ?? 0) - (values.min() ?? 0)
        }
        return ranges.indices.max { ranges[$0] < ranges[$1] } ?? 0
    }

    private static func spread(_ box: [(r: Double, g: Double, b: Double)]) -> Double {
        guard box.count > 1 else { return 0 }
        let axis = widestAxis(box)
        let values = box.map { component($0, axis) }
        return (values.max() ?? 0) - (values.min() ?? 0)
    }

    /// カード用の小さなサムネイル(長辺320px)。
    static func thumbnailData(of image: UIImage, maxDimension: CGFloat = 320) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / max(1, longest))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }

    private static func hex(of color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - 傾き(ガラス玉の光)

/// 端末の傾きを取り、ローパスフィルターで滑らかにした値(-1〜1)を出す。
/// 画面が見えている間だけ動かす。モーションが使えない端末・シミュレーターでは0のまま。
@MainActor
@Observable
final class GlassTilt {
    private(set) var x: Double = 0
    private(set) var y: Double = 0

    @ObservationIgnored private let manager = CMMotionManager()
    /// ローパスフィルターの係数(小さいほど滑らか)
    @ObservationIgnored private let smoothing = 0.12

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 45.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let gravity = motion?.gravity else { return }
            // 端末を手に持った普通の角度(やや手前に傾けた状態)を中心にする。
            let targetX = max(-1, min(1, gravity.x * 2))
            let targetY = max(-1, min(1, (gravity.y + 0.6) * 2))
            x += (targetX - x) * smoothing
            y += (targetY - y) * smoothing
        }
    }

    func stop() {
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
    }
}
