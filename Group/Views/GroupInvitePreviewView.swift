import SwiftUI
import CloudKit

/// 招待リンクをタップしてアプリが起動した際、実際にCKShareへ参加する前に
/// グループ名・招待者名を確認してもらうための独自の招待画面。
/// 「参加する」が押されるまではCloudKit側には一切アクセスしない
/// (CKAcceptSharesOperationはonAcceptが呼ばれて初めて実行される)。
struct GroupInvitePreviewView: View {
    let metadata: CKShare.Metadata
    /// 実際の参加処理(GroupSharingService.acceptShare)を呼ぶ非同期クロージャ。
    /// 呼び出し元(LaterApp)が、成功/失敗どちらの場合もpendingMetadataをnilにして
    /// この画面自体を閉じる。
    let onAccept: () async -> Void
    let onDecline: () -> Void

    @State private var isAccepting = false

    private var groupName: String {
        (metadata.share[CKShare.SystemFieldKey.title] as? String) ?? "グループ"
    }

    private var inviterName: String {
        let identity = metadata.share.owner.userIdentity
        if let components = identity.nameComponents {
            let formatted = PersonNameComponentsFormatter().string(from: components)
            if !formatted.isEmpty { return formatted }
        }
        if let email = identity.lookupInfo?.emailAddress, !email.isEmpty {
            return email
        }
        return "だれか"
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.brandGreen.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 90
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Color.brandGreen)
            }

            VStack(spacing: 8) {
                Text("\(inviterName)さんから招待されています")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))

                Text(groupName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    isAccepting = true
                    Task { await onAccept() }
                } label: {
                    Group {
                        if isAccepting {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("参加する")
                        }
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.brandGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(isAccepting)

                Button {
                    onDecline()
                } label: {
                    Text("キャンセル")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.vertical, 12)
                }
                .disabled(isAccepting)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brandBlack.ignoresSafeArea())
        .interactiveDismissDisabled(isAccepting)
    }
}
