import SwiftUI

/// 投稿先を選ぶ専用画面。以前はPostTargetGroupSelectionView本体に同居していた
/// リスト部分(SetLog風の行デザイン)をそのまま切り出したもの。選択状態は
/// $selectedGroupIDsで呼び出し元(PostTargetGroupSelectionView)と共有する。
struct PostTargetSelectionSheet: View {
    let userGroups: [LaterGroup]
    let currentUser: UserProfile?
    @Binding var selectedGroupIDs: Set<UUID>

    @Environment(\.dismiss) private var dismiss
    /// 「その他」を開いて、上位3件より先のグループも表示しているかどうか。
    @State private var isShowingMoreGroups = false

    private static let otherGroupsRowLimit = 3
    private static let captionAccent = Color.brandGreen
    private static let rowTitleColor = Color(hex: "f5f3ee")
    private static let rowSubtitleColor = Color(hex: "6b6a63")
    private static let rowTrailingIconColor = Color(hex: "4a4a47")
    private static let checkboxBorderColor = Color.white.opacity(0.2)

    private var meGroup: LaterGroup? {
        userGroups.first(where: \.isPersonalSpace)
    }

    private var otherGroups: [LaterGroup] {
        userGroups.filter { !$0.isPersonalSpace }
    }

    private var selectableOtherGroups: [LaterGroup] {
        otherGroups.filter(isSelectable)
    }

    /// 「まだ投稿していない」グループを先頭に並べ替えたもの。デフォルトではこの先頭3件だけ
    /// 表示し(otherGroupsRowLimit)、残りは「その他」を開いた時だけ表示する。
    private var orderedOtherGroups: [LaterGroup] {
        otherGroups.sorted { lhs, rhs in
            let lhsPosted = todaysCount(in: lhs) > 0
            let rhsPosted = todaysCount(in: rhs) > 0
            guard lhsPosted != rhsPosted else { return false }
            return !lhsPosted
        }
    }

    private var visibleOtherGroups: [LaterGroup] {
        isShowingMoreGroups ? orderedOtherGroups : Array(orderedOtherGroups.prefix(Self.otherGroupsRowLimit))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !otherGroups.isEmpty {
                        bulkActionRow
                    }

                    LazyVStack(spacing: 0) {
                        if let meGroup {
                            groupRow(meGroup)
                        }
                        ForEach(visibleOtherGroups, id: \.id) { group in
                            groupRow(group)
                        }
                    }
                    .padding(.top, 4)

                    if orderedOtherGroups.count > Self.otherGroupsRowLimit {
                        moreGroupsToggleRow
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.brandBlack.ignoresSafeArea())
            .navigationTitle("送信先を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                        .foregroundStyle(Self.captionAccent)
                }
            }
        }
    }

    private var moreGroupsToggleRow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingMoreGroups.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Text(isShowingMoreGroups ? "閉じる" : "その他(\(orderedOtherGroups.count - Self.otherGroupsRowLimit))")
                Image(systemName: isShowingMoreGroups ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.brandGreen)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var bulkActionRow: some View {
        HStack(spacing: 16) {
            Button("すべて選択") {
                selectedGroupIDs.formUnion(selectableOtherGroups.map(\.id))
                if let meGroup, isSelectable(meGroup) {
                    selectedGroupIDs.insert(meGroup.id)
                }
            }
            Button("全解除") {
                selectedGroupIDs.subtract(otherGroups.map(\.id))
                if let meGroup {
                    selectedGroupIDs.remove(meGroup.id)
                }
            }
            Spacer()
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.brandGreen)
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    // MARK: - グループ行(MEも含め、全グループを同じ扱いでユーザーが選択/解除できる)

    private func groupRow(_ group: LaterGroup) -> some View {
        let selectable = isSelectable(group)
        let isSelected = selectedGroupIDs.contains(group.id)

        return Button {
            guard selectable else { return }
            if selectedGroupIDs.contains(group.id) {
                selectedGroupIDs.remove(group.id)
            } else {
                selectedGroupIDs.insert(group.id)
            }
            HapticsManager.tick()
        } label: {
            HStack(spacing: 14) {
                selectionCheckbox(isSelected: isSelected)

                squareGroupIcon(group)

                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Self.rowTitleColor)

                    if !selectable {
                        Text(unavailableReason(for: group))
                            .font(.system(size: 12))
                            .foregroundStyle(Self.rowSubtitleColor)
                    }
                }

                Spacer()

                Image(systemName: selectable ? "chevron.right" : "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Self.rowTrailingIconColor)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .opacity(selectable ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!selectable)
    }

    /// SetLog風の選択チェックボックス(行の左端、24x24)。選択中は緑塗り+白いチェック、
    /// 非選択は薄いグレーの枠線のみ。
    private func selectionCheckbox(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? Self.captionAccent : Color.clear)
            Circle()
                .strokeBorder(isSelected ? Color.clear : Self.checkboxBorderColor, lineWidth: 1.5)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 24, height: 24)
    }

    /// このリスト専用の角丸スクエアアイコン(14px角丸)。GroupIconView(円形)は他の
    /// 画面でも共通利用されているため変更せず、ここだけ形状の異なる専用実装にする。
    private func squareGroupIcon(_ group: LaterGroup) -> some View {
        CachedPhotoImage(imageData: group.iconImageData, cacheKey: "groupicon_\(group.id.uuidString)") { uiImage in
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                Color.brandGreen.opacity(0.12)
                if let firstCharacter = group.name.trimmingCharacters(in: .whitespacesAndNewlines).first {
                    Text(String(firstCharacter))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.brandGreen)
                } else {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.brandGreen)
                }
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func unavailableReason(for group: LaterGroup) -> String {
        "本日の上限(\(GroupUnlockPolicy.individualMaximumPhotoCount(for: group))枚)に到達済み"
    }

    // MARK: - 選択状態の判定(PostTargetGroupSelectionView.isSelectable/todaysCountと同じ基準)

    /// 時間帯制限の撤廃に伴い、状態(.shooting/.unlocked)を問わず、現在のサイクルの
    /// 上限枚数に達していなければいつでも撮影できる。
    private func isSelectable(_ group: LaterGroup) -> Bool {
        todaysCount(in: group) < GroupUnlockPolicy.individualMaximumPhotoCount(for: group)
    }

    private func todaysCount(in group: LaterGroup) -> Int {
        guard let myID = currentUser?.id else { return 0 }
        return group.currentCyclePhotos().filter { $0.owner?.id == myID }.count
    }
}
