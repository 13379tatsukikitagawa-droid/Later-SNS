import SwiftUI

/// 撮影前の「キャプション入力」画面(2026/9 新デザイン仕様「②キャプション入力画面」)。
/// 2ステップ中の1ステップ目。キャプションは任意入力で、スキップしても「次へ」でも
/// そのまま撮影画面(③)へ進む。入力した文字列は撮影画面のファインダー上に表示され、
/// 投稿準備画面(PostTargetGroupSelectionView)まで引き継がれる
/// (呼び出し元のTodayView.pendingCaptionが仲介する)。
struct CaptionEntryView: View {
    /// 呼び出し時点の初期値(通常は空文字)。
    var initialCaption: String = ""
    /// 「次へ」またはスキップで確定した文字列を渡して、撮影画面へ進む合図にする。
    let onContinue: (String) -> Void
    let onCancel: () -> Void

    @State private var caption: String
    @FocusState private var isFocused: Bool

    private static let accent = Color.laterAccent
    private static let quickReplies = ["眠い", "最高", "がんばった", "まあまあ", "内緒"]

    init(initialCaption: String = "", onContinue: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.initialCaption = initialCaption
        self.onContinue = onContinue
        self.onCancel = onCancel
        _caption = State(initialValue: initialCaption)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.top, 8)
                .padding(.horizontal, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("STEP 1/2")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Self.accent)
                        .padding(.top, 28)

                    Text("今日をひとことで書いてみよう")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(Color.laterText)

                    Text("書き終えたら、そのまま撮影に進みます")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.laterTextMuted)

                    captionField
                        .padding(.top, 6)

                    quickReplyChips
                }
                .padding(.horizontal, 20)
            }

            Spacer(minLength: 0)

            bottomArea
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .background(Color.laterBackground.ignoresSafeArea())
    }

    // MARK: - トップバー

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.laterText)
                    .frame(width: 36, height: 36)
            }

            Spacer()

            HStack(spacing: 6) {
                Capsule().fill(Self.accent).frame(width: 28, height: 4)
                Capsule().fill(Color.white.opacity(0.15)).frame(width: 28, height: 4)
            }

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
    }

    // MARK: - 入力欄

    private var captionField: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.laterCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Self.accent, lineWidth: 1.5)
                )
                .frame(minHeight: 96)

            if caption.isEmpty {
                Text("今日は忙しかったな…")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.laterTextMuted.opacity(0.7))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
            }

            TextEditor(text: $caption)
                .focused($isFocused)
                .font(.system(size: 16))
                .foregroundStyle(Color.laterText)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 96)
        }
    }

    // MARK: - クイック返信チップ

    private var quickReplyChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Self.quickReplies, id: \.self) { reply in
                    Button {
                        caption = reply
                    } label: {
                        Text(reply)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.laterText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(Color.laterCard))
                            .overlay(Capsule().strokeBorder(Color.laterBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 下部固定領域

    private var bottomArea: some View {
        VStack(spacing: 12) {
            Text("キャプションは今日撮る1枚に焼き付けられます")
                .font(.system(size: 12))
                .foregroundStyle(Color.laterTextMuted)
                .multilineTextAlignment(.center)

            Button {
                isFocused = false
                onContinue(caption)
            } label: {
                HStack(spacing: 8) {
                    Text("次へ・撮影する")
                        .font(.system(size: 16, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Color.laterBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(Self.accent))
            }
            .buttonStyle(.plain)

            Button {
                isFocused = false
                onContinue("")
            } label: {
                Text("あとで書く（スキップ）")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.laterTextMuted)
            }
            .buttonStyle(.plain)
        }
    }
}
