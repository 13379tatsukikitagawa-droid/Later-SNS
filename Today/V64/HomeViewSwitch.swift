import SwiftUI

/// P02〜P04:Home の 切りかえ口。`HomeView` と 同じ 引数を うけとり、V64(新しい Home)か これまでの Home(`HomeView`)を 出す。
/// TodayView は `HomeView(` を `HomeViewSwitch(` に 1か所 かえる だけ。DEBUG の 状態メニューで 見くらべられる。
enum UIFlag {
    static let v64Key = "ui.v64"
    static var v64: Bool { UserDefaults.standard.object(forKey: v64Key) as? Bool ?? true }
}

struct HomeViewSwitch: View {
    let state: HomeState
    let now: Date
    let light: YesterdayLight
    let developContent: HomeDevelopCard.Content
    /// 現像カード・あなたの光に使う、強くぼかした色だけの画像
    let developTexture: UIImage?
    /// 今日撮った枚数(のこりフィルムに出す)
    var shotsToday: Int = 0
    let tones: [Color]
    /// ひらいたあとの光の色(昨日の写真の代表色)
    let openedTones: [Color]
    /// MEを除いた、参加中のグループの要約(昨日、投稿した人数)
    let groupSummaries: [GroupSummary]
    /// まだグループをつくれるか
    let canCreateGroup: Bool
    /// タグ画面・撮影画面・昨日を見る画面などで、Homeが覆われているか
    let isCovered: Bool
    /// 月の長押しの進み具合(球の色づきが同じ値を読む)
    let holdModel: HoldGaugeModel
    let avatarImage: UIImage?
    let avatarSeed: UUID?
    let showsAvatarBadge: Bool
    let onOpenProfile: () -> Void
    /// v54:ME 画面(Recap)を ひらく。アバターは Profile、暗室の ALBUMS 見出しは ME(別の 入口)
    var onOpenMe: () -> Void = {}
    /// アバターの2回タップ・長押し(今日 / 昨日の切りかえ)
    var avatarSwitch = AvatarSwitch()
    var avatarName = ""
    let onDevelopTap: () -> Void
    let onSelectGroup: (UUID) -> Void
    let onCreateGroup: () -> Void
    var onJoinGroup: () -> Void = {}
    /// 列の先頭の「追加」タイルを押した(追加シートを出す)
    var onAddGroup: () -> Void = {}
    var arrivingGroupID: UUID?
    /// 起動アニメーションの、いまの時刻の見た目(LaunchFrame.at)。終わったら .finished
    var launch: LaunchFrame = .finished
    /// ウォーム起動の、0.4秒だけのきらめき(0〜1)
    var sparkle: Double = 0
    /// 光の球(230pt の円ぜんたい)をタップした(Mondo の入口)
    var onOrbTap: () -> Void = {}
    /// v61:じぶんの きのうを ひらく(Home の Yesterday ページの CTA から)
    var onOpenYesterday: () -> Void = {}
    /// Mondo へのダイブ中(球は 5.5倍にふくらんで消え、ほかの要素は 320ms で消える)
    var isDiving = false
    /// 下へつづく層の中身と操作(HomeLayerModel.swift)
    var layerData: HomeLayerData = .empty
    var layerActions = HomeLayerActions()
    /// v14:今日撮った1枚(時刻と街だけ)と、撮った枠をタップしたとき(現像ページャーのその枚数目)
    var todayShots: [TodayShot] = []
    var onOpenShot: (Int) -> Void = { _ in }
    /// v17:下へつづく区画
    var v17: HomeV17Data = .empty
    var v17Actions = HomeV17Actions()
    var bump: V17Bump?
    /// v28 暗室
    var groups: [LaterGroup] = []
    var onOpenChat: (UUID) -> Void = { _ in }
    var onReplyPhoto: (UUID, LaterPhoto) -> Void = { _, _ in }

    var body: some View {
        if UIFlag.v64 {
            HomeV64Host(src: self)
        } else {
            HomeView(
            state: state,
            now: now,
            light: light,
            developContent: developContent,
            developTexture: developTexture,
            shotsToday: shotsToday,
            tones: tones,
            openedTones: openedTones,
            groupSummaries: groupSummaries,
            canCreateGroup: canCreateGroup,
            isCovered: isCovered,
            holdModel: holdModel,
            avatarImage: avatarImage,
            avatarSeed: avatarSeed,
            showsAvatarBadge: showsAvatarBadge,
            onOpenProfile: onOpenProfile,
            onOpenMe: onOpenMe,
            avatarSwitch: avatarSwitch,
            avatarName: avatarName,
            onDevelopTap: onDevelopTap,
            onSelectGroup: onSelectGroup,
            onCreateGroup: onCreateGroup,
            onJoinGroup: onJoinGroup,
            onAddGroup: onAddGroup,
            arrivingGroupID: arrivingGroupID,
            launch: launch,
            sparkle: sparkle,
            onOrbTap: onOrbTap,
            onOpenYesterday: onOpenYesterday,
            isDiving: isDiving,
            layerData: layerData,
            layerActions: layerActions,
            todayShots: todayShots,
            onOpenShot: onOpenShot,
            v17: v17,
            v17Actions: v17Actions,
            bump: bump,
            groups: groups,
            onOpenChat: onOpenChat,
            onReplyPhoto: onReplyPhoto
            )
        }
    }
}
