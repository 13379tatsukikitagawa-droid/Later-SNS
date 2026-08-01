import Foundation
import SwiftUI

// MARK: - モックユーザーデータ
/// アプリ内で使用するモックユーザーデータベース

struct MockUser: Identifiable, Hashable {
    let id: String
    let name: String
    let username: String
    let bio: String
    let profileImageName: String? // システムアイコン名
    let profileColor: Color // プロフィールカラー
    
    init(id: String, name: String, username: String, bio: String, profileImageName: String? = nil, profileColor: Color = .blue) {
        self.id = id
        self.name = name
        self.username = username
        self.bio = bio
        self.profileImageName = profileImageName
        self.profileColor = profileColor
    }
}

// MARK: - モックユーザーデータベース
class MockUserDatabase {
    static let shared = MockUserDatabase()
    
    // モックユーザー一覧
    let users: [MockUser] = [
        MockUser(
            id: "user_001",
            name: "田中太郎",
            username: "tanaka_taro",
            bio: "デザイナー 🎨 | 東京在住 | 美しいUIを作ることが好き",
            profileImageName: "paintbrush.fill",
            profileColor: .purple
        ),
        MockUser(
            id: "user_002",
            name: "佐藤花子",
            username: "sato_hanako",
            bio: "フォトグラファー 📸 | 旅行が大好き | 世界中を旅しています",
            profileImageName: "camera.fill",
            profileColor: .orange
        ),
        MockUser(
            id: "user_003",
            name: "鈴木一郎",
            username: "suzuki_ichiro",
            bio: "エンジニア 👨‍💻 | SwiftUIが好き | iOS開発者",
            profileImageName: "laptopcomputer",
            profileColor: .blue
        ),
        MockUser(
            id: "user_004",
            name: "高橋美咲",
            username: "takahashi_misaki",
            bio: "イラストレーター 🎨 | 猫好き 🐱 | 日々創作活動中",
            profileImageName: "paintpalette.fill",
            profileColor: .pink
        ),
        MockUser(
            id: "user_005",
            name: "伊藤健太",
            username: "ito_kenta",
            bio: "ライター ✍️ | テクノロジーとライフスタイル | 記事執筆中",
            profileImageName: "pencil",
            profileColor: .green
        ),
        MockUser(
            id: "user_006",
            name: "山田大輔",
            username: "yamada_daisuke",
            bio: "起業家 💼 | スタートアップ経営 | 新しいことに挑戦",
            profileImageName: "briefcase.fill",
            profileColor: .indigo
        ),
        MockUser(
            id: "user_007",
            name: "中村愛美",
            username: "nakamura_aimi",
            bio: "ヨガインストラクター 🧘‍♀️ | ウェルネス | 心と体の健康",
            profileImageName: "figure.yoga",
            profileColor: .cyan
        ),
        MockUser(
            id: "user_008",
            name: "小林翔太",
            username: "kobayashi_shota",
            bio: "料理人 🍳 | 和食専門 | 季節の食材を活かした料理",
            profileImageName: "fork.knife",
            profileColor: .brown
        ),
        MockUser(
            id: "user_009",
            name: "渡辺真由美",
            username: "watanabe_mayumi",
            bio: "音楽プロデューサー 🎵 | ジャズとR&B | 新しい音を探求中",
            profileImageName: "music.note",
            profileColor: .purple
        ),
        MockUser(
            id: "user_010",
            name: "加藤誠",
            username: "kato_makoto",
            bio: "建築家 🏛 | モダンデザイン | 空間と人をつなぐ",
            profileImageName: "building.2.fill",
            profileColor: .gray
        ),
        MockUser(
            id: "user_011",
            name: "佐々木優子",
            username: "sasaki_yuko",
            bio: "マーケター 📊 | データ分析が得意 | ブランド戦略",
            profileImageName: "chart.bar.fill",
            profileColor: .teal
        ),
        MockUser(
            id: "user_012",
            name: "木村拓也",
            username: "kimura_takuya",
            bio: "アスリート ⚽️ | サッカー選手 | 夢を追いかけて",
            profileImageName: "sportscourt.fill",
            profileColor: .green
        ),
        MockUser(
            id: "user_013",
            name: "林恵子",
            username: "hayashi_keiko",
            bio: "教育者 📚 | 子どもたちの未来を創る | 学びの楽しさを伝える",
            profileImageName: "book.fill",
            profileColor: .orange
        ),
        MockUser(
            id: "user_014",
            name: "森本隆",
            username: "morimoto_takashi",
            bio: "映像クリエイター 🎬 | ドキュメンタリー制作 | 物語を紡ぐ",
            profileImageName: "film.fill",
            profileColor: .red
        ),
        MockUser(
            id: "user_015",
            name: "松本あかり",
            username: "matsumoto_akari",
            bio: "ファッションデザイナー 👗 | サステナブルファッション",
            profileImageName: "tshirt.fill",
            profileColor: .pink
        ),
        MockUser(
            id: "user_016",
            name: "井上聡",
            username: "inoue_satoshi",
            bio: "データサイエンティスト 📈 | AI/ML | 未来を予測する",
            profileImageName: "brain.head.profile",
            profileColor: .blue
        ),
        MockUser(
            id: "user_017",
            name: "斎藤麻衣",
            username: "saito_mai",
            bio: "ライフコーチ 💫 | 人生をより良くするサポート",
            profileImageName: "sparkles",
            profileColor: .yellow
        ),
        MockUser(
            id: "user_018",
            name: "前田健",
            username: "maeda_ken",
            bio: "バリスタ ☕️ | コーヒーへの情熱 | 一杯一杯に心を込めて",
            profileImageName: "cup.and.saucer.fill",
            profileColor: .brown
        ),
        MockUser(
            id: "user_019",
            name: "藤田理恵",
            username: "fujita_rie",
            bio: "環境活動家 🌱 | 持続可能な社会を目指して",
            profileImageName: "leaf.fill",
            profileColor: .green
        ),
        MockUser(
            id: "user_020",
            name: "岡田直樹",
            username: "okada_naoki",
            bio: "ゲームデベロッパー 🎮 | インディーゲーム制作 | 楽しさを創造",
            profileImageName: "gamecontroller.fill",
            profileColor: .purple
        )
    ]
    
    // MARK: - 検索機能
    
    /// ユーザー名または名前で検索
    /// - Parameter query: 検索クエリ
    /// - Returns: 一致するユーザーの配列
    func searchUsers(query: String) -> [MockUser] {
        guard !query.isEmpty else { return users }
        
        let lowercasedQuery = query.lowercased()
        
        return users.filter { user in
            user.name.lowercased().contains(lowercasedQuery) ||
            user.username.lowercased().contains(lowercasedQuery) ||
            user.bio.lowercased().contains(lowercasedQuery)
        }
    }
    
    /// IDでユーザーを取得
    /// - Parameter id: ユーザーID
    /// - Returns: 一致するユーザー、見つからない場合はnil
    func getUserByID(_ id: String) -> MockUser? {
        users.first { $0.id == id }
    }
    
    /// ランダムなユーザーを取得
    /// - Parameter count: 取得する人数
    /// - Returns: ランダムなユーザーの配列
    func getRandomUsers(count: Int = 5) -> [MockUser] {
        Array(users.shuffled().prefix(count))
    }
    
    /// おすすめユーザーを取得（既にフォロー中のユーザーを除外）
    /// - Parameter followingIDs: 既にフォロー中のユーザーIDリスト
    /// - Returns: おすすめユーザーの配列
    func getRecommendedUsers(excludingIDs followingIDs: [String], count: Int = 10) -> [MockUser] {
        let availableUsers = users.filter { !followingIDs.contains($0.id) }
        return Array(availableUsers.shuffled().prefix(count))
    }
}
