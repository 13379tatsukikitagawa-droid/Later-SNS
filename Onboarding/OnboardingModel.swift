import Foundation
import SwiftData
import UserNotifications

// MARK: - 場面

/// 初回設定(オンボーディング)の場面。現在の場面はUserDefaultsに保存し、アプリを閉じても
/// 続きから再開する(開幕は再開時には再生しない)。戻る操作・やり直しは用意しない。
/// 初回設定 v2.1 の場面(7画面+メールの場面)。開幕は場面ではない(保存しない)。
enum OnboardingStep: String, CaseIterable {
    /// ① はじめる(Apple / メール)
    case account
    /// ② ニックネーム
    case name
    /// ③ Laterの一日(24時間の輪・6場面)
    case day
    /// ④ あなたを3つのタグで表すと(v2.1 で初回に戻した)
    case tags
    /// ⑤ 仕組みの問題(静けさのパート)
    case quiet
    /// ⑥ 最初の1枚(プロフィール写真)
    case photo
    /// ⑦ 預けました(通知のお願い)→ ようこそ → Home
    case notify
    /// 「メールで続ける」のあとの場面(①の延長)。本筋の順番(next)には入らない。
    case emailInput, emailSending, emailSent, emailVerifying, emailFailed

    /// メールでのサインインの場面か
    var isEmailStep: Bool {
        switch self {
        case .emailInput, .emailSending, .emailSent, .emailVerifying, .emailFailed: return true
        default: return false
        }
    }

    /// 本筋の順番
    static let mainFlow: [OnboardingStep] = [.account, .name, .day, .tags, .quiet, .photo, .notify]

    /// 玉のまわりの点の数(画面の数)
    static let dotCount = 7

    /// 玉のまわりの7つの点のうち、白く灯っている数(画面 i で i 個)
    var litDots: Int {
        switch self {
        case .account: return 1
        case .name: return 2
        case .day: return 3
        case .tags: return 4
        case .quiet: return 5
        case .photo: return 6
        case .notify: return 7
        case .emailInput, .emailSending, .emailSent, .emailVerifying, .emailFailed: return 1
        }
    }

    /// 静けさのパート(⑤だけ)。玉・光を暗くし、触覚を止める。④のタグは通常の画面。
    var isQuiet: Bool { self == .quiet }

    /// 玉が大きい(ヒーロー)場面
    var usesHeroOrb: Bool { self == .account }

    var next: OnboardingStep? {
        guard let index = Self.mainFlow.firstIndex(of: self), index + 1 < Self.mainFlow.count else { return nil }
        return Self.mainFlow[index + 1]
    }
}

// MARK: - 場面の中身(タイプライター用。いまは使わない部品からだけ参照)

struct OnboardingLine {
    enum Tone {
        case primary
        case secondary
    }

    let text: String
    var tone: Tone = .primary
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

// MARK: - 文言

enum OnboardingCopy {
    /// 「自分を表すタグ」の候補(初回設定④とプロフィールの編集で使う)。一覧は SelfTagCatalog で差し替える
    static var selfTagCandidates: [String] { SelfTagCatalog.candidates }
    // ④
    static let tagsTitle = "あなたを3つのタグで\n表すと、何ですか。"
    static let tagsSub = "プロフィールに表示されます。\nあとから変えられます。"
    static let tagAddTitle = "タグを\n追加してください。"
    static let tagAddSub = "1〜12文字。空白は使えません。"
    // ①
    static let accountTitle = "今日を撮ると、\nみんなの昨日がひらく。"
    static let accountSub = "1日1枚。7日で消える、\n友だちとだけの写真アプリ。"
    // ②
    static let nameTitle = "ニックネームを\n決めてください。"
    static let nameSub = "本名でなくて大丈夫です。\nあとから変えられます。"
    // ③
    static let dayTitle = "Laterの一日"
    static func daySub(name: String) -> String { "\(name)さんの一日は、こう流れます。" }
    // ④(数字は出典から切り離さない。根拠が確認できる表現にだけ変える)
    static let quietTitle = "比べてしまうのは、\n仕組みの問題です。"
    static let quietStat = "約3人に1人"
    static let quietStatBody = "体に悩んだことのある10代の女性が、\nInstagramによって悩みが悪化したと\n答えました。"
    static let quietSource = "出典:Facebook社内調査(Instagram)2021年\nWSJ報道・米議会提出資料"
    static let quietAnswer = "Laterには、\nいいねもフォロワー数もありません。"
    // ⑤
    static let photoTitle = "あなたを表す1枚を\n撮ってください。"
    static let photoSub = "景色でも、手元でも大丈夫です。\n翌朝9:00まで、あなたにも見えません。"
    // ⑥
    static let notifyTitle = "預けました。"
    static let notifySub = "写真は、明日の朝9:00に現像されます。"
    static let notifySkippedTitle = "準備ができました。"
    static let notifySkippedSub = "プロフィールの写真は、あとから撮れます。"
    static let notifyNote = "毎朝9:00に、このようにお知らせします。"

    /// 毎朝9:00の通知の本文(⑥の見本カードも、この定数を使う)
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
    /// ボタンの触覚(くっきり軽く1回)
    static let buttonHaptic: (intensity: Float, sharpness: Float) = (0.7, 0.8)
    /// ⑤の長押し:だんだん強く(強さ0.15→0.85、鋭さ0.2→0.55)→ 満ちたら強く1回(1.0 / 0.9)
    static let photoHoldIntensity: ClosedRange<Float> = 0.15...0.85
    static let photoHoldSharpness: ClosedRange<Float> = 0.2...0.55
    static let photoCaptureHaptic: (intensity: Float, sharpness: Float) = (1.0, 0.9)
    /// ようこその吸い込み:連続でだんだん強く
    static let welcomeRamp: (from: Float, to: Float, sharpFrom: Float, sharpTo: Float) = (0.15, 0.8, 0.2, 0.6)
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

    /// 毎朝9:00のお知らせが登録されているか(設定のトグル)
    static func isScheduled() async -> Bool {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.contains { $0.identifier == identifier }
    }

    /// 毎朝9:00のお知らせを解除する
    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// 許可のダイアログの結果。許可 / 拒否 / エラー / 時間切れ(どれでも「ようこそ」へ進む)
    enum AuthorizationResult: String {
        case granted, denied, failed, timedOut
    }

    /// 許可を求める。結果が `timeout` 秒たっても返らなければ、時間切れとして先へ進む(保険)。
    static func requestAuthorization(timeout: Double = 10) async -> AuthorizationResult {
        let once = ResumeOnce()
        return await withCheckedContinuation { continuation in
            Task {
                let result: AuthorizationResult
                do {
                    result = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) ? .granted : .denied
                } catch {
                    print("[Welcome] 通知の許可でエラー: \(error)")
                    result = .failed
                }
                if once.claim() { continuation.resume(returning: result) }
            }
            Task {
                try? await Task.sleep(for: .seconds(timeout))
                if once.claim() { continuation.resume(returning: .timedOut) }
            }
        }
    }

    /// 一度だけ resume するための目印
    private final class ResumeOnce: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func claim() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if done { return false }
            done = true
            return true
        }
    }

    /// 毎日9:00のローカル通知を登録する(許可されているときだけ)。「ようこそ」の演出とは独立に、待たずに呼ぶ。
    @discardableResult
    static func schedule() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return false }

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

    /// 初めてプロフィール画像が現像され、まだその演出を見せていない(ProfileImmersiveViewで一度だけ再生する)。
    static let revealPendingKey = "profilePhotoRevealPending"

    static func store(_ imageData: Data, for profile: UserProfile, takenAt date: Date = Date(), context: ModelContext) {
        profile.pendingProfileImageData = imageData
        profile.pendingProfileImageRevealAt = revealDate(after: date)
        try? context.save()
    }

    /// 撮りなおしの1枚を預ける。入れかわり待ちは1つだけ:もう一度撮ると、待ちの写真が差しかわる(回数の制限なし)。
    static func storeRetake(_ imageData: Data, for profile: UserProfile, takenAt date: Date = Date(), context: ModelContext) {
        store(imageData, for: profile, takenAt: date, context: context)
    }

    /// 入れかわり待ちの写真を捨てて、元にもどす(翌朝9:00 までのあいだだけ)
    static func cancelPending(for profile: UserProfile, context: ModelContext) {
        profile.pendingProfileImageData = nil
        profile.pendingProfileImageRevealAt = nil
        try? context.save()
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

// MARK: - 自分を表すタグの候補(データ)

/// 「自分を表すタグ」の候補の一覧。今は固定。あとでサーバーなどから差し替えられるよう、ここに分けておく。
/// (撮影時のハッシュタグとは別物)
enum SelfTagCatalog {
    static let candidates = ["朝型", "夜型", "散歩", "コーヒー", "音楽", "本", "猫", "ひとり時間", "空", "映画", "料理", "運動"]
}
