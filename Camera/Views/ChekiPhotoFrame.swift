import SwiftUI
import CoreImage.CIFilterBuiltins

/// 写真を「チェキ(インスタントフィルム)」風に見せる共通コンポーネント。
/// ロジック(取得・フィルタ・保存)は一切持たず、渡された写真をどう見せるかだけを担当する。
/// - `ChekiPhotoFrame`: 単体表示(白フチ+日付印字+光のにじみ+グレイン)
/// - `ChekiPhotoStack`: 自分の写真を最大5枚まで重ね置き表示し、タップで開ける

private let chekiFrameColor = Color(red: 0.969, green: 0.961, blue: 0.933) // #f7f5ee

// MARK: - 単体表示

struct ChekiPhotoFrame: View {
    let photo: LaterPhoto
    var rotation: Double = 0
    var shadowRadius: CGFloat = 10
    var shadowOpacity: Double = 0.35

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "''yy.M.d"
        return formatter.string(from: photo.captureDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            photoArea
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .padding(7)

            HStack(spacing: 3) {
                if let locationName = photo.locationName, !locationName.isEmpty {
                    Image(systemName: "mappin")
                        .font(.system(size: 8, weight: .regular))
                    Text(locationName)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 4)

                Text(dateString)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .fixedSize()
            }
            .foregroundStyle(Color.black.opacity(0.35))
            .padding(.horizontal, 9)
            .frame(height: 22)
        }
        .background(chekiFrameColor)
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowRadius * 0.4)
        .rotationEffect(.degrees(rotation))
    }

    /// アプリ再起動をまたいでも変わらない、写真ごとに安定したキャッシュキー。
    /// imageDataのバイト数を含めているのは、「現像中(空データ)→解禁後(実データ)」の
    /// ように同じ写真でも中身が変わるケースで、古い加工結果を掴み続けないようにするため。
    private var chekiCacheKey: String {
        "\(photo.id.uuidString)_\(photo.imageData.count)"
    }

    private var photoArea: some View {
        ZStack {
            if photo.isUnlocked {
                // 解禁済みの写真は、解禁確定の瞬間(CloudKitManager.evaluateGroupUnlockConditions
                // →ChekiColorGrade.bakeIntoImageData)に既にFilmEmulationを一度だけ焼き込んで
                // imageData自体を加工済みにしてある。ここでは再加工せず、そのまま表示するだけでよい。
                CachedPhotoImage(imageData: photo.imageData, cacheKey: photo.imageCacheKey) { uiImage in
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.black.opacity(0.05)
                }
            } else {
                // 通常ChekiPhotoFrameは解禁済み(ベストショット等)の文脈でしか使われないため、
                // ここに来るのは想定外の状態のはずだが、安全側のフォールバックとして
                // 従来通りその場でFilmEmulationを適用して表示する。
                CachedChekiImage(imageData: photo.imageData, cacheKey: chekiCacheKey) { uiImage in
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    CachedPhotoImage(imageData: photo.imageData, cacheKey: photo.imageCacheKey) { rawImage in
                        Image(uiImage: rawImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.black.opacity(0.05)
                    }
                }
            }
        }
        .clipped()
    }
}

/// 撮影直後の生々しい色味に、FilmEmulation(トーンカーブ/ハレーション/グレイン/
/// 周辺減光/現像ムラ)を適用する。Core Imageでの処理はコストが高いため、
/// 写真ごとに安定したキー(呼び出し側が渡すcacheKey、data.hashValueではない)で
/// メモリ+ディスクにキャッシュし、同じ写真の再描画や次回起動時の再計算を避ける。
/// 処理自体は必ずTask.detached経由でメインスレッド外で行う(SwiftUIのbodyから
/// 同期的に呼び出さないこと)。
/// (CGImagePropertyOrientation(_ uiOrientation:)はUtilities/CGImagePropertyOrientation+UIImage.swift
/// に共通化済み。DevelopingPreviewCache等、EXIF向き補正が必要な他の箇所からも使う)。

enum ChekiColorGrade {
    private static let context = CIContext()
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = ImageCacheLimits.countLimit
        cache.totalCostLimit = ImageCacheLimits.totalCostLimitBytes
        return cache
    }()

    /// メモリキャッシュのほか、アプリ再起動をまたいでも消えないディスクキャッシュも持つ。
    /// Caches directory配下(OSが空き容量不足時に自動で消してよい場所)に置く。
    private static let diskCacheDirectory: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ChekiColorGrade", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// メモリキャッシュに既にあれば同期的に即座に返す(無ければnil)。SwiftUIのbodyから
    /// 同期的に呼んでよいのはこれだけ(ディスクI/OやCore Image処理は含まない)。
    static func cachedImage(forKey cacheKey: String) -> UIImage? {
        cache.object(forKey: cacheKey as NSString)
    }

    /// メモリ→ディスクの順にキャッシュを確認し、どちらにも無ければバックグラウンドで
    /// FilmEmulationを適用して生成する。以前はこの処理がSwiftUIのbodyから同期的に
    /// (=メインスレッドで)呼ばれていた(ChekiColorGrade.image(mainThreadSync)という
    /// 名前でその停止時間を計測していた)。今はTask.detached内、つまり必ず
    /// バックグラウンドで実行するため、その計測はメインスレッド側にはもう現れない
    /// (代わりにここでバックグラウンド側の所要時間を計測する)。
    ///
    /// cacheKeyには写真のUUID等、アプリ再起動をまたいでも変わらない識別子を渡すこと
    /// (data.hashValueはプロセスごとにハッシュシードがランダム化されるため使わない)。
    static func image(data: Data, cacheKey: String) async -> UIImage? {
        if let cached = cache.object(forKey: cacheKey as NSString) {
            return cached
        }
        if let diskImage = await loadFromDisk(cacheKey: cacheKey) {
            cache.setObject(diskImage, forKey: cacheKey as NSString, cost: diskImage.estimatedMemoryCost)
            return diskImage
        }

        // CIImage(data:)はEXIFの回転情報をピクセルへ反映しない(内部プロパティとして
        // 保持するだけ)ため、そのままCIFilterで処理してUIImage(cgImage:)化すると
        // 常に.up扱いになり、横向き/縦向きで撮った写真が正面向きに寝てしまう。
        // UIImage(data:)経由でEXIF Orientationを読み取り、.oriented(_:)で
        // ピクセル自体を正しい向きに焼き込んでからフィルターにかける。
        let token = PerformanceSignpost.begin("ChekiColorGrade.image(background)", detail: "bytes=\(data.count)")
        let result = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let sourceImage = UIImage(data: data), let cgImage = sourceImage.cgImage else { return nil }
            let ciImage = CIImage(cgImage: cgImage).oriented(CGImagePropertyOrientation(sourceImage.imageOrientation))

            // トーンカーブ/ハレーション/グレイン/周辺減光/現像ムラの5層構成
            // (詳細はServices/PhotoProcessing/FilmEmulation.swift)。
            let processed = FilmEmulation.process(ciImage, seed: FilmEmulation.seed(for: data))
            guard let outputCGImage = context.createCGImage(processed, from: ciImage.extent) else { return nil }
            return UIImage(cgImage: outputCGImage)
        }.value
        PerformanceSignpost.end("ChekiColorGrade.image(background)", token)

        guard let result else { return nil }
        cache.setObject(result, forKey: cacheKey as NSString, cost: result.estimatedMemoryCost)
        saveToDisk(result, cacheKey: cacheKey)
        return result
    }

    /// 解禁確定の瞬間(CloudKitManager.evaluateGroupUnlockConditions、markForUploadの直前)に
    /// 一度だけ呼ぶ。FilmEmulationのフル加工を適用し、結果をJPEGとして再エンコードした上で
    /// photo.imageDataへ直接書き戻す。以降この写真のimageDataは常に加工済みの最終結果になり、
    /// 各メンバーの端末はCKAsset経由で受け取ったバイト列をそのまま表示すればよくなる
    /// (表示のたびの再加工・キャッシュ経由は不要)。
    ///
    /// 失敗した場合はimageDataを変更しない(未加工のまま解禁されるだけで、無限に
    /// 現像中のままになるよりは安全なフォールバック)。
    /// isColorGradedが既にtrueの場合は何もしない(誤って二重に焼き込む=グレイン等を
    /// 多重に重ねてしまうことを防ぐ冪等性ガード)。
    @MainActor
    static func bakeIntoImageData(_ photo: LaterPhoto) async {
        guard !photo.isColorGraded else { return }
        let data = photo.imageData
        guard !data.isEmpty else { return }
        let token = PerformanceSignpost.begin("ChekiColorGrade.bakeIntoImageData", detail: "bytes=\(data.count)")
        let seed = FilmEmulation.seed(for: data)
        let result = await Task.detached(priority: .userInitiated) { () -> Data? in
            guard let sourceImage = UIImage(data: data), let cgImage = sourceImage.cgImage else { return nil }
            let ciImage = CIImage(cgImage: cgImage).oriented(CGImagePropertyOrientation(sourceImage.imageOrientation))
            let processed = FilmEmulation.process(ciImage, seed: seed)
            guard let outputCGImage = context.createCGImage(processed, from: ciImage.extent) else { return nil }
            return UIImage(cgImage: outputCGImage).jpegData(compressionQuality: 0.9)
        }.value
        PerformanceSignpost.end("ChekiColorGrade.bakeIntoImageData", token)

        guard let result else {
            print("[GroupSync] ChekiColorGrade.bakeIntoImageData失敗: FilmEmulation処理またはJPEGエンコードに失敗")
            return
        }
        photo.imageData = result
        photo.isColorGraded = true
    }

    /// LaterPhoto以外(プロフィール画像等)向けの汎用の焼き込み関数。専用の永続フラグ
    /// (isColorGraded相当)を持たないデータに使う。「元データを新しく設定するタイミング
    /// (ピッカーでの選択直後等)で一度だけ呼ぶ」という運用で冪等性を担保する
    /// (LaterPhotoのようにグループ全体で解禁タイミングを共有するデータではなく、
    /// 本人が能動的に選び直した時にだけ発生する一回きりの操作のため、フラグは不要)。
    static func bakedData(from data: Data) async -> Data? {
        guard !data.isEmpty else { return nil }
        return await Task.detached(priority: .userInitiated) { () -> Data? in
            guard let sourceImage = UIImage(data: data), let cgImage = sourceImage.cgImage else { return nil }
            let ciImage = CIImage(cgImage: cgImage).oriented(CGImagePropertyOrientation(sourceImage.imageOrientation))
            let processed = FilmEmulation.process(ciImage, seed: FilmEmulation.seed(for: data))
            guard let outputCGImage = context.createCGImage(processed, from: ciImage.extent) else { return nil }
            return UIImage(cgImage: outputCGImage).jpegData(compressionQuality: 0.9)
        }.value
    }

    private static func diskURL(for cacheKey: String) -> URL {
        diskCacheDirectory.appendingPathComponent(cacheKey).appendingPathExtension("jpg")
    }

    private static func loadFromDisk(cacheKey: String) async -> UIImage? {
        await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: diskURL(for: cacheKey)) else { return nil }
            return UIImage(data: data)
        }.value
    }

    private static func saveToDisk(_ image: UIImage, cacheKey: String) {
        Task.detached(priority: .background) {
            guard let jpegData = image.jpegData(compressionQuality: 0.9) else { return }
            try? jpegData.write(to: diskURL(for: cacheKey), options: .atomic)
        }
    }

    /// 更新日時が cutoff より古い加工結果を、ディスクから消す。
    /// 以前はこのフォルダを一度も掃除しておらず、写真が7日で消えても加工済みJPEGが
    /// Caches に残り続けていた(Documents & Data が増え続ける原因の一つ)。
    /// PhotoExpiryMaintenance.pruneExpired(起動・フォアグラウンド復帰・バックグラウンド)から呼ぶ。
    static func removeDiskCache(olderThan cutoff: Date) {
        let dir = diskCacheDirectory
        Task.detached(priority: .utility) {
            let urls = (try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey]
            )) ?? []
            for url in urls {
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                if modified < cutoff { try? FileManager.default.removeItem(at: url) }
            }
        }
    }
}

/// 写真ごとに固定の(でも見た目上はランダムな)光のにじみを、右上寄りのコーナーに重ねる。
/// 現像後の写真表示(ChekiPhotoFrame/ProfileChekiCard)からは撤去済み。今後チェキの
/// 縁取り部分など、写真そのものではない箇所での再利用を検討する場合のために残している。
struct ChekiLightLeak: View {
    let seed: UUID

    private var seedValue: Int { abs(seed.hashValue) }

    // 右上に出る確率を高くしつつ、たまに他の角にも出す
    private var corner: UnitPoint {
        let corners: [UnitPoint] = [.topTrailing, .topTrailing, .topTrailing, .top, .trailing]
        return corners[seedValue % corners.count]
    }

    private var tint: Color {
        let tints: [Color] = [
            Color(red: 1.0, green: 0.55, blue: 0.25),
            Color(red: 1.0, green: 0.75, blue: 0.35),
            Color(red: 1.0, green: 0.42, blue: 0.5)
        ]
        return tints[(seedValue / 7) % tints.count]
    }

    var body: some View {
        RadialGradient(
            colors: [tint.opacity(0.32), tint.opacity(0.1), .clear],
            center: corner,
            startRadius: 4,
            endRadius: 130
        )
        .blendMode(.screen)
        .allowsHitTesting(false)
    }
}

// MARK: - 重ね置き表示(最大5枚)

/// 純粋に見た目だけを担当する(タップ処理は持たない)。開く操作は呼び出し側の
/// 既存のタップ領域・ジェスチャーに任せる想定。
struct ChekiPhotoStack: View {
    /// 新しい順(先頭が最新)。5枚を超える分は無視する。
    let photos: [LaterPhoto]

    private var stacked: [LaterPhoto] {
        Array(photos.prefix(5))
    }

    var body: some View {
        ZStack {
            // 古い写真から先に描画し、最新の写真を一番上(最前面)に重ねる。
            ForEach(Array(stacked.enumerated().reversed()), id: \.element.id) { index, photo in
                let depthFromTop = stacked.count - 1 - index
                ChekiPhotoFrame(
                    photo: photo,
                    rotation: rotation(for: photo, index: index),
                    shadowRadius: 5 + CGFloat(depthFromTop) * 2,
                    shadowOpacity: 0.22 + Double(depthFromTop) * 0.035
                )
                .offset(offset(for: photo))
                .zIndex(Double(depthFromTop))
            }
        }
    }

    private func rotation(for photo: LaterPhoto, index: Int) -> Double {
        let h = abs(photo.id.hashValue)
        // -8度 〜 +5度
        return -8 + Double(h % 1000) / 999 * 13
    }

    private func offset(for photo: LaterPhoto) -> CGSize {
        let h = abs(photo.id.hashValue)
        let dx = Double((h / 13) % 13) - 6 // -6...6
        let dy = Double((h / 101) % 9) - 4 // -4...4
        return CGSize(width: dx, height: dy)
    }
}
