import SwiftUI

/// 投票画面・結果画面・Home画面で共通して使う、グループ切り替え用のヘッダー。
/// 見た目と開閉・切り替えの配線だけを持つ「賢くない」コンポーネントで、
/// 状態判定ロジック(GroupUnlockPolicy/VotingManager)への依存はこのファイル内に閉じる。
struct GroupSwitcherHeader: View {
    let groups: [LaterGroup]
    @Binding var selectedGroupID: UUID?
    /// 「戻る」が意味を持たない画面(Homeタブのルートなど)ではnilにしてアイコンごと隠す
    var onBack: (() -> Void)?

    @State private var isExpanded = false
    @State private var showingMembers = false
    @State private var showingComingSoonAlert = false

    private var selectedGroup: LaterGroup? {
        groups.first { $0.id == selectedGroupID } ?? groups.first
    }

    var body: some View {
        HStack {
            if let onBack {
                iconButton(systemName: "chevron.left", action: onBack)
            } else {
                Color.clear.frame(width: 36, height: 36)
            }

            Spacer()

            pillButton

            Spacer()

            iconButton(systemName: "ellipsis") {
                // Menuはlabelタップで自動的に開くため、ここでは何もしない
            }
            .overlay(moreMenu)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            if isExpanded {
                expandedOverlay
            }
        }
        .sheet(isPresented: $showingMembers) {
            CircleManagementView()
        }
        .alert("準備中", isPresented: $showingComingSoonAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("この機能は近日対応予定です")
        }
        // このヘッダーは親のVStack内で一番先に宣言される(=デフォルトのz順では
        // 一番背面)ことが多く、展開時の候補一覧(expandedOverlay)が下に続く
        // コンテンツ(TabView等)の後ろに隠れてしまっていた。zIndexを明示的に
        // 上げて、常に他の兄弟要素より手前に描画されるようにする。
        .zIndex(1)
    }

    // MARK: - アイコンボタン

    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
    }

    /// 「その他メニュー」。メンバー一覧は既存画面に暫定的に繋ぎ、設定/退出は
    /// CloudKit側の同期が未整備のため「準備中」の土台だけ用意する。
    private var moreMenu: some View {
        Menu {
            Button {
                showingMembers = true
            } label: {
                Label("メンバーを見る", systemImage: "person.2")
            }
            Button {
                showingComingSoonAlert = true
            } label: {
                Label("グループ設定", systemImage: "gearshape")
            }
            Button(role: .destructive) {
                showingComingSoonAlert = true
            } label: {
                Label("グループを退出", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Color.clear.frame(width: 36, height: 36)
        }
    }

    // MARK: - ピルボタン

    private var pillButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedGroup?.name ?? "グループ")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .foregroundStyle(isExpanded ? Color.black : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isExpanded ? Color.brandGreen : Color.white.opacity(0.1))
            )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }

    // MARK: - 展開時のオーバーレイ・パネル

    private var expandedOverlay: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                }

            groupListPanel
                .padding(.top, 54)
                .padding(.horizontal, 40)
        }
        .transition(.opacity)
    }

    private var groupListPanel: some View {
        VStack(spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                Button {
                    selectedGroupID = group.id
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(group.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                            Text(statusLine(for: group))
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.55))
                        }

                        Spacer()

                        if group.id == selectedGroup?.id {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.brandGreen)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < groups.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 0.5)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - 状態1行の生成

    /// GroupStatusPresenter(共通ロジック)に委譲する。以前はここで独自に同じ判定を
    /// 実装しており、Home画面のグループ一覧・GroupHomeDetailViewと重複していたため一本化した。
    private func statusLine(for group: LaterGroup) -> String {
        switch GroupStatusPresenter.state(for: group) {
        case .unlocked:
            return "解禁中"
        case .shooting(let hasStarted, let achievedCount, let memberCount, _, _):
            if !hasStarted { return "未スタート" }
            return "\(achievedCount)/\(memberCount)人 撮影済み"
        }
    }
}
