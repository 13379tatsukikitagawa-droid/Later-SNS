import SwiftUI

/// グループ一覧画面(2026/9 新デザイン仕様「④グループ一覧画面」)。Home画面の
/// 「すべて見る」から遷移する。最大10グループまで作成できる仕組みを可視化する。
/// ME(個人用スペース)はここには含めない(HomeのDaily Shotカードが専任)。
struct GroupListView: View {
    let groups: [LaterGroup]
    let onCreateGroup: () -> Void

    @Environment(\.dismiss) private var dismiss
    private static let accent = Color.laterAccent
    private static var maxCount: Int { GroupMembershipPolicy.maxGroupsPerUser }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 12)

            progressBar
                .padding(.horizontal, 20)
                .padding(.top, 14)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(groups, id: \.id) { group in
                        NavigationLink {
                            GroupHomeDetailView(group: group)
                        } label: {
                            groupRow(group)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)

                VStack(spacing: 10) {
                    createButton
                    Text(footerText)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.laterTextMuted)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .background(Color.laterBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - トップバー

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.laterText)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Text("グループ")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Color.laterText)

            Spacer()

            Text("\(groups.count) / \(Self.maxCount)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Self.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.laterCard))
        }
    }

    // MARK: - 進捗バー

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(Self.accent)
                    .frame(width: geometry.size.width * min(1, Double(groups.count) / Double(Self.maxCount)))
            }
        }
        .frame(height: 6)
    }

    // MARK: - グループ行

    private func groupRow(_ group: LaterGroup) -> some View {
        let isInProgress = isGroupInProgress(group)
        return HStack(spacing: 14) {
            overlappingAvatars(group)

            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.laterText)
                Text(statusText(group))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isInProgress ? Self.accent : Color.laterTextMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.laterTextMuted)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.laterCard))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isInProgress ? Self.accent.opacity(0.7) : Color.white.opacity(0.08), lineWidth: isInProgress ? 1.5 : 1)
        )
    }

    /// メンバーの重なりアバター(最大4人まで表示し、残りは「+N」で表す)。
    private func overlappingAvatars(_ group: LaterGroup) -> some View {
        let members = group.members
        let visibleCount = 4
        let visibleMembers = Array(members.prefix(visibleCount))
        let remaining = max(0, members.count - visibleCount)

        return HStack(spacing: -12) {
            ForEach(Array(visibleMembers.enumerated()), id: \.element.id) { _, member in
                CachedPhotoImage(
                    imageData: member.profileImageData,
                    cacheKey: "avatar_grouplist_\(member.id.uuidString)"
                ) { uiImage in
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ZStack {
                        Self.accent.opacity(0.2)
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Self.accent)
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.laterCard, lineWidth: 2))
            }

            if remaining > 0 {
                ZStack {
                    Circle().fill(Color.black.opacity(0.4))
                    Text("+\(remaining)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.laterText)
                }
                .frame(width: 32, height: 32)
                .overlay(Circle().strokeBorder(Color.laterCard, lineWidth: 2))
            }
        }
    }

    private func isGroupInProgress(_ group: LaterGroup) -> Bool {
        if case .shooting(let hasStarted, _, _, _, _) = GroupStatusPresenter.state(for: group) {
            return hasStarted
        }
        return false
    }

    private func statusText(_ group: LaterGroup) -> String {
        switch GroupStatusPresenter.state(for: group) {
        case .shooting(let hasStarted, let achievedCount, let memberCount, _, _):
            guard hasStarted else { return "未スタート" }
            return "\(achievedCount)/\(memberCount) READY・もうすぐ公開"
        case .unlocked:
            return "解禁中"
        }
    }

    // MARK: - 作成ボタン

    private var isAtLimit: Bool { groups.count >= Self.maxCount }

    private var createButton: some View {
        Button {
            onCreateGroup()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text(isAtLimit ? "上限に達しました" : "＋ 新しいグループを作る")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(isAtLimit ? Color.laterTextMuted : Color.laterBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(isAtLimit ? Color.white.opacity(0.08) : Self.accent))
        }
        .buttonStyle(.plain)
        .disabled(isAtLimit)
    }

    private var footerText: String {
        isAtLimit ? "上限に達しました" : "あと\(Self.maxCount - groups.count)個作成できます"
    }
}
