import SwiftUI

/// Later内だけで使う匿名ペルソナ(実名・実写とは別の名前・アイコン)の割り当てを行う。
/// 「サーバー側でランダム割り当て」という要件を、自前サーバーを持たないこのアプリの
/// 構成の中で実質的に満たすため、初回オンボーディング時にこの端末上で生成し、
/// UserProfile.name/username/profileImageDataへ書き込む(以降はCloudKit同期で
/// 全メンバー間に伝わるため、実質的に「一度だけの割り当て」として機能する)。
///
/// アイコンは実写ではなく、SF Symbols+背景色を焼き込んだイラスト風の画像にする
/// (ProfileChekiCard/ChekiPhotoFrame/MainTabViewのアバターオーバーレイ等、既存の
/// profileImageData消費側を一切変更せずに済ませるため、"実写でなくイラストである"という
/// 制約はレンダリングされたバイト列の中身だけで満たす)。
enum PersonaGenerator {
    private static let adjectives = [
        "名もなき", "しずかな", "そらいろの", "ひみつの", "ゆうぐれの",
        "ふしぎな", "ちいさな", "とおくの", "なつかしい", "きまぐれな"
    ]
    private static let animals = [
        "キツネ", "クジラ", "ネコ", "フクロウ", "リス",
        "カモメ", "シカ", "ウサギ", "ペンギン", "コアラ"
    ]
    /// 短い識別子(@fox-7f2a のような形式)用の英語表記。表示名(日本語)とは
    /// 対応させず、独立にランダム選択する。
    private static let shortIDWords = [
        "fox", "whale", "cat", "owl", "squirrel",
        "gull", "deer", "rabbit", "penguin", "koala"
    ]
    private static let iconSymbols = [
        "hare.fill", "bird.fill", "leaf.fill", "moon.stars.fill", "cloud.fill",
        "flame.fill", "drop.fill", "snowflake", "sparkles", "pawprint.fill"
    ]
    private static let iconColors: [Color] = [
        Color(red: 0.30, green: 0.43, blue: 0.96),
        Color(red: 0.97, green: 0.44, blue: 0.02),
        Color(red: 0.18, green: 0.62, blue: 0.27),
        Color(red: 0.91, green: 0.29, blue: 0.55),
        Color(red: 0.44, green: 0.28, blue: 0.91),
        Color(red: 0.06, green: 0.60, blue: 0.68)
    ]

    struct Persona {
        let name: String
        let shortID: String
        let iconSymbol: String
        let iconColor: Color
    }

    static func generate() -> Persona {
        Persona(
            name: (adjectives.randomElement() ?? "名もなき") + (animals.randomElement() ?? "キツネ"),
            shortID: "@\(shortIDWords.randomElement() ?? "fox")-\(String(format: "%04x", Int.random(in: 0...0xFFFF)))",
            iconSymbol: iconSymbols.randomElement() ?? "hare.fill",
            iconColor: iconColors.randomElement() ?? .blue
        )
    }

    /// アイコンをJPEGバイト列として焼き込む(既存のUserProfile.profileImageDataへ
    /// そのまま書き込める形式)。ChekiColorGrade.bakedData(from:)と同じ
    /// ImageRendererパターンを使う。
    @MainActor
    static func renderIconImageData(for persona: Persona, size: CGFloat = 240) -> Data? {
        let view = ZStack {
            persona.iconColor
            Image(systemName: persona.iconSymbol)
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
        }
        .frame(width: size, height: size)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let uiImage = renderer.uiImage else { return nil }
        return uiImage.jpegData(compressionQuality: 0.9)
    }
}
