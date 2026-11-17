import AVFoundation
import CoreImage
import Photos
import UIKit

// v50:Recap を 本物の動画(.mp4・無音)に書き出す。すべて 端末の中だけ(サーバー・外のAPIは使わない)。
// 1コマぶんの絵は UIGraphicsImageRenderer で作り、AVAssetWriter で つなぐ。
// 音は入れない(無音の書き出しで良い。でっちあげの曲は入れない)。

nonisolated enum RecapExporter {
    static let width = 720
    static let height = 1_280
    static let fps: Int32 = 30

    enum ExportError: Error { case writer, libraryDenied }

    static func export(segments: [RecapSegment], style: RecapStyle) async throws -> URL {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("later-recap-\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: output)

        let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 3_200_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel,
                AVVideoExpectedSourceFrameRateKey: fps,
            ],
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ])
        guard writer.canAdd(input) else { throw ExportError.writer }
        writer.add(input)
        guard writer.startWriting() else { throw ExportError.writer }
        writer.startSession(atSourceTime: .zero)

        let ciContext = CIContext()
        var frameIndex: Int64 = 0
        for segment in segments {
            guard let frame = renderFrame(segment, style: style), let ciImage = CIImage(image: frame) else { continue }
            let frameCount = max(1, Int((segment.duration(style: style) * Double(fps)).rounded()))
            for _ in 0..<frameCount {
                while !input.isReadyForMoreMediaData {
                    try await Task.sleep(nanoseconds: 2_000_000)
                }
                guard let pool = adaptor.pixelBufferPool else { continue }
                var buffer: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
                guard let buffer else { continue }
                ciContext.render(ciImage, to: buffer, bounds: CGRect(x: 0, y: 0, width: width, height: height), colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
                adaptor.append(buffer, withPresentationTime: CMTime(value: frameIndex, timescale: fps))
                frameIndex += 1
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw ExportError.writer }
        return output
    }

    /// 書き出した動画を、本人の 写真(カメラロール)に 保存する
    static func saveToPhotoLibrary(url: URL) async throws {
        var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        }
        guard status == .authorized || status == .limited else { throw ExportError.libraryDenied }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
        }
    }

    // MARK: - 1コマの絵

    private static func renderFrame(_ segment: RecapSegment, style: RecapStyle) -> UIImage? {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor(white: 0.04, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            switch segment {
            case .day(let day):
                drawDayCard(day, size: size)
            case .photo(let day, let shot, let image, let kept):
                drawPhotoCard(day: day, shot: shot, image: image, kept: kept, style: style, size: size)
            case .end(let total, let kept, let range, let covers):
                drawEndCard(totalShots: total, keptCount: kept, rangeLabel: range, covers: covers, size: size)
            }
        }
    }

    private static func drawDayCard(_ day: MEDay, size: CGSize) {
        let weekday = MERules.label(ago: day.ago, date: day.date)
        let dot = MERules.dot(day.date)
        centered(weekday, font: .systemFont(ofSize: 34, weight: .heavy), color: .white, y: size.height * 0.44, size: size)
        centered(dot, font: .monospacedSystemFont(ofSize: 18, weight: .bold), color: UIColor(white: 1, alpha: 0.55), y: size.height * 0.44 + 46, size: size)
    }

    private static func drawPhotoCard(day: MEDay, shot: MEShot, image: UIImage, kept: Bool, style: RecapStyle, size: CGSize) {
        let inset: CGFloat = style == .cheki ? 36 : 0
        let photoRect = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2 - (style == .cheki ? 120 : 0))
        if style == .cheki {
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
        }
        drawAspectFill(image, in: photoRect)
        drawBottomShade(in: photoRect)

        let timeText = MERules.dot(day.date) + "  " + shot.takenAt.formatted(date: .omitted, time: .shortened)
        let textColor: UIColor = style == .cheki ? UIColor(white: 0.1, alpha: 1) : .white
        centered(timeText, font: .monospacedSystemFont(ofSize: 14, weight: .bold), color: textColor, y: size.height - (style == .cheki ? 150 : 70), size: size)
        if let tag = day.tags.first {
            centered("#\(tag)", font: .boldSystemFont(ofSize: 15), color: UIColor(red: 1, green: 0.7, blue: 0.48, alpha: 1), y: size.height - (style == .cheki ? 120 : 40), size: size)
        }
        if kept {
            centered("★", font: .systemFont(ofSize: 20), color: UIColor(red: 1, green: 0.84, blue: 0.04, alpha: 1), y: 56, size: size)
        }
    }

    private static func drawEndCard(totalShots: Int, keptCount: Int, rangeLabel: String, covers: [UIImage], size: CGSize) {
        let columns = 3
        let cell = size.width / CGFloat(columns)
        for (index, image) in covers.prefix(6).enumerated() {
            let row = index / columns, col = index % columns
            let rect = CGRect(x: CGFloat(col) * cell, y: size.height * 0.18 + CGFloat(row) * cell, width: cell - 2, height: cell - 2)
            drawAspectFill(image, in: rect)
        }
        drawBottomShade(in: CGRect(x: 0, y: size.height * 0.18, width: size.width, height: cell * 2))
        centered(rangeLabel, font: .monospacedSystemFont(ofSize: 13, weight: .bold), color: UIColor(white: 1, alpha: 0.6), y: size.height * 0.62, size: size)
        centered("That was your week.", font: .systemFont(ofSize: 30, weight: .heavy), color: .white, y: size.height * 0.62 + 40, size: size)
        centered("\(totalShots) shots · 7 days · \(keptCount) kept", font: .monospacedSystemFont(ofSize: 13, weight: .semibold), color: UIColor(white: 1, alpha: 0.7), y: size.height * 0.62 + 90, size: size)
    }

    /// clip は この関数の中だけ(前後で必ず save/restore する。end の 6枚グリッドなど、連続で呼ぶため)
    private static func drawAspectFill(_ image: UIImage, in rect: CGRect) {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0, let context = UIGraphicsGetCurrentContext() else { return }
        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(x: rect.midX - drawSize.width / 2, y: rect.midY - drawSize.height / 2)
        context.saveGState()
        context.clip(to: rect)
        image.draw(in: CGRect(origin: origin, size: drawSize))
        context.restoreGState()
    }

    private static func drawBottomShade(in rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.72).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
        context.saveGState()
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: rect.minY + rect.height * 0.5), end: CGPoint(x: 0, y: rect.maxY), options: [])
        context.restoreGState()
    }

    private static func centered(_ text: String, font: UIFont, color: UIColor, y: CGFloat, size: CGSize) {
        let attributed = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        let textSize = attributed.size()
        attributed.draw(at: CGPoint(x: (size.width - textSize.width) / 2, y: y))
    }
}
