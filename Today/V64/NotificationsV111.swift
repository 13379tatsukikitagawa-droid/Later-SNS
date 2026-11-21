import SwiftUI
import UIKit
import UserNotifications

// MARK: - 許可の 状態 ・ 6つの スイッチ(v111 §8)

enum NotifPermission {
    case unset, on, off
    static func current() async -> NotifPermission {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        switch s.authorizationStatus {
        case .notDetermined: return .unset
        case .denied: return .off
        default: return .on
        }
    }
}

/// Worker の `/v1/prefs` と 同じ 6つ(名前も そろえる)。「9:00 ひらいた」「ラストコール」は 端末の ローカル通知で 同じ 値を 使う。
struct NotifPrefs: Codable, Equatable {
    var friend_request = true
    var friend_accepted = true
    var trip_invite = true
    var trip_chat = true
    var opened = true
    var lastcall = false
}

enum NotifPrefsStore {
    private static let key = "notifPrefsV111"
    static func load() -> NotifPrefs {
        guard let d = UserDefaults.standard.data(forKey: key), let p = try? JSONDecoder().decode(NotifPrefs.self, from: d) else { return NotifPrefs() }
        return p
    }
    static func save(_ p: NotifPrefs) {
        if let d = try? JSONEncoder().encode(p) { UserDefaults.standard.set(d, forKey: key) }
    }

    /// 端末で 出す 2つ(9:00 ひらいた ・ ラストコール)を スイッチの とおりに そろえる(許可が ある 時だけ)
    static func applyLocal(_ p: NotifPrefs) async {
        guard await NotifPermission.current() == .on else { return }
        if p.opened { _ = await DailyOpenNotification.schedule() } else { DailyOpenNotification.cancel() }
        if p.lastcall { await LastCallNotification.schedule() } else { LastCallNotification.cancel() }
    }
}

/// ラストコール:毎日 23:50(端末の ローカル通知 ・ 初期 オフ)
enum LastCallNotification {
    static let identifier = "later.lastcall"
    static func cancel() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier]) }
    static func schedule() async {
        let c = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "ラストコール"
        content.body = "あと 10分。今日の 1枚を 撮ろう"
        content.sound = .default
        var dc = DateComponents(); dc.hour = 23; dc.minute = 50
        let req = UNNotificationRequest(identifier: identifier, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true))
        c.removePendingNotificationRequests(withIdentifiers: [identifier])
        try? await c.add(req)
    }
}

extension SocialClient {
    static func fetchPrefs() async -> NotifPrefs? {
        guard SocialFlag.useWorker, let d = try? await call("GET", "/v1/prefs") else { return nil }
        return try? JSONDecoder().decode(NotifPrefs.self, from: d)
    }
    @discardableResult static func savePrefs(_ p: NotifPrefs) async -> Bool {
        guard SocialFlag.useWorker, let d = try? JSONEncoder().encode(p), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return false }
        return (try? await call("POST", "/v1/prefs", body: o)) != nil
    }
    /// テスト通知。Worker(切りかえ オン)なら 本物の APNs、そうでなければ 端末の 通知。戻り値は 画面に 出す ひとこと。
    static func sendTestPush() async -> String {
        if SocialFlag.useWorker {
            guard let d = try? await call("POST", "/v1/push/test"), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return "送れませんでした ・ もう一度" }
            if (o["sent"] as? Int ?? 0) > 0 { return "送りました ・ すぐ 届きます" }
            let reason = (o["reasons"] as? [String])?.first ?? (o["reason"] as? String) ?? ""
            return reason == "no_device" ? "この iPhone が まだ 登録されて いません" : "届きませんでした(\(reason))"
        }
        let content = UNMutableNotificationContent()
        content.title = "Lattag"; content.body = "テスト通知です。届いて います"; content.sound = .default
        let req = UNNotificationRequest(identifier: "later.test.local", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
        try? await UNUserNotificationCenter.current().add(req)
        return "この iPhone に 送りました"
    }
}

// MARK: - 許可を 聞く タイミング(§8-1)

enum NotifAskWhy: String, Identifiable {
    case friend, trip
    var id: String { rawValue }
    var line: String { self == .friend ? "相手が 承認したら 知らせます" : "みんなが 撮ったら 知らせます" }
    var sub: String { self == .friend ? "友だち申請 ・ 承認 ・ Trip の 招待" : "Trip の チャット ・ 9:00 ひらいた" }
}

extension Notification.Name { static let notifAskTrigger = Notification.Name("notifAskTrigger") }

@MainActor @Observable
final class NotifAskCenter {
    static let shared = NotifAskCenter()
    var why: NotifAskWhy?
    private let laterKey = "notifAskLaterAt"
    private let askedKey = "notifAskedFriend"

    /// はじめて 友だち申請を 送った / 受けた 時、はじめて Trip を 作った / 入った 時。`あとで` の 人には 7日 まで 出さない。
    func trigger(_ why: NotifAskWhy) async {
        guard self.why == nil, await NotifPermission.current() == .unset else { return }
        if let t = UserDefaults.standard.object(forKey: laterKey) as? Date, Date().timeIntervalSince(t) < 7 * 86400 { return }
        self.why = why
    }
    func later() { UserDefaults.standard.set(Date(), forKey: laterKey); why = nil }
    func accept() async {
        why = nil
        let r = await DailyOpenNotification.requestAuthorization(timeout: 20)
        if r == .granted {
            Haptics.play(.success)
            UIApplication.shared.registerForRemoteNotifications()
            await NotifPrefsStore.applyLocal(NotifPrefsStore.load())
            if let hex = UserDefaults.standard.string(forKey: "apnsTokenHex"), SocialFlag.useWorker { await SocialClient.registerDevice(tokenHex: hex) }
        }
    }
    static func post(_ why: NotifAskWhy) { NotificationCenter.default.post(name: .notifAskTrigger, object: why.rawValue) }
}

/// 画面の いちばん 上の 入れ物に 1回 つける(シートを 出す)
struct NotifAskHost: ViewModifier {
    @State private var center = NotifAskCenter.shared
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .notifAskTrigger)) { n in
                if let raw = n.object as? String, let why = NotifAskWhy(rawValue: raw) { Task { await center.trigger(why) } }
            }
            .sheet(item: $center.why) { why in
                NotifAskSheetV111(why: why, onOK: { Task { await center.accept() } }, onLater: { center.later() })
                    .presentationDetents([.height(500)]).presentationDragIndicator(.hidden).presentationCornerRadius(34)
            }
    }
}
extension View { func notifAskHost() -> some View { modifier(NotifAskHost()) } }

// MARK: - 許可の 前の シート(§8-2)

struct NotifAskSheetV111: View {
    let why: NotifAskWhy
    var onOK: () -> Void
    var onLater: () -> Void
    @State private var swing = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill").font(.system(size: 34, weight: .bold)).foregroundStyle(Color(hex: "111113"))
                    .frame(width: 76, height: 76).background(PopColor.pink, in: Circle()).overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .rotationEffect(.degrees(swing ? 12 : -12), anchor: .top)
                Text("1").font(.system(size: 13, weight: .black)).foregroundStyle(Color(hex: "111113")).frame(width: 24, height: 24)
                    .background(PopColor.sun, in: Circle()).overlay(Circle().strokeBorder(.white, lineWidth: 2)).offset(x: 4, y: -2)
            }.padding(.top, 28)
            HStack(spacing: 10) {
                Image("AppIconShare").resizable().scaledToFit().frame(width: 38, height: 38).clipShape(RoundedRectangle(cornerRadius: 38 * 0.224, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Lattag").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                    Text("ようこ が 友だち申請を 承認しました").font(.system(size: 12.5, weight: .medium)).foregroundStyle(.white.opacity(0.7)).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                Text("いま").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.4))
            }
            .padding(12).background(Color(hex: "2A2A2E"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 20).accessibilityHidden(true)
            Text(why.line).font(.system(size: 24, weight: .black)).foregroundStyle(.white).multilineTextAlignment(.center).padding(.top, 4)
            Text(why.sub).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.55)).multilineTextAlignment(.center)
            Spacer(minLength: 6)
            PopButton(title: "オンにする", kind: .lime) { onOK() }.padding(.horizontal, 20)
            Button { Haptics.play(.tick); onLater() } label: {
                Text("あとで").font(.system(size: 15, weight: .bold)).foregroundStyle(.white.opacity(0.6)).frame(maxWidth: .infinity).frame(height: 44)
            }.buttonStyle(.plain).padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "151517"))
        .loopWhileVisible(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: $swing)
        .onAppear { Haptics.play(.pop) }
    }
}

// MARK: - 設定 › お知らせ(§8-3)

struct NotifSettingsV111View: View {
    var onClose: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var perm: NotifPermission = .unset
    @State private var prefs = NotifPrefsStore.load()
    @State private var note: String?
    @State private var busy = false

    private let rows: [(WritableKeyPath<NotifPrefs, Bool>, String, String)] = [
        (\.friend_request, "友だち申請", "だれかが 申請した 時"),
        (\.friend_accepted, "友だちに なった", "相手が 承認した 時"),
        (\.trip_invite, "Trip の 招待", "Trip に よばれた 時"),
        (\.trip_chat, "Trip の チャット", "みんなが 書いた 時"),
        (\.opened, "9:00 ひらいた", "きのうの 写真が ひらいた 時"),
        (\.lastcall, "ラストコール", "23:50 まだ 撮って いない 時"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { Haptics.play(.tick); onClose() } label: { Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44).background(.white.opacity(0.1), in: Circle()) }.buttonStyle(.plain)
                Spacer()
                Text("お知らせ").font(.system(size: 18, weight: .black)).foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }.padding(.horizontal, 16).padding(.top, 14)
            ScrollView {
                VStack(spacing: 16) {
                    permCard
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                            toggle(r.0, r.1, r.2)
                            if i < rows.count - 1 { Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.leading, 16) }
                        }
                    }
                    .background(PopColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .opacity(perm == .on ? 1 : 0.4)
                    Text("お知らせが 届かない 時:iPhone の 設定 › 通知 › Lattag を オン ・ 集中モードを 確かめる")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.4)).multilineTextAlignment(.center).padding(.horizontal, 12)
                }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 40)
            }
        }
        .background(Color(hex: "0A0A0B").ignoresSafeArea())
        .overlay(alignment: .top) {
            if let note {
                Text(note).font(.system(size: 13, weight: .heavy)).foregroundStyle(Color(hex: "111113")).padding(.horizontal, 14).frame(height: 36)
                    .background(PopColor.sun, in: Capsule()).overlay(Capsule().strokeBorder(.white, lineWidth: 2)).padding(.top, 70).transition(.scale.combined(with: .opacity))
            }
        }
        .environment(\.colorScheme, .dark)
        .task { await refresh(); if let remote = await SocialClient.fetchPrefs() { prefs = remote; NotifPrefsStore.save(remote); await NotifPrefsStore.applyLocal(remote) } }
        .onChange(of: scenePhase) { _, p in if p == .active { Task { await refresh() } } }
    }

    private var permCard: some View {
        let (title, line, button): (String, String, String) = {
            switch perm {
            case .unset: return ("まだ 決めて いません", "オンに すると、友だち申請や Trip の 招待を すぐ 受けとれます", "オンにする")
            case .on: return ("オン", "この iPhone に 届きます", "テスト通知を 送る")
            case .off: return ("オフ", "iPhone の 設定で 止まって います", "設定アプリを ひらく")
            }
        }()
        return VStack(spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: perm == .off ? "bell.slash.fill" : "bell.fill").font(.system(size: 24, weight: .bold)).foregroundStyle(Color(hex: "111113"))
                    .frame(width: 56, height: 56).background(perm == .on ? PopColor.lime : (perm == .unset ? PopColor.pink : PopColor.sky), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("お知らせ").font(LF.mono(10)).tracking(2).foregroundStyle(.white.opacity(0.5))
                    Text(title).font(.system(size: 19, weight: .black)).foregroundStyle(.white)
                    Text(line).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            Button { Task { await permAction() } } label: {
                Text(button).font(.system(size: 14, weight: .heavy)).foregroundStyle(perm == .on ? .white : Color(hex: "111113")).frame(maxWidth: .infinity).frame(height: 44)
                    .background(perm == .on ? Color.white.opacity(0.12) : (perm == .unset ? PopColor.lime : PopColor.sky), in: Capsule())
            }.buttonStyle(.plain).disabled(busy)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(PopColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func toggle(_ kp: WritableKeyPath<NotifPrefs, Bool>, _ title: String, _ sub: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 16, weight: .heavy)).foregroundStyle(.white); Text(sub).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(.white.opacity(0.45)) }
            Spacer()
            Toggle("", isOn: Binding(get: { prefs[keyPath: kp] }, set: { v in
                guard perm == .on else { flash("先に お知らせを オンに してね"); return }
                Haptics.play(.click); prefs[keyPath: kp] = v; commit()
            })).labelsHidden().toggleStyle(V87Toggle())
        }.padding(.horizontal, 16).frame(minHeight: 64)
    }

    private func commit() {
        let p = prefs
        NotifPrefsStore.save(p)
        Task { await NotifPrefsStore.applyLocal(p); await SocialClient.savePrefs(p) }
    }

    private func refresh() async { perm = await NotifPermission.current() }

    private func permAction() async {
        busy = true; defer { busy = false }
        Haptics.play(.pop)
        switch perm {
        case .unset:
            let r = await DailyOpenNotification.requestAuthorization(timeout: 20)
            await refresh()
            if r == .granted {
                UIApplication.shared.registerForRemoteNotifications()
                await NotifPrefsStore.applyLocal(prefs)
                if let hex = UserDefaults.standard.string(forKey: "apnsTokenHex"), SocialFlag.useWorker { await SocialClient.registerDevice(tokenHex: hex) }
            }
        case .on:
            flash(await SocialClient.sendTestPush())
        case .off:
            if let u = URL(string: UIApplication.openNotificationSettingsURLString) { await UIApplication.shared.open(u) }
        }
    }

    private func flash(_ t: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { note = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { if note == t { withAnimation { note = nil } } }
    }
}
