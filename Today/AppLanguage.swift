import SwiftUI
import UIKit

/// アプリの 言語(日本語 / English)。切りかえは iOS の「設定 > Later > 言語」で 行う(Apple 標準)。
/// 日本語・英語 以外の 端末は 英語(開発言語 = English)。
enum AppLanguage {
    /// いま 使っている 言語が 英語か
    static var isEnglish: Bool {
        (Bundle.main.preferredLocalizations.first ?? "en").hasPrefix("en")
    }

    /// 設定の 行に 出す 名前(どちらの 言語でも 同じ 形)
    static var currentName: String { isEnglish ? "English" : "日本語" }

    /// iOS の 設定(このアプリの ページ)を ひらく。言語の 項目は、端末に 2つ 以上の 言語が あるときに 出る
    @MainActor
    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// 設定の「言語 / Language」:日本語 / English(いまの 方に チェック)。えらぶと iOS の 設定を ひらく
struct LanguageSheet: View {
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("settings.language.title")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(.white)
            VStack(spacing: 0) {
                row("日本語", selected: !AppLanguage.isEnglish)
                Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                row("English", selected: AppLanguage.isEnglish)
            }
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.07)))
            Text("settings.language.note")
                .font(.system(size: 12.5))
                .foregroundStyle(Color(hex: "A1A1A8"))
                .fixedSize(horizontal: false, vertical: true)
            Text("settings.language.missing")
                .font(.system(size: 11.5))
                .foregroundStyle(Color(hex: "8E8E93"))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(hex: "111114").ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func row(_ name: String, selected: Bool) -> some View {
        Button {
            Haptics.play(.tick)
            guard !selected else { onClose(); return }
            onClose()
            // iOS の「設定 > Later > 言語」で えらぶ(えらぶと iOS が アプリを 開きなおす)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { AppLanguage.openSystemSettings() }
        } label: {
            HStack {
                Text(verbatim: name).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Color(hex: "FF7A2A"))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
