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
    /// プロフィールの最終更新日時。未編集ならnil。
    let updatedAt: Date?
    /// 光のにじみの位置を決める安定した種。プロフィールが無い場合は呼び出し側が固定値を渡す。
    let seed: UUID
    /// falseの場合、写真タップ・右下の編集バッジのどちらの編集導線も無効化する
    /// (他人のプロフィールを閲覧専用で表示する場合に使う)。QR/シェア機能は
    /// 設定画面へ統合する想定のため、このカードには含めない。
    var isEditable: Bool = true
    var onEdit: () -> Void = {}

    private let frameColor = Color(hex: "F3ECD9")
    private let captionColor = Color(hex: "8a7550")
    private let nameColor = Color(hex: "FBF6E9")
    private let fallbackPhotoColor = Color(red: 0.53, green: 0.49, blue: 0.44) // セピア寄りグレー(未選出時)

    /// カード本体の固定幅。以前はアスペクト比(.aspectRatio(_, contentMode: .fit))だけで
    /// 写真枠のサイズを決めており、呼び出し側(ScrollView内のVStack)から実効幅が
    /// 曖昧に伝播すると、選んだ写真によっては枠の外まで引き伸ばされてしまう不具合が
    /// あった。写真枠のサイズを毎回レイアウト計算に頼らず固定値で確定させる。
    private static let cardWidth: CGFloat = 320
    private static let photoHorizontalInset: CGFloat = 14
    private static let photoTopInset: CGFloat = 14
    private static let photoBottomInset: CGFloat = 18
    private static var photoWidth: CGFloat { cardWidth - photoHorizontalInset * 2 }
    private static var photoHeight: CGFloat { photoWidth * 5 / 4 }

    var body: some View {
        photoContent
        .frame(width: Self.cardWidth)
        .background(frameColor)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
        .overlay(alignment: .bottomTrailing) {
            if isEditable {
                editBadge
                    .padding(10)
            }
        }
    }

    /// カード右下に重ねる、小さな編集ボタン(QR/シェア/編集の3ボタン行を廃止した代替)。
    private var editBadge: some View {
        Button(action: onEdit) {
            Image(systemName: "pencil")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(.black.opacity(0.4), in: Circle())
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
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
            .padding(.top, Self.photoTopInset)
            .padding(.horizontal, Self.photoHorizontalInset)
            .padding(.bottom, Self.photoBottomInset)

            bioRow

            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 0.5)
                .padding(.horizontal, 16)
                .padding(.top, 4)

            dateRow
        }
    }

    // MARK: - 写真部分(aspect-ratio 4:5、写真が無くても必ずこの枠自体は表示される)

    private var photoArea: some View {
        ZStack(alignment: .topLeading) {
            // プロフィール画像は、選び直された時点(ProfileView/OnboardingViewの
            // ピッカーのonChange)で既にChekiColorGrade.bakedData(from:)により
            // 焼き込み済みのバイト列になっている。写真(ChekiPhotoFrame)の解禁済み表示と
            // 同じく、ここでは表示のたびの再加工はせず、そのまま表示するだけでよい。
            if profileImageData != nil {
                CachedPhotoImage(imageData: profileImageData, cacheKey: "avatar_\(seed.uuidString)") { uiImage in
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: Self.photoWidth, height: Self.photoHeight)
                } placeholder: {
                    fallbackPhotoColor
                }
            } else {
                fallbackPhotoColor
                // プロフィール画像が無い(初回設定で撮った1枚が現像前を含む)間は、
                // 自動で割り当てるペルソナのアイコンを出す。
                PersonaIcon(seed: seed)
                    .frame(width: 96, height: 96)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // 下から上への暗転グラデーション(名前ブロックの可読性確保用)。
            LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .bottom, endPoint: .center)

            nameBlock
                .padding(14)
        }
        // 縦横比の異なる写真を選んでも必ずこのサイズに収まるよう、.aspectRatio(_, .fit)による
        // 曖昧なレイアウト伝播ではなく明示的な固定フレームで確定させ、object-fit: cover相当
        // (.aspectRatio(contentMode: .fill)+.frame+.clipped)で中央クロップ表示する。
        .frame(width: Self.photoWidth, height: Self.photoHeight)
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
    }

    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(.custom("Snell Roundhand", size: 26))
                .italic()
                .foregroundStyle(nameColor)
                .shadow(color: .black.opacity(0.55), radius: 4)
                .rotationEffect(.degrees(-4))

            Text("@\(username)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(nameColor.opacity(0.85))
                .shadow(color: .black.opacity(0.5), radius: 3)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    // MARK: - 写真下(鉛筆+自己紹介・区切り線・日付スタンプ)

    private var bioRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(captionColor.opacity(0.8))

            Text(bio.isEmpty ? "自己紹介を書く" : bio)
                .font(.system(size: 13))
                .italic()
                .foregroundStyle(captionColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    private var dateRow: some View {
        HStack {
            Text(dateString)
                .font(.custom("Courier New", size: 11))
            Spacer()
        }
        .foregroundStyle(captionColor.opacity(0.8))
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var dateString: String {
        guard let updatedAt else { return "未編集" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "''yy.M.d"
        return formatter.string(from: updatedAt)
    }

}
