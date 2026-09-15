import SwiftUI

/// 「現像中」画面。自分が今日撮影した写真を1枚ずつ、撮影からの経過時間に応じて
/// FilmEmulation(トーンカーブ/彩度・コントラスト/ハレーション/グレイン/周辺減光/
/// 現像ムラ)の効き具合を段階的に強めていくことで、実際のインスタントフィルムが
/// 化学反応で徐々に発色していく質感を再現する(単純な黒オーバーレイのフェードは廃止)。
/// ロジック(状態判定・保存・アンロック)は一切持たず、渡された写真配列をどう
/// 見せるかだけを担当する。
struct DevelopingProgressView: View {
    let photos: [LaterPhoto]

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let now = context.date

            VStack(spacing: 0) {
                header

                developingLine

                if photos.isEmpty {
                    Spacer()
                    Text("今日撮影した写真がありません")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                } else {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                            photoCard(photo: photo, now: now)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    pageIndicator
                }
            }
        }
        .background(Color.brandBlack.ignoresSafeArea())
    }

    // MARK: - ヘッダー

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }

            Spacer()

            Text("現像の進み具合")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var developingLine: some View {
        Text("時間が経つほど、本当の色に近づいていく")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
            .padding(.top, 14)
            .padding(.bottom, 10)
    }

    // MARK: - 写真カード

    private func photoCard(photo: LaterPhoto, now: Date) -> some View {
        let progress = Self.developProgress(photo: photo, now: now)

        return VStack(spacing: 14) {
            ZStack {
                if photo.imageData.isEmpty {
                    Color.white.opacity(0.05)
                } else {
                    // 単純な黒オーバーレイのアルファフェードは廃止し、FilmEmulationの
                    // 段階的パラメータ補間だけで「現像されていく」質感変化を表現する。
                    DevelopingPreviewImage(photo: photo, progress: progress)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 24)
            .frame(maxHeight: .infinity)

            if let caption = photo.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            progressBar(progress: progress)
                .padding(.horizontal, 32)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func progressBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.36, green: 0.20, blue: 0.09),
                                Color(red: 1.0, green: 0.541, blue: 0.239)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress)
                    .animation(.linear(duration: 1.0), value: progress)
            }
        }
        .frame(height: 6)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<photos.count, id: \.self) { index in
                Circle()
                    .fill(currentIndex == index ? Color.brandGreen : Color.white.opacity(0.25))
                    .frame(width: 6, height: 6)
                    .animation(.spring(response: 0.3), value: currentIndex)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    // MARK: - 進捗計算

    /// 現像が視覚的に「ほぼ本当の色」に見えるまでの目安時間。時間帯制限の撤廃により
    /// グループの解禁時刻(未来の一時点)を基準にできなくなったため、実際のインスタント
    /// フィルムと同じく「撮影からの経過時間」だけを基準にする(グループ全体がいつ
    /// 解禁されるかとは無関係に、1枚ごとの現像が進んでいく)。
    private static let developingHorizon: TimeInterval = 3600

    /// 撮影からの経過時間に応じた現像進捗(0〜1)。1に近づくほど「本当の色」に近い。
    /// 経過時間がdevelopingHorizonを超えても1で頭打ちになるだけで、写真自体が
    /// 実際に閲覧できるかどうか(isUnlocked)とは別軸の演出。
    private static func developProgress(photo: LaterPhoto, now: Date) -> Double {
        let elapsed = now.timeIntervalSince(photo.captureDate)
        let linearProgress = min(1, max(0, elapsed / developingHorizon))
        return PhotoUnlockUtilities.applyEasing(progress: linearProgress, easingType: .easeIn)
    }
}

/// progress(0〜1、developProgress済みのeased値)に応じてFilmEmulationを段階的に
/// 適用した画像を表示する。DevelopingProgressView.photoCard専用。
///
/// パフォーマンス対策として、progressを2%刻みに量子化してからキャッシュキーに使う。
/// TimelineViewは1秒ごとに再描画されるが、量子化後の値が変わらない間は
/// .task(id:)が再実行されない(=同じキーのままなのでSwiftUIが新しいTaskを
/// 起動しない)ため、実際にFilmEmulationを再計算するのは量子化の刻みが
/// 変わった時だけになる。前回の描画結果はimageに残り続けるため、再計算中も
/// 黒画面へ戻ったりチラつくことはない。
private struct DevelopingPreviewImage: View {
    let photo: LaterPhoto
    let progress: Double

    /// 2%刻み(50段階)に量子化する。
    private static let steps: Double = 50

    @State private var image: UIImage?

    private var quantizedProgress: Double {
        (min(1, max(0, progress)) * Self.steps).rounded() / Self.steps
    }

    /// アプリ再起動をまたぐ必要が無い(現像は数時間で終わり、二度と同じ進捗には
    /// ならない)ため、写真ID+バイト数+量子化した進捗だけで一意になればよい。
    private var cacheKey: String {
        "\(photo.id.uuidString)_\(photo.imageData.count)_\(Int(quantizedProgress * Self.steps))"
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                // 最初の1回、まだ何も加工結果が無い間だけのプレースホルダー。
                // 排出直後の「ほぼ真っ白〜グレー」なチェキに寄せて黒背景のみにする。
                Color.black
            }
        }
        .task(id: cacheKey) {
            guard !photo.imageData.isEmpty else {
                image = nil
                return
            }
            if let cached = DevelopingPreviewCache.cachedImage(forKey: cacheKey) {
                image = cached
                return
            }
            let configuration = FilmEmulation.developingConfiguration(progress: quantizedProgress)
            let seed = FilmEmulation.seed(for: photo.imageData)
            let result = await DevelopingPreviewCache.image(
                data: photo.imageData,
                cacheKey: cacheKey,
                configuration: configuration,
                seed: seed
            )
            withAnimation(.easeInOut(duration: 0.6)) {
                image = result
            }
        }
    }
}
