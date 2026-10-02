import SwiftUI
import AVFoundation

/// Later Cameraの入口。以前は「チェキを構える」演出として、起動直後にチェキ型の
/// カメラ筐体+小さなライブプレビュー窓(状態A)を挟み、そこをタップして初めて
/// フルスクリーンの撮影画面(状態B、TrueBlindCameraView)へ進む2段階構造だったが、
/// 撮影までの手間を減らすため状態Aは廃止し、常に直接TrueBlindCameraViewを表示する。
struct CheckiCameraEntryView: View {
    var currentCount: Int
    var limit: Int
    /// 撮影前のキャプション入力画面(CaptionEntryView)で入力された文字列。
    /// TrueBlindCameraViewのファインダー上にバッジ表示する。
    var caption: String = ""
    var onCapture: (Data, String?) -> Void
    var onCaptureVideo: (URL, UIImage?, Double, String?) -> Void

    @StateObject private var camera = FilmCameraController()
    @State private var isFlashOn = false
    @State private var cameraPosition: AVCaptureDevice.Position = .front

    var body: some View {
        TrueBlindCameraView(
            camera: camera,
            initialCameraPosition: cameraPosition,
            isFlashOn: $isFlashOn,
            currentCount: currentCount,
            limit: limit,
            caption: caption,
            onCapture: onCapture,
            onCaptureVideo: onCaptureVideo
        )
        .onAppear {
            camera.configure()
            camera.setCameraPosition(cameraPosition)
        }
    }
}
