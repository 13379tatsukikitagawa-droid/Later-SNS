import AVFoundation
import SwiftUI
import CoreImage
import Foundation
import Testing
import UIKit
@testable import Later_再度

/// v20 動画・v18.2 撮ったあと の決めごと
struct VideoV20Tests {
    @Test func 動画の数字() {
        #expect(VideoRules.width == 720 && VideoRules.height == 960)
        #expect(VideoRules.bitRate == 3_500_000 && VideoRules.keyFrameInterval == 30)
        #expect(VideoRules.rawWidth == 720 && VideoRules.rawHeight == 960)
        #expect(VideoRules.maxDuration == 10)
        #expect(abs(VideoRules.tickInterval - 10.0 / 24) < 0.0001)
        #expect(!VideoRules.keeps(duration: 0.9))
        #expect(VideoRules.keeps(duration: 1.0))
    }

    @Test func なぞって切りかえ() {
        #expect(VideoShutterRules.swipe(dx: -50, dy: 10) == .video)
        #expect(VideoShutterRules.swipe(dx: 50, dy: -10) == .photo)
        #expect(VideoShutterRules.swipe(dx: -40, dy: 0) == nil)
        #expect(VideoShutterRules.swipe(dx: -80, dy: 45) == nil)
    }

    @Test func 録画の目もりとバイブ() {
        #expect(VideoShutterRules.litTicks(elapsed: 0) == 0)
        #expect(VideoShutterRules.litTicks(elapsed: 0.43) == 1)
        #expect(VideoShutterRules.litTicks(elapsed: 10) == 24)
        #expect(!VideoShutterRules.isWarning(elapsed: 6.9))
        #expect(VideoShutterRules.isWarning(elapsed: 7))
        #expect(VideoShutterRules.reelLevel(elapsed: 3) == 0.14)
        #expect(abs(VideoShutterRules.reelLevel(elapsed: 10) - 0.76) < 0.0001)
        #expect(VideoShutterRules.timerText(3.4) == "● 00:03 / 10")
        #expect(MilkCheki.durationText(8.2) == "0:08")
    }

    @Test func 長押しの目もり() {
        #expect(ShutterRules.litTicks(progress: 0) == 0)
        #expect(ShutterRules.litTicks(progress: 1) == 24)
        // 進み = 時間^1.25(はじめは ゆっくり)
        #expect(ShutterRules.litTicks(progress: 0.5) < 12)
        #expect(ShutterRules.photoHint(stage: 1) == "● ○ ○  もうすこし")
        #expect(ShutterRules.idleHint(mode: .photo, left: 2) == "ながおしで撮る ・ 音量ボタンも ながおし")
        #expect(ShutterRules.idleHint(mode: .video, left: 0) == "今日は、ここまで")
    }

    @Test func 撮ったあとの時間() {
        #expect(ShotTiming.flash == 0.12 && ShotTiming.toCheki == 0.23 && ShotTiming.handOff == 0.78)
        #expect(ShotTiming.flyStart == 1.08 && ShotTiming.flyDuration == 0.6)
        #expect(ShotTiming.chekiSize == CGSize(width: 200, height: 250))
    }

    @Test func バイブ() {
        #expect(Haptics.Tuning.beats(.land).first?.intensity == 0.85)
        #expect(Haptics.Tuning.beats(.projector).count == 4)
        #expect(Haptics.Tuning.beats(.shutter).map(\.time) == [0, 0.07])
        #expect(Haptics.Tuning.beats(.warn).map(\.time) == [0, 0.09])
    }

    // MARK: 録画(合成したフレームで、書き出しまで)

    private static func frame(_ pts: CMTime, hue: CGFloat) -> CMSampleBuffer {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 1080, 1440, kCVPixelFormatType_32BGRA, [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer)
        let pb = buffer!
        let image = CIImage(color: CIColor(color: UIColor(hue: hue, saturation: 0.6, brightness: 0.7, alpha: 1))).cropped(to: CGRect(x: 0, y: 0, width: 1080, height: 1440))
        CIContext().render(image, to: pb)
        var format: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pb, formatDescriptionOut: &format)
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30), presentationTimeStamp: pts, decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: pb, formatDescription: format!, sampleTiming: &timing, sampleBufferOut: &sample)
        return sample!
    }

    private func record(frames: Int) async -> RecordedVideo? {
        let recorder = RetroRecorder()
        recorder.setActive(true)
        recorder.startRecording(audio: false)
        for i in 0..<frames {
            recorder.handleVideo(Self.frame(CMTime(value: CMTimeValue(i), timescale: 30), hue: CGFloat(i % 30) / 30))
        }
        return await withCheckedContinuation { continuation in
            recorder.stopRecording { continuation.resume(returning: $0) }
        }
    }

    /// v21:録画は ふつうの映像(720×960)
    @Test func 録画はふつうの映像() async throws {
        let video = try #require(await record(frames: 45))
        #expect(video.duration >= 1.4 && video.duration <= 1.6)
        #expect(!video.poster.isEmpty)
        #expect(video.velocities.count == 45)
        let tracks = try await AVURLAsset(url: video.url).loadTracks(withMediaType: .video)
        #expect(try await tracks.first!.load(.naturalSize) == CGSize(width: 720, height: 960))
        try? FileManager.default.removeItem(at: video.url)
    }

    /// v21:撮ったあとに 1回だけ RETRO-8(540×720)へ書き出す。10秒の動画の時間を測る(シミュレーターの値は目安)
    @Test func 撮ったあとにレトロを書き出す() async throws {
        let video = try #require(await record(frames: 300))
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("retro-test.mp4")
        let start = Date()
        let result = try await RetroExporter.export(raw: video.url, to: out, velocities: video.velocities, captureDate: Date(), light: false)
        let seconds = Date().timeIntervalSince(start)
        print(String(format: "[RetroExport] 10秒の動画を %.1f秒で書き出し(1コマ %.1fms)", seconds, seconds * 1000 / 300))
        let sz = (try? FileManager.default.attributesOfItem(atPath: out.path)[.size] as? Int) ?? 0
        print("[RetroExport] 書き出しの大きさ \(sz) bytes(\(Double(sz) / 1_048_576) MB)")
        #expect(!result.poster.isEmpty)
        #expect(result.duration > 9.5 && result.duration <= 10.1)
        let tracks = try await AVURLAsset(url: out).loadTracks(withMediaType: .video)
        #expect(try await tracks.first!.load(.naturalSize) == CGSize(width: 720, height: 960))
        try? FileManager.default.removeItem(at: video.url)
        try? FileManager.default.removeItem(at: out)
    }

    @Test func 音のフィルタは低い音を切る() {
        var hp = Biquad.highPass(frequency: 80, sampleRate: 44_100)
        // 20Hz の大きな波は、ほとんど通らない
        var peak: Float = 0
        for i in 0..<44_100 { let y = hp.run(sin(2 * .pi * 20 * Float(i) / 44_100)); if i > 4_000 { peak = max(peak, abs(y)) } }
        #expect(peak < 0.1)
    }

    @Test func 一秒より短いと捨てる() async {
        let video = await record(frames: 20)
        #expect(video == nil)
    }
}

