import SwiftUI

/// グループ作成完了時に表示する招待リンク共有カード。
/// ダーク背景×緑(#4ade6c)アクセントのブランドトーンに統一し、
/// 「招待リンクを送る」(ShareLink=標準シェアシート)と「リンクをコピー」の2導線を提供する。
/// 導線がバッティングしないよう、閉じる操作(スワイプ/ボタン)は一つだけにし、
/// 呼び出し側(CircleCreateGroupView)の.sheet(onDismiss:)で親画面ごと閉じる。
struct GroupCreatedShareView: View {
    let groupName: String
    let shareURL: URL?
    /// 非nilの場合、カードの下に注意文言を表示する(例: iCloud容量不足で画像だけ
    /// 保存できなかった場合の案内)。通常の成功時はnilのまま。
    var warningMessage: String? = nil
    /// v22 J-2:リンクを もう一度 つくる(失敗したとき)。nil なら「もういちど」は 出さない
    var makeLink: (() async -> URL?)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedToast = false
    @State private var showingShareSheet = false
    /// つくりなおした リンク(CKShare の URL)
    @State private var remadeURL: URL?
    @State private var making = false

    private static let accentGreen = Color.brandGreen
    private static let cardBackground = Color(hex: "1A1A1A")

    /// 標準のhttps://www.icloud.com/share/...のままタップすると、iOS側の判断でアプリでは
    /// なくSafari(iCloudのWebページ)が開いてしまい参加処理に進めないことがあるため、
    /// タップされれば確実にこのアプリが直接開くlater://join?shareUrl=...でラップする
    /// (GroupDetailView.inviteSectionと同じ方針)。
    private var joinLink: URL? {
        guard let shareURL = remadeURL ?? shareURL else { return nil }
        return GroupJoinLink.buildURL(shareURL: shareURL) ?? shareURL
    }

    /// v22 J-2:以前と同じ文面(InviteConfig.shareMessage)
    private var shareMessage: String {
        guard let joinLink else { return "" }
        return InviteConfig.shareMessage(groupName: groupName, url: joinLink)
    }

    var body: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 0)

                card

                if let warningMessage {
                    warningBanner(warningMessage)
                }

                Spacer(minLength: 0)

                Button {
                    dismiss()
                } label: {
                    Text("あとで送る")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)

            if showCopiedToast {
                copiedToast
            }
        }
        .sheet(isPresented: $showingShareSheet, onDismiss: {
            // 共有シート自体が完全に閉じた後に、この画面ごと閉じる。共有シートの
            // completionWithItemsHandlerから直接dismiss()を呼ぶと、共有シートが
            // 閉じきる前に親画面の解放が始まり二重解除のような競合を起こしうるため、
            // 一度showingShareSheetをfalseにしてSwiftUI側の通常の解除を経由させてから
            // onDismissでこの画面を閉じる、という2段階にしている。
            dismiss()
        }) {
            ShareSheet(activityItems: [
                ShareLinkItemSource(text: shareMessage, title: "「\(groupName)」に招待されました。")
            ]) { _ in
                // 共有完了・キャンセルのいずれでも、そのまま留まらせず閉じる。
                showingShareSheet = false
            }
        }
    }

    // MARK: - カード本体

    private var card: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Self.accentGreen.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Self.accentGreen)
            }

            VStack(spacing: 6) {
                Text("グループを作成しました")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text(groupName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            if joinLink != nil {
                linkRow
            } else {
                linkFailedRow
            }

            if joinLink != nil {
                // URLオブジェクトのままShareLinkへ渡すと、LINE等一部アプリの共有シートで
                // 「Cannot issue sandbox extension」エラーになり共有自体が失敗することが
                // あったため、リンクを含むプレーンテキストとして共有する。SwiftUI標準の
                // ShareLinkだとカスタムのLPLinkMetadata(アプリアイコン)・共有完了時の
                // コールバックの両方が取れないため、UIActivityViewControllerを
                // 直接使うShareSheet+ShareLinkItemSourceに変更している。
                Button {
                    HapticsManager.cardChange()
                    showingShareSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                        Text("招待リンクを送る")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Self.accentGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            Button {
                copyToClipboard()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                    Text("リンクをコピー")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Self.accentGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Self.accentGreen.opacity(0.4), lineWidth: 1.5)
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Self.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Self.accentGreen.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)
    }

    private var linkRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Self.accentGreen)

            Text(linkDisplayText)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var linkDisplayText: String {
        joinLink?.absoluteString ?? ""
    }

    /// リンクが できなかった:利用者には やさしい文(灰)。押すと もういちど。長押しで 開発用の詳細
    private var linkFailedRow: some View {
        Button {
            Task { await remake() }
        } label: {
            HStack(spacing: 10) {
                if making {
                    ProgressView().tint(Color(hex: "FF8A2A")).scaleEffect(0.8)
                    Text("リンクを つくっています…").foregroundStyle(Color(hex: "FF8A2A"))
                } else {
                    Image(systemName: "arrow.clockwise").font(.system(size: 13, weight: .semibold))
                    Text("リンクを つくれませんでした。もういちど")
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .disabled(making || makeLink == nil)
        .cloudDiagnosticsOnLongPress()
        .accessibilityHint("長押しで、くわしい内容")
    }

    private func remake() async {
        guard let makeLink, !making else { return }
        making = true
        for i in 0..<3 { DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.18) { Haptics.play(.tick) } }
        let url = await makeLink()
        making = false
        if let url {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { remadeURL = url }
            Haptics.play(.success)
        } else {
            Haptics.play(.warn)
        }
    }

    // MARK: - コピー & トースト

    private func copyToClipboard() {
        guard let joinLink else { return }
        UIPasteboard.general.string = joinLink.absoluteString
        HapticsManager.tick()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.3)) {
                showCopiedToast = false
            }
        }
    }

    /// iCloud容量不足で画像だけ保存できなかった場合などの注意文言。エラーではなく
    /// 「グループ自体は作成できている」ことが伝わるよう、赤ではなくアンバー系にする。
    private func warningBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.orange)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private var copiedToast: some View {
        VStack {
            Spacer()
            Text("リンクをコピーしました")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.black.opacity(0.85)))
                .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .allowsHitTesting(false)
    }
}
