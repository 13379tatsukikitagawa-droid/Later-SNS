#if DEBUG
import SwiftData
import SwiftUI
import UIKit

/// 3本指で 長押し → 状態メニュー(DEBUG ビルドだけ)。項目は モックの デモボタンと 同じ 名前。
struct DebugStateMenu: View {
    @Environment(\.dismiss) private var dismiss
    @State private var state = DebugState.shared
    @State private var shots = DebugState.shared.shots
    @State private var showPreview = false
    @State private var showVolume = false

    /// (名前, route, 一時の 起動フラグ)
    static let screens: [(String, String, [String: Any])] = [
        ("Friends:はじめて", "friends", ["debugFriendsMode": "first"]),
        ("Friends:友だち 0人", "friends", ["debugFriendsMode": "nofriends"]),
        ("Friends:自分の きのう なし", "friends", ["debugFriendsMode": "noown"]),
        ("Mondo:投稿 なし", "yesterday", ["debugTab": 1, "debugMondo": "empty"]),
        ("ひらく(新)", "reveal", [:]),
        ("音楽:つなぐ まえ", "music", [:]),
        ("設定", "settings", [:]),
        ("QR(チェキ)", "qr", [:]),
        ("プロフィール 編集", "profileedit", [:]),
        ("現像", "develop", [:]),
        ("Trip を つくる", "trip", [:]),
    ]

    @MainActor static func open(_ item: (String, String, [String: Any])) {
        let d = UserDefaults.standard
        for (k, v) in item.2 { d.set(v, forKey: k) }
        if let url = URL(string: "lattag://debug/\(item.1)") { _ = DebugRouter.handle(url) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { for k in item.2.keys { d.removeObject(forKey: k) } }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("今日 撮った 枚数") {
                    Picker("枚数", selection: $shots) {
                        ForEach(0...3, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: shots) { _, v in state.setShots(v) }
                }
                Section("状態") {
                    Toggle("はじめての 日(⇄ いつも)", isOn: $state.firstDay)
                    Picker("ともだち", selection: $state.friends) {
                        Text("0人").tag(0); Text("3人").tag(3)
                    }.pickerStyle(.segmented)
                    Toggle("申請が とどく", isOn: $state.requests)
                    Toggle("Trip を つくる(見本の Trip)", isOn: $state.trip)
                    Toggle("招待が とどく", isOn: $state.invite)
                    Toggle("翌朝 9:00 に する", isOn: $state.nextMorning)
                    Toggle("見本データを 使う(写真・友だち・Mondo)", isOn: $state.sampleData)
                }
                Section("昼 ⇄ 夜") {
                    Picker("テーマ", selection: Binding(get: { state.theme }, set: { state.setTheme($0) })) {
                        Text("自動").tag(ThemeOverride.automatic)
                        Text("昼").tag(ThemeOverride.day)
                        Text("夜").tag(ThemeOverride.night)
                    }.pickerStyle(.segmented)
                }
                Section("やりなおし") {
                    Button("オープニングを もう一度") { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { state.replayOpening() } }
                    Button("はじめての 設定を もう一度") { state.replayOnboarding(); dismiss() }
                    Button("ぜんぶ 最初から", role: .destructive) { state.resetAll(); shots = 0 }
                }
                Section("はじめての 設定の 画面へ(O03〜O11)") {
                    ForEach(["intro", "in", "mail", "sent", "name", "id", "tag", "fr", "nt", "go"], id: \.self) { step in
                        Button(step) { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { state.jumpToOnboarding(step) } }
                    }
                }
                Section("新しい Home(V64)") {
                    Toggle("V64 の Home を つかう(切りかえたら 再起動)", isOn: Binding(get: { UIFlag.v64 }, set: { UserDefaults.standard.set($0, forKey: UIFlag.v64Key) }))
                }
                Section("画面を ひらく(見本どおりの 状態)") {
                    ForEach(DebugStateMenu.screens, id: \.0) { item in
                        Button(item.0) { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { DebugStateMenu.open(item) } }
                    }
                }
                Section("データの 量(v106)") {
                    Button("データの 量を 見る") { showVolume = true }
                }
                Section("確かめる") {
                    Button("書体 ・ バイブ ・ ガラス の プレビュー") { showPreview = true }
                }
            }
            .navigationTitle("DEBUG 状態メニュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
            .sheet(isPresented: $showPreview) { DesignSystemPreview() }
            .sheet(isPresented: $showVolume) { DebugDataVolumeView().modelContainer(LaterApp.sharedModelContainer) }
        }
    }
}

/// 3本指 長押しの 取りつけ(アプリの ウィンドウに 1つ)
@MainActor
enum DebugMenuInstaller {
    private static var installed = false
    private static let handler = Handler()

    static func install() {
        guard !installed else { return }
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }
            let g = UILongPressGestureRecognizer(target: handler, action: #selector(Handler.fire(_:)))
            g.numberOfTouchesRequired = 3
            g.minimumPressDuration = 0.6
            g.cancelsTouchesInView = false
            window.addGestureRecognizer(g)
            installed = true
        }
    }

    private final class Handler: NSObject {
        @objc func fire(_ g: UILongPressGestureRecognizer) {
            guard g.state == .began else { return }
            Task { @MainActor in
                guard var top = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first?.rootViewController else { return }
                while let p = top.presentedViewController { top = p }
                if top is UIHostingController<DebugStateMenu> { return }
                Haptics.play(.pop)
                top.present(UIHostingController(rootView: DebugStateMenu()), animated: true)
            }
        }
    }
}
#endif
