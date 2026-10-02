import SwiftUI
import UIKit

/// タグの入力欄。日本語IMEの変換中(markedTextRangeが非nil)は絶対に確定しないため、
/// SwiftUIのTextFieldではなくUITextFieldを包む。
///
/// 確定の方法:リターン(変換中でない時)/ 半角・全角の空白(変換中でない時)/ キーボード上の「追加」。
/// 貼り付けは空白・改行で分割して、順に確定する。
struct TagInputField: UIViewRepresentable {
    /// 入力中の文字(変換中の文字も含む。候補はこの文字で引く)
    @Binding var text: String
    /// 3つ確定して満杯か(文字は入らず、カーソルも出さない)
    let isFull: Bool
    /// 値が変わるたびにキーボードを開き直す
    let focusTrigger: Int
    let accessibilityLabel: String
    /// 確定の操作があった(整える前の文字を渡す)
    let onCommit: (String) -> Void
    /// 貼り付けで複数のタグが入ってきた
    let onPaste: ([String]) -> Void
    /// 満杯の時に確定しようとした
    let onRejectedWhileFull: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.font = .systemFont(ofSize: 32, weight: .medium)
        field.textColor = .white
        field.tintColor = .white
        field.keyboardAppearance = .dark
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.returnKeyType = .done
        field.enablesReturnKeyAutomatically = false
        field.backgroundColor = .clear
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.inputAccessoryView = context.coordinator.makeAccessoryBar()
        // 画面を開いた瞬間から、キーボードを開いておく。
        DispatchQueue.main.async { field.becomeFirstResponder() }
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        field.tintColor = isFull ? .clear : .white
        field.accessibilityLabel = accessibilityLabel
        if field.markedTextRange == nil, field.text != text {
            field.text = text
        }
        if context.coordinator.lastFocusTrigger != focusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            DispatchQueue.main.async { field.becomeFirstResponder() }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: TagInputField
        var lastFocusTrigger: Int
        private weak var field: UITextField?

        init(_ parent: TagInputField) {
            self.parent = parent
            self.lastFocusTrigger = parent.focusTrigger
        }

        func makeAccessoryBar() -> UIView {
            let bar = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 48))
            bar.backgroundColor = .clear
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.filled()
            configuration.title = "追加"
            configuration.baseBackgroundColor = .white
            configuration.baseForegroundColor = .black
            configuration.cornerStyle = .capsule
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var updated = attributes
                updated.font = .systemFont(ofSize: 14, weight: .bold)
                return updated
            }
            button.configuration = configuration
            button.accessibilityLabel = "タグを追加"
            button.addTarget(self, action: #selector(accessoryAddTapped), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            bar.addSubview(button)
            NSLayoutConstraint.activate([
                button.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
                button.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            ])
            return bar
        }

        @objc private func accessoryAddTapped() {
            guard let field, field.markedTextRange == nil else { return }
            commit(field)
        }

        private func commit(_ field: UITextField) {
            if parent.isFull {
                if !(field.text ?? "").isEmpty { parent.onRejectedWhileFull() }
                return
            }
            parent.onCommit(field.text ?? "")
        }

        @objc func editingChanged(_ field: UITextField) {
            self.field = field
            if field.markedTextRange == nil {
                // 「#」は打っても無視する。1つのタグは16文字まで(超える入力は単に入らない)。
                var value = (field.text ?? "").replacingOccurrences(of: "#", with: "").replacingOccurrences(of: "＃", with: "")
                if value.count > ShootTagRules.maxLength { value = String(value.prefix(ShootTagRules.maxLength)) }
                if value != field.text { field.text = value }
            }
            parent.text = field.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            field = textField
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            field = textField
            let isComposing = textField.markedTextRange != nil
            let current = (textField.text ?? "") as NSString
            let containsSpace = string.rangeOfCharacter(from: .whitespacesAndNewlines) != nil

            // 満杯の時は文字が入らない(削除だけ通す)。確定しようとした時だけ断る。
            if parent.isFull {
                if string.isEmpty { return true }
                if containsSpace && !isComposing { commit(textField) }
                return false
            }

            // 貼り付け:空白・改行で分割して、最大3つまで順に確定する。
            if !isComposing, string.count > 1, containsSpace {
                let combined = current.replacingCharacters(in: range, with: string)
                let parts = combined.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                textField.text = ""
                parent.text = ""
                parent.onPaste(parts)
                return false
            }

            // 空白(変換中でない時)でタグを確定する。変換中の空白は「変換」に使われる。
            if !isComposing, containsSpace {
                let before = current.replacingCharacters(in: range, with: "")
                textField.text = before
                parent.text = before
                commit(textField)
                return false
            }

            if !isComposing {
                let result = current.replacingCharacters(in: range, with: string)
                    .replacingOccurrences(of: "#", with: "").replacingOccurrences(of: "＃", with: "")
                if result.count > ShootTagRules.maxLength { return false }
            }
            return true
        }

        /// 変換中のリターンは「変換の確定」なので、その時はここが呼ばれても確定しない。
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            field = textField
            guard textField.markedTextRange == nil else { return true }
            commit(textField)
            return false
        }
    }
}
