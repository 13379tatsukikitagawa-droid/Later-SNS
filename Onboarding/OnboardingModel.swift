import Foundation
import SwiftData
import UserNotifications

// MARK: - 場面

/// 初回設定(オンボーディング)の場面。現在の場面はUserDefaultsに保存し、アプリを閉じても
/// 続きから再開する(開幕は再開時には再生しない)。戻る操作・やり直しは用意しない。
enum OnboardingStep: String, CaseIterable {
    case meet, account, name, nameConfirm
    case explainAsk, explainSealed, explain9, explainArrive
    case tags
    case lookismAsk1, lookismAsk2
    case lookismNow1, lookismNow2, lookismNow3
    case lookismStructure1, lookismStructure2, lookismStructure3
    case lookismBlame, lookismAnswer, lookismConsent
    case profilePhoto, notify, finish
    /// 「メールで続ける」のあとの場面(アカウントの1問の延長)。本筋の順番(next)には入らない。
    case emailInput, emailSending, emailSent, emailVerifying, emailFailed

    /// メールでのサインインの場面か
    var isEmailStep: Bool {
        switch self {
        case .emailInput, .emailSending, .emailSent, .emailVerifying, .emailFailed: return true
        default: return false
        }
    }

    /// 本筋の順番(メールの場面を除く)
    static let mainFlow: [OnboardingStep] = allCases.filter { !$0.isEmailStep }

    /// 玉のまわりの8つの点のうち、白く灯っている数(進み具合。数字は出さない)。
    var litDots: Int {
        switch self {
        case .meet: return 0
        case .account: return 1
        case .name, .nameConfirm: return 2
        case .explainAsk, .explainSealed, .explain9, .explainArrive: return 3
        case .tags: return 4
        case .lookismAsk1, .lookismAsk2, .lookismNow1, .lookismNow2, .lookismNow3,
             .lookismStructure1, .lookismStructure2, .lookismStructure3,
             .lookismBlame, .lookismAnswer, .lookismConsent: return 4
        case .profilePhoto: return 6
        case .notify: return 7
        case .finish: return 8
        case .emailInput, .emailSending, .emailVerifying, .emailFailed: return 1
        // 送りました(待っている感じ)
        case .emailSent: return 6
        }
    }

    /// ルッキズムのパート(静けさのパート)。玉・点・光を消し、触覚もタイプのスキップも止める。
    var isQuiet: Bool {
        switch self {
        case .lookismAsk1, .lookismAsk2, .lookismNow1, .lookismNow2, .lookismNow3,
             .lookismStructure1, .lookismStructure2, .lookismStructure3,
             .lookismBlame, .lookismAnswer, .lookismConsent: return true
        default: return false
        }
    }

    var next: OnboardingStep? {
        let flow = Self.mainFlow
        guard let index = flow.firstIndex(of: self), index + 1 < flow.count else { return nil }
        return flow[index + 1]
    }
}

// MARK: - 場面の中身

struct OnboardingLine {
    enum Tone {
        /// 白(静けさのパートでは#E9E9ED)
        case primary
        /// グレー(#8E8E93)
        case secondary
    }

    let text: String
    var tone: Tone = .primary
}

enum OnboardingActions {
    case primary(String)
    case choice(yes: String, no: String)
    case account
    case nameInput
    /// ボタンなし。打ち終わってから指定秒後に自動で次へ。
    case auto(after: TimeInterval)
    case tags
    case hold(OnboardingHoldKind)
    case profilePhoto
    case notify
    /// メールアドレスの入力(CTA「リンクを送る」)
    case emailInput
    /// 送りました(メールアプリを開く・アドレスを変える・再送)
    case emailSent
    /// 失敗(もう一度送る・Appleで続ける)
    case emailFailed
    /// ボタンなし(送信中・確認中)
    case none
}

enum OnboardingHoldKind {
    /// ルッキズムの最後の同意
    case consent
    /// 結び(Homeへ)
    case finish
}

/// メールでのサインインがうまくいかなかった理由
enum EmailSignInFailure: Equatable {
    /// 通信の失敗・時間切れ
    case network
    /// リンクの期限切れ・使用済み
    case expiredLink
    /// 別の端末でリンクを開いた(アドレスが端末に残っていない)
    case missingEmail
    /// 送信の回数が多すぎる(Firebaseの制限)
    case tooManyRequests

    var title: String {
        switch self {
        case .network, .tooManyRequests: return "送れませんでした。"
        case .expiredLink, .missingEmail: return "確かめられませんでした。"
        }
    }

    var message: String {
        switch self {
        case .network: return "通信を確かめて、\nもう一度ためしてください。"
        case .expiredLink: return "リンクの期限が切れています。\nもう一度、送ってください。"
        case .missingEmail: return "同じアドレスを、\nもう一度入れてください。"
        case .tooManyRequests: return "しばらくしてから、\nもう一度ためしてください。"
        }
    }

    /// Firebase Authのエラーを、画面の言葉に分ける(NSErrorのcodeで判定する)。
    static func from(_ error: Error) -> EmailSignInFailure {
        switch (error as NSError).code {
        case 17010: return .tooManyRequests          // tooManyRequests
        case 17028, 17030: return .expiredLink       // expiredActionCode / invalidActionCode
        case 17034: return .missingEmail             // missingEmail
        default: return .network
        }
    }
}

enum OnboardingVisual {
    case none
    /// 小さな枠の中央に白い点だけ(写真は出ない)
    case sealedFrame
    /// 「09:00」と、一斉に光る14個の点
    case nineAM
    /// 34個の点の輪(オレンジ→青→黄)
    case arriveRing
    /// 灰色の「いいね」「フォロワー」の数字
    case counts
    /// 3つの丸(1つだけ白く灯る)
    case threeCircles
    /// 通知カードの見本
    case notificationCard
    /// プロフィール撮影の小さなファインダー
    case viewfinder
    /// リンクの確認中の輪(直径96pt、白い輪が回る)
    case verifyingRing
}

struct OnboardingScene {
    let lines: [OnboardingLine]
    let actions: OnboardingActions
    var visual: OnboardingVisual = .none
    /// 文字の大きさ(既定27pt)。行数の多い場面だけ小さくする。
    var fontSize: CGFloat = 27
    /// 文の下に添える小さな出典など(等幅)。
    var footnote: String?
}

extension OnboardingStep {
    func scene(name: String, emailFailure: EmailSignInFailure = .network) -> OnboardingScene {
        switch self {
        case .emailInput:
            return OnboardingScene(lines: [.init(text: "メールアドレスを\n教えてください。")], actions: .emailInput, fontSize: 26)
        case .emailSending:
            return OnboardingScene(lines: [.init(text: "リンクを\n送っています…")], actions: .none, fontSize: 26)
        case .emailSent:
            return OnboardingScene(lines: [.init(text: "メールを\n送りました。")], actions: .emailSent)
        case .emailVerifying:
            return OnboardingScene(lines: [.init(text: "リンクを\n確認しています…")], actions: .none, visual: .verifyingRing, fontSize: 26)
        case .emailFailed:
            // 補足(14pt)は、見出しの下に入力欄と同じ層で出す(OnboardingFlowView.emailFailureNote)。
            return OnboardingScene(lines: [.init(text: emailFailure.title)], actions: .emailFailed, fontSize: 26)
        case .meet:
            return OnboardingScene(lines: [
                .init(text: "これから、\nいくつか質問をします。\n"),
                .init(text: "答えをもとに、\nあなたのLaterを\n用意します。", tone: .secondary),
            ], actions: .primary("はじめる"))
        case .account:
            return OnboardingScene(lines: [.init(text: "以前、Laterを\n使ったことはありますか。")], actions: .account)
        case .name:
            return OnboardingScene(lines: [.init(text: "Laterの中で、\nあなたを何と\n呼べばいいですか。")], actions: .nameInput)
        case .nameConfirm:
            return OnboardingScene(lines: [.init(text: "\(name)さん、\nよろしくお願いします。")], actions: .auto(after: 1.8))
        case .explainAsk:
            return OnboardingScene(lines: [.init(text: "写真を撮ったら、\nすぐに確認したいですか。")], actions: .choice(yes: "はい", no: "いいえ"))
        case .explainSealed:
            return OnboardingScene(lines: [.init(text: "Laterでは、\n撮った写真をすぐに\n見ることはできません。")], actions: .primary("つづける"), visual: .sealedFrame)
        case .explain9:
            return OnboardingScene(lines: [.init(text: "毎朝9:00、\n全員が同時に、\n1日1枚だけ撮れるように\nなります。")], actions: .primary("つづける"), visual: .nineAM)
        case .explainArrive:
            return OnboardingScene(lines: [.init(text: "今日の1枚を撮ると、\n昨日みんなが撮った\n写真が届きます。")], actions: .primary("つづける"), visual: .arriveRing)
        case .tags:
            return OnboardingScene(lines: [.init(text: "あなたを3つのタグで\n表すとしたら、何ですか。")], actions: .tags, fontSize: 25)
        case .lookismAsk1:
            return OnboardingScene(lines: [.init(text: "SNSに写真を載せる前に、\n何度も撮り直したことは\nありますか。")], actions: .choice(yes: "ある", no: "ない"))
        case .lookismAsk2:
            return OnboardingScene(lines: [.init(text: "見た目が気になって、\n投稿をやめたことは\nありますか。")], actions: .choice(yes: "ある", no: "ない"))
        case .lookismNow1:
            return OnboardingScene(lines: [.init(text: "多くのSNSでは、\n写真は加工されてから\n公開されます。")], actions: .primary("つづける"))
        case .lookismNow2:
            return OnboardingScene(lines: [.init(text: "肌は整えられ、\n輪郭は細くされ、\n本当の顔は少しずつ\n見えなくなっています。")], actions: .primary("つづける"))
        case .lookismNow3:
            return OnboardingScene(lines: [.init(text: "そして、その写真には\n数字がつきます。\nいいねの数、\nフォロワーの数。")], actions: .primary("つづける"), visual: .counts)
        case .lookismStructure1:
            return OnboardingScene(lines: [.init(text: "数字は\n比べるためにあります。")], actions: .primary("つづける"))
        case .lookismStructure2:
            return OnboardingScene(lines: [.init(text: "比べられる場所では、\n人は「よく見られる\n自分」を作り続ける\nことになります。")], actions: .primary("つづける"))
        case .lookismStructure3:
            return OnboardingScene(
                lines: [.init(text: OnboardingCopy.lookismStatistic)],
                actions: .primary("つづける"),
                visual: .threeCircles,
                footnote: OnboardingCopy.lookismStatisticSource
            )
        case .lookismBlame:
            return OnboardingScene(lines: [
                .init(text: "これは、あなたが\n弱いからではありません。\n"),
                .init(text: "比べたくなるように\n作られた仕組みの\n問題です。", tone: .secondary),
            ], actions: .primary("つづける"))
        case .lookismAnswer:
            // 4つの約束で9行になるため、この場面だけ文字を小さくして画面に収める。
            return OnboardingScene(lines: [
                .init(text: "Laterには、\nいいねもフォロワー数も\nありません。\n"),
                .init(text: "加工も、\n撮り直しもできません。\n"),
                .init(text: "プロフィールに、\n顔は必要ありません。\n"),
                .init(text: "ここでは、見た目ではなく\nその日の瞬間を残します。", tone: .secondary),
            ], actions: .primary("つづける"), fontSize: 21)
        case .lookismConsent:
            return OnboardingScene(lines: [.init(text: "この約束のもとで、\nはじめますか。")], actions: .hold(.consent))
        case .profilePhoto:
            return OnboardingScene(lines: [
                .init(text: "あなたを表す1枚を\n撮ってください。\n"),
                .init(text: "顔である必要はありません。", tone: .secondary),
            ], actions: .profilePhoto, visual: .viewfinder)
        case .notify:
            return OnboardingScene(lines: [.init(text: "毎朝9:00に、\n撮影の開始をお知らせ\nしてもいいですか。")], actions: .notify, visual: .notificationCard)
        case .finish:
            return OnboardingScene(lines: [
                .init(text: "準備ができました。\n"),
                .init(text: "明日の朝、\nあなたの最初の1枚が\n現像されます。", tone: .secondary),
            ], actions: .hold(.finish))
        }
    }
}

// MARK: - 文言

enum OnboardingCopy {
    /// 「Laterの答え」の数字の根拠。根拠が確認できる表現にだけ変更すること。
    /// 報道(WSJ, 2021)では、Meta(旧Facebook)社内調査で「体の悩みを抱えた10代の少女の32%が、
    /// Instagramでその悩みが悪化したと答えた」とされている。
    static let lookismStatistic = "体に悩む10代女性の\n32%が、Instagramで\n悩みが悪化したと\n答えました。"
    /// 出典の1行は、数字と切り離さず必ず画面に出す。
    static let lookismStatisticSource = "出典:Meta(旧Facebook)社内調査(Instagram)\n2021年 WSJ報道・米議会提出資料"

    /// 「自分を表すタグ」の候補。後で流行のタグに差し替えられるよう、データとして分けておく。
    static let selfTagCandidates = ["朝型", "散歩", "コーヒー", "音楽", "夜型", "本", "猫", "ひとり時間", "空"]

    /// プロフィール撮影の例(押せない、案内だけ)。
    static let profilePhotoExamples = ["いま見えている景色", "手元", "好きなもの"]

    static let dailyNotificationBody = "9:00 になりました。今日を撮れます。"

    static let appleSignInFailed = "Appleでのサインインができませんでした。もう一度ためしてください。"
}

// MARK: - 入力ルール

enum OnboardingRules {
    static let nameMaxLength = 12
    static let tagMaxLength = 12
    static let maxSelfTags = 3

    enum NameProblem {
        case empty, tooLong, looksLikeContact
    }

    /// 前後の空白を削った名前。1〜12文字、URL・メールアドレスらしい文字列は不可
    /// (本名・連絡先を入れさせない)。
    static func validateName(_ raw: String) -> (name: String, problem: NameProblem?) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return (name, .empty) }
        if name.count > nameMaxLength { return (name, .tooLong) }
        if looksLikeContact(name) { return (name, .looksLikeContact) }
        return (name, nil)
    }

    private static func looksLikeContact(_ text: String) -> Bool {
        let lowered = text.lowercased()
        if lowered.contains("@") || lowered.contains("＠") { return true }
        if lowered.contains("http") || lowered.contains("www.") || lowered.contains("://") { return true }
        // 「example.com」のようなドメインらしい並び
        return lowered.range(of: #"[a-z0-9-]+\.[a-z]{2,}"#, options: .regularExpression) != nil
    }

    /// 自由入力のタグ。「#」は自動で外し、空白は不可。1〜12文字。
    static func normalizedTag(_ raw: String) -> String? {
        var tag = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while tag.hasPrefix("#") || tag.hasPrefix("＃") { tag.removeFirst() }
        guard !tag.isEmpty, tag.count <= tagMaxLength,
              tag.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
        return tag
    }

    /// 入力させないユーザーID(@から始まるID)は自動で割り当てる。
    static func generatedUsername() -> String {
        let chars = Array("abcdefghijkmnpqrstuvwxyz23456789")
        return "later_" + String((0..<8).map { _ in chars.randomElement()! })
    }
}

// MARK: - 調整用の数値

enum OnboardingTuning {
    /// タイプ中の触覚を何文字ごとに鳴らすか(0なら鳴らさない)。実機でうるさければ3にするか0にする。
    static let typingHapticEvery = 2
    static let typingHaptic: (intensity: Float, sharpness: Float) = (0.25, 0.5)
    /// ボタン(=パシャ)の触覚。ボタンとシャッターで2回鳴らさない。
    static let shutterHaptic: (intensity: Float, sharpness: Float) = (0.7, 0.8)
    static let tagHaptic: (intensity: Float, sharpness: Float) = (0.5, 0.6)
    static let openingSettleHaptic: (intensity: Float, sharpness: Float) = (0.5, 0.6)
    static let finishHaptic: (intensity: Float, sharpness: Float) = (1.0, 1.0)
    static let finishTail: (intensity: Float, duration: TimeInterval) = (0.4, 0.3)
    /// パシャの瞬間にシャッター音を鳴らすか(今は鳴らさない。将来、設定で選べるようにする)。
    static let playsShutterSound = false
    /// メールのリンクを再送できるまでの秒数
    static let emailResendInterval = 30
}

// MARK: - 保存キー

extension Notification.Name {
    /// メールのサインインリンクからアプリに戻ってきた(LaterApp.onOpenURL)
    static let emailSignInLinkOpened = Notification.Name("emailSignInLinkOpened")
    /// メールのサインインリンクで、サインインを完了できなかった(objectにError。nilなら端末にアドレスが無い)
    static let emailSignInLinkFailed = Notification.Name("emailSignInLinkFailed")
}

enum OnboardingStorage {
    static let stepKey = "onboardingStep"
    static let completedKey = "onboardingCompleted"
}

// MARK: - 毎朝9:00のお知らせ

enum DailyOpenNotification {
    /// 端末のローカル時刻で何時に知らせるか(撮影スタートと同じ)。
    static let hour = DailyExposureRules.openingHour
    static let identifier = "later.daily.open"

    /// 許可を求め、許可されたら毎日9:00のローカル通知を登録する。拒否されたら何もしない。
    @discardableResult
    static func requestAndSchedule() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return false }

        let content = UNMutableNotificationContent()
        content.body = OnboardingCopy.dailyNotificationBody
        content.sound = .default
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        do {
            try await center.add(request)
            return true
        } catch {
            print("[DailyOpenNotification] 登録に失敗: \(error)")
            return false
        }
    }
}

// MARK: - プロフィール画像の現像

/// 初回設定で撮ったプロフィール画像は、次の9:00に現像されるまで本人にも見せない。
/// それまではペルソナのアイコン(PersonaIcon)を表示する。
@MainActor
enum ProfilePhotoDevelopment {
    /// 撮った時刻から見た「次の9:00」。
    static func revealDate(after date: Date, calendar: Calendar = .current) -> Date {
        let todayOpening = calendar.date(bySettingHour: DailyExposureRules.openingHour, minute: 0, second: 0, of: date) ?? date
        if date < todayOpening { return todayOpening }
        return calendar.date(byAdding: .day, value: 1, to: todayOpening) ?? todayOpening
    }

    /// プロフィール画像の撮り直しは、1日にこの回数まで(初回設定の1枚は含めない)。
    static let maxRetakesPerDay = 1
    /// 初めてプロフィール画像が現像され、まだその演出を見せていない(ProfileImmersiveViewで一度だけ再生する)。
    static let revealPendingKey = "profilePhotoRevealPending"
    private static let retakeDayKey = "profilePhotoRetakeDay"
    private static let retakeCountKey = "profilePhotoRetakeCount"

    static func canRetake(now: Date = Date()) -> Bool {
        retakesToday(now: now) < maxRetakesPerDay
    }

    private static func retakesToday(now: Date) -> Int {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: retakeDayKey) == ExposureDayStore.dayKey(for: now) else { return 0 }
        return defaults.integer(forKey: retakeCountKey)
    }

    static func store(_ imageData: Data, for profile: UserProfile, takenAt date: Date = Date(), context: ModelContext) {
        profile.pendingProfileImageData = imageData
        profile.pendingProfileImageRevealAt = revealDate(after: date)
        try? context.save()
    }

    /// 撮り直しの1枚を預ける(回数を数える)。
    static func storeRetake(_ imageData: Data, for profile: UserProfile, takenAt date: Date = Date(), context: ModelContext) {
        let defaults = UserDefaults.standard
        let count = retakesToday(now: date)
        defaults.set(ExposureDayStore.dayKey(for: date), forKey: retakeDayKey)
        defaults.set(count + 1, forKey: retakeCountKey)
        store(imageData, for: profile, takenAt: date, context: context)
    }

    /// 現像の時刻を過ぎていれば、プロフィール画像として反映し、参加中のグループへ同期する。
    static func promoteIfDue(_ profile: UserProfile, now: Date = Date(), context: ModelContext) {
        guard let data = profile.pendingProfileImageData,
              let revealAt = profile.pendingProfileImageRevealAt,
              now >= revealAt else { return }
        if profile.profileImageData == nil {
            UserDefaults.standard.set(true, forKey: revealPendingKey)
        }
        profile.profileImageData = data
        profile.profileUpdatedAt = now
        profile.pendingProfileImageData = nil
        profile.pendingProfileImageRevealAt = nil
        try? context.save()
        UserDefaults.standard.set(data, forKey: "profileImageData")

        if let cloudKitManager = CloudKitManager.current {
            for group in profile.groups {
                cloudKitManager.markForUpload(userProfile: profile, in: group)
            }
        }
        Task { await UserDirectoryService.publish(profile) }
    }
}
