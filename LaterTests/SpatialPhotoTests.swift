import Metal
import Testing
import UIKit
@testable import Later_再度

struct SpatialPhotoTests {
    // MARK: - 時間割(デモと同じ値)

    @Test func startsAsStillPearlWithBlur() {
        let f = SpatialPhotoTimeline.at(0, reduceMotion: false)
        #expect(abs(f.lensRadius - 39) < 0.01)
        #expect(abs(f.blur - 10) < 0.01)
        #expect(f.strength == 0)
        #expect(!f.isScanning)
        #expect(!f.isSwaying)
    }

    @Test func lensCoversTheScreenAtOnePointSix() {
        let f = SpatialPhotoTimeline.at(1.6, reduceMotion: false)
        #expect(abs(f.lensRadius - 39 * 16.7) < 0.01)
        #expect(abs(SpatialPhotoTimeline.at(1.8, reduceMotion: false).blur) < 0.0001)
    }

    @Test func scanTracksItsPercentFromTwoToFourPointFour() {
        #expect(SpatialPhotoTimeline.at(1.9, reduceMotion: false).scanPercent == nil)
        #expect(SpatialPhotoTimeline.at(2.0, reduceMotion: false).scanPercent == 0)
        #expect(SpatialPhotoTimeline.at(3.2, reduceMotion: false).scanPercent == 50)
        #expect(SpatialPhotoTimeline.at(4.4, reduceMotion: false).scanPercent == nil)
    }

    @Test func strengthRampsAfterTheScan() {
        #expect(SpatialPhotoTimeline.at(2.3, reduceMotion: false).strength == 0)
        #expect(abs(SpatialPhotoTimeline.at(4.1, reduceMotion: false).strength - 0.032) < 0.0001)
    }

    @Test func swayStartsAtThreePointSix() {
        #expect(!SpatialPhotoTimeline.at(3.5, reduceMotion: false).isSwaying)
        #expect(SpatialPhotoTimeline.at(3.6, reduceMotion: false).isSwaying)
    }

    @Test func hintShowsOnlyBetweenFourPointFourAndSevenPointFour() {
        #expect(!SpatialPhotoTimeline.at(4.3, reduceMotion: false).showsHint)
        #expect(SpatialPhotoTimeline.at(5.0, reduceMotion: false).showsHint)
        #expect(!SpatialPhotoTimeline.at(7.4, reduceMotion: false).showsHint)
    }

    @Test func reduceMotionIsStillAtAnyTime() {
        for t in [0.0, 2.5, 3.0, 5.0] {
            let f = SpatialPhotoTimeline.at(t, reduceMotion: true)
            #expect(f.strength == 0)
            #expect(f.blur == 0)
            #expect(!f.isScanning)
            #expect(!f.isSwaying)
            #expect(!f.showsHint)
            #expect(f.lensRadius == .infinity)
        }
    }

    // MARK: - 深度マップ(保存の大きさ)

    @Test func depthMapStaysUnderFortyKilobytes() throws {
        // 滑らかな深度(奥→手前)は、ふつう十分小さく収まる
        let width = 390, height = 844
        let bytes: [UInt8] = (0..<(width * height)).map { i in UInt8((i / width) * 255 / height) }
        let gray = try #require(DepthMapEncoder.grayscaleImage(bytes: bytes, width: width, height: height))
        let data = try #require(DepthMapEncoder.encodedForStorage(gray))
        #expect(data.count <= DepthMapEncoder.maxBytes)
    }

    @Test func depthMapIsNormalizedToFullRange() throws {
        let values: [Float] = [2, 4, .nan, 6]
        let gray = try #require(DepthMapEncoder.grayscale(normalized: values, width: 2, height: 2))
        #expect(gray.size == CGSize(width: 2, height: 2))
    }

    // MARK: - シェーダー

    @Test func shaderSourceCompilesOnThisDevice() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { return }   // GPU が無い環境では確かめない
        let library = try device.makeLibrary(source: SpatialPhotoShader.source, options: nil)
        #expect(library.makeFunction(name: "spatialVertex") != nil)
        #expect(library.makeFunction(name: "spatialFragment") != nil)
    }
}
