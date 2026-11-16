#if DEBUG
import SwiftUI
import UIKit

/// 3本指で 長押し → 状態メニュー(DEBUG ビルドだけ)。項目は モックの デモボタンと 同じ 名前。
struct DebugStateMenu: View {
    @Environment(\.dismiss) private var dismiss
    @State private var state = DebugState.shared
    @State private var shots = DebugState.shared.shots
    @State private var showPreview = false

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
                Section("確かめる") {
                    Button("書体 ・ バイブ ・ ガラス の プレビュー") { showPreview = true }
                }
            }
            .navigationTitle("DEBUG 状態メニュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
            .sheet(isPresented: $showPreview) { DesignSystemPreview() }
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
