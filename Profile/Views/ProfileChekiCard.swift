import SwiftUI

/// プロフィール全体を1枚の大きなチェキ(インスタントフィルム)として表現するカード。
/// 写真部分にはユーザーが設定したプロフィール画像を表示する(以前は「今日の一枚」に
/// 選ばれた投稿写真を表示していたが、プロフィール画像表示に置き換えた)。
/// グレイン・色調補正はChekiPhotoFrame.swiftの実装(ChekiGrainTexture/ChekiColorGrade)を
/// そのまま共有する。写真部分に名前・自己紹介などの文字を重ねる構成がChekiPhotoFrameとは
/// 大きく異なるため、上位のカードView自体は新規に作っている。
///
/// UserProfileを直接受け取らず個々のプリミティブ値を受け取るようにしているのは、
/// 「プロフィールが1件も存在しない(=まだ誰も撮影していない/オンボーディング未完了)」
/// 状態でも、呼び出し側がフォールバック値を渡すだけでこのカード自体は必ず描画できる
/// ようにするため(データが無いとカードごと非表示になる、という不具合を防ぐ)。
struct ProfileChekiCard: View {
    /// 既に「ゲスト」等のフォールバックを適用済みの表示名
    let name: String
    /// 既に「guest」等のフォールバックを適用済みのユーザーネーム(@なし)
    let username: String
    /// 未設定なら空文字。空の場合はプレースホルダー文言を表示する。
    let bio: String
    /// ユーザーが自分で設定したプロフィール画像。無ければセピア系の既定色にする。
    let profileImageData: Data?
    /// 連続撮影達成回数。0でも"×0"としてそのまま表示する。
    let streak: Int
    /// プロフィールの最終更新日時。未編集ならnil。
    let updatedAt: Date?
    /// 光のにじみの位置を決める安定した種。プロフィールが無い場合は呼び出し側が固定値を渡す。
    let seed: UUID
    /// falseの場合、QR/シェア/編集ボタンを一切表示せず、写真タップでの編集導線も無効化する
    /// (他人のプロフィールを閲覧専用で表示する場合に使う)。
    var isEditable: Bool = true
    var onQRCode: () -> Void = {}
    var onShare: () -> Void = {}
    var onEdit: () -> Void = {}

    private let frameColor = Color(red: 0.969, green: 0.961, blue: 0.933) // #f7f5ee
    private let fallbackPhotoColor = Color(red: 0.53, green: 0.49, blue: 0.44) // セピア寄りグレー(未選出時)

    var body: some View {
        VStack(spacing: 0) {
            photoContent

            if isEditable {
                actionRow
            }
        }
        .background(frameColor)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
    }

    private var photoContent: some View {
        VStack(spacing: 0) {
            // 編集タップは「写真部分(中央)」だけに限定する。以前はphotoContent全体
            // (写真+日付/選出回数の行)を丸ごとButtonにしていたため、タップ可能な領域が
            // カードの下の方まで不必要に広がっていた。
            Group {
                if isEditable {
                    Button(action: onEdit) {
                        photoArea
                    }
                    .buttonStyle(.plain)
                } else {
                    photoArea
                }
            }
            .padding(10)

            dateRow

            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 0.5)
                .padding(.horizontal, 16)
                .padding(.top, 10)
        }
    }

    // MARK: - 写真部分(1:1、写真が無くても必ずこの枠自体は表示される)

    /// このカードはProfileView側でScrollViewの中に置かれており、GeometryReaderを
    /// .aspectRatio(1, .fit)と組み合わせると、ScrollViewが縦方向に無限大の高さを
    /// 提案するせいで正方形化が破綻する(既知のSwiftUIの落とし穴)。そのため
    /// GeometryReaderには頼らず、画面幅から一辺の長さを直接算出する
    /// (呼び出し側のProfileView.padding(.horizontal, 20)+このカード内側の
    /// .padding(10)を差し引いたもの)。
    private var photoSide: CGFloat {
        UIScreen.main.bounds.width - 40 - 20
    }

    private var photoArea: some View {
        let side = photoSide
        return ZStack(alignment: .topLeading) {
            // プロフィール画像は、選び直された時点(ProfileView/OnboardingViewの
            // ピッカーのonChange)で既にChekiColorGrade.bakedData(from:)により
            // 焼き込み済みのバイト列になっている。写真(ChekiPhotoFrame)の解禁済み表示と
            // 同じく、ここでは表示のたびの再加工はせず、そのまま表示するだけでよい。
            if profileImageData != nil {
                CachedPhotoImage(imageData: profileImageData, cacheKey: "avatar_\(seed.uuidString)") { uiImage in
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: side, height: side)
                        .clipped()
                } placeholder: {
                    fallbackPhotoColor
                }
            } else {
                fallbackPhotoColor
            }

            nameBlock
                .padding(14)

            streakBadge
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .trailing)

            bioOverlay
        }
        .frame(width: side, height: side)
    }

    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(.custom("Snell Roundhand", size: 26))
                .italic()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.55), radius: 4)
                .rotationEffect(.degrees(-4))

            Text("@\(username)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.5), radius: 3)
        }
    }

    private var streakBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "camera.fill")
                .font(.system(size: 10, weight: .bold))
            Text("×\(streak)")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.35)))
        .rotationEffect(.degrees(5))
    }

    /// 自己紹介が空でもプレースホルダー文言を表示し、この行自体は必ず存在させる。
    private var bioOverlay: some View {
        VStack {
            Spacer()
            Text(bio.isEmpty ? "自己紹介を書く" : bio)
                .font(.custom("Snell Roundhand", size: 17))
                .italic()
                .foregroundStyle(bio.isEmpty ? .white.opacity(0.55) : .white)
                .shadow(color: .black.opacity(0.6), radius: 4)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .rotationEffect(.degrees(-1.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .padding(.top, 30)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                )
        }
    }

    // MARK: - 写真下の余白

    private var dateRow: some View {
        HStack {
            Text(dateString)
                .font(.system(size: 10, design: .monospaced))
            Spacer()
        }
        .foregroundStyle(.black.opacity(0.45))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var dateString: String {
        guard let updatedAt else { return "未編集" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "''yy.M.d"
        return formatter.string(from: updatedAt)
    }

    private var actionRow: some View {
        HStack(spacing: 0) {
            actionButton(icon: "qrcode", label: "QRコード", action: onQRCode)
            actionDivider
            actionButton(icon: "square.and.arrow.up", label: "シェア", action: onShare)
            actionDivider
            actionButton(icon: "pencil", label: "編集", action: onEdit)
        }
        .frame(height: 56)
    }

    private var actionDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.1))
            .frame(width: 0.5)
            .padding(.vertical, 12)
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.black.opacity(0.7))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
