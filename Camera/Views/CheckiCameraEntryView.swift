import SwiftUI
import AVFoundation

/// Later Cameraの入口。「チェキを構える」という一手間・儀式感を持たせるため、
/// 起動直後はチェキ型のカメラ筐体+小さなライブプレビュー窓(状態A)を表示し、
/// その窓をタップして初めてフルスクリーンの実際の撮影画面(状態B、
/// TrueBlindCameraView)へ進む2段階構造にする。
///
/// 状態A・状態Bは同じFilmCameraController(=同じAVCaptureSession)を共有する
/// (小窓とフルスクリーンプレビューが別々にAVCaptureSessionを持つと、カメラの
/// 二重起動でパフォーマンス・バッテリーに悪影響が出るため)。撮影・現像・
/// アップロードのロジックは一切変更せず、TrueBlindCameraViewへそのまま委譲する。
struct CheckiCameraEntryView: View {
    var currentCount: Int
    var limit: Int
    var streakCount: Int
    var onCapture: (Data, String?) -> Void
    var onCaptureVideo: (URL, UIImage?, Double, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = FilmCameraController()
    @State private var isFlashOn = false
    /// 入口(状態A)の小窓は「チェキを構える」所作としてフロントカメラのプレビューから
    /// 始める(仕様)。状態Bへ進んだ後は既存のswitchCameraButtonでいつでも切り替えられる
    /// (同じセッションを共有しているため、ここでの選択がそのまま引き継がれる)。
    @State private var cameraPosition: AVCaptureDevice.Position = .front
    @State private var hasEnteredCapture = false
    @State private var isPulsing = false

    private static let neonGreen = Color.brandGreen

    private var remainingCount: Int { max(0, limit - currentCount) }

    var body: some View {
        Group {
            if hasEnteredCapture {
                TrueBlindCameraView(
                    camera: camera,
                    initialCameraPosition: cameraPosition,
                    isFlashOn: $isFlashOn,
                    currentCount: currentCount,
                    limit: limit,
                    streakCount: streakCount,
                    onCapture: onCapture,
                    onCaptureVideo: onCaptureVideo
                )
                .transition(.opacity.combined(with: .scale(scale: 1.05)))
            } else {
                entranceView
                    .transition(.opacity)
            }
        }
        .onAppear {
            camera.configure()
            camera.setCameraPosition(cameraPosition)
        }
    }

    // MARK: - 状態A: 入口画面

    private var entranceView: some View {
        VStack(spacing: 0) {
            entranceTopBar
                .padding(.horizontal, 20)
                .padding(.top, 56)

            Spacer()

            chekiCasing

            Text("今日の一枚は、まだ現像されていない")
                .font(.custom("Caveat-Bold", size: 22))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.top, 20)

            maskingTapeNote
                .padding(.top, 16)

            Spacer()
            Spacer()
        }
        .background(Color(hex: "17110c").ignoresSafeArea())
        .statusBarHidden()
    }

    private var entranceTopBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.black.opacity(0.35)))
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text("TODAY'S LATER・\(Self.todayLabel())")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                Text(remainingCount > 0 ? "残り\(remainingCount)枚" : "本日分は撮影済み")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    isFlashOn.toggle()
                } label: {
                    Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.black.opacity(0.35)))
                }
                .buttonStyle(.plain)

                Button {
                    cameraPosition = cameraPosition == .back ? .front : .back
                    camera.setCameraPosition(cameraPosition)
                    HapticsManager.tick()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.black.opacity(0.35)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private static func todayLabel() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: Date())
    }

    // MARK: - チェキ型カメラ筐体(状態Aの主役。ピン留め+わずかな回転)

    private var chekiCasing: some View {
        VStack(spacing: 10) {
            smallPreviewWindow

            Text("TAP TO SHOOT")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color(hex: "8a7c6a"))
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: "eee0b8"))
                .shadow(color: .black.opacity(0.4), radius: 14, x: 0, y: 8)
        )
        .overlay(alignment: .top) {
            CorkboardPin(size: 20)
                .offset(y: -12)
        }
        .rotationEffect(.degrees(-3))
    }

    /// 実際のフロントカメラのライブプレビュー(camera.sessionをそのまま使う、
    /// 状態Bと同一のAVCaptureSession)。タップするとhasEnteredCapture=trueになり、
    /// TrueBlindCameraView側のフルスクリーンプレビューへ切り替わる
    /// (同じセッションを使い回すため、プレビューが一瞬でも途切れることはない)。
    private var smallPreviewWindow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.32)) {
                hasEnteredCapture = true
            }
        } label: {
            ZStack {
                CameraPreviewRepresentable(session: camera.session)

                Circle()
                    .fill(Self.neonGreen.opacity(isPulsing ? 0.15 : 0.32))
                    .frame(width: 60, height: 60)
                    .scaleEffect(isPulsing ? 1.25 : 1.0)

                Image(systemName: "camera.aperture")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4)
            }
            .frame(width: 150, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.15), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        // アクセシビリティ: タップ可能領域を44x44pt以上に(実サイズは150x150で既に十分だが、
        // 仕様の明示要求に合わせて最低保証を明記する)。
        .frame(minWidth: 44, minHeight: 44)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private var maskingTapeNote: some View {
        Text("撮った瞬間は見えません。現像されるまで、待とう")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.corkboardCTAText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.corkboardCard)
                    .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 3)
            )
            .rotationEffect(.degrees(2))
    }
}
