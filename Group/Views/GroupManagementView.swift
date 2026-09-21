import SwiftUI
import SwiftData

/// 🎪 グループ管理・作成・招待画面
struct GroupManagementView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]
    
    @State private var showCreateGroup = false
    @State private var showJoinGroup = false
    @State private var showInviteSheet = false
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    private var myGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // アクションボタン
                        actionButtons
                        
                        // 参加中のグループ
                        if !myGroups.isEmpty {
                            groupList
                        } else {
                            emptyState
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("グループ管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView { group in
                    // Group created successfully
                    HapticsManager.unlockSuccess()
                }
            }
            .sheet(isPresented: $showJoinGroup) {
                JoinGroupView()
            }
            .sheet(isPresented: $showInviteSheet) {
                if let group = myGroups.first {
                    InviteToGroupView(group: group)
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // グループ作成
            Button {
                showCreateGroup = true
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 40))
                    
                    Text("グループ作成")
                        .font(.headline)
                }
                .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.15))
                )
            }
            
            // グループ参加
            Button {
                showJoinGroup = true
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.plus.fill")
                        .font(.system(size: 40))
                    
                    Text("グループ参加")
                        .font(.headline)
                }
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.6))
                )
            }
        }
    }
    
    // MARK: - Group List
    
    private var groupList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("参加中のグループ")
                .font(.title3.bold())
                .foregroundStyle(.white)
            
            ForEach(myGroups) { group in
                GroupManagementCard(
                    group: group,
                    isHost: group.host?.id == currentUser?.id,
                    onInvite: {
                        showInviteSheet = true
                    }
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("まだグループに参加していません")
                .font(.title3)
                .foregroundStyle(.white)
            
            Text("新しいグループを作成するか、\n招待コードを使って既存のグループに参加してください")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Group Card

struct GroupManagementCard: View {
    let group: LaterGroup
    let isHost: Bool
    let onInvite: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    
                    Text("\(group.members.count)人のメンバー")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                if isHost {
                    Text("ホスト")
                        .font(.caption.bold())
                        .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.5))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.2))
                        )
                }
            }
            
            // 招待コード
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("招待コード")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Text(group.inviteCode)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.5))
                }
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = group.inviteCode
                    HapticsManager.swipeFeedback()
                } label: {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            
            // 招待ボタン
            if isHost {
                Button {
                    onInvite()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("友達を招待")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.8))
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.4))
        )
    }
}


// MARK: - Join Group View

struct JoinGroupView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]
    
    @State private var inviteCode = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08)
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.5))
                    
                    VStack(spacing: 16) {
                        Text("グループに参加")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        
                        Text("招待コードを入力して\nグループに参加しましょう")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    
                    // 招待コード入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text("招待コード")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white.opacity(0.8))
                        
                        TextField("6文字のコードを入力", text: $inviteCode)
                            .textFieldStyle(.plain)
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .textCase(.uppercase)
                            .autocorrectionDisabled()
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.6))
                            )
                        
                        if showError {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                    
                    // 参加ボタン
                    Button {
                        joinGroup()
                    } label: {
                        Text("参加")
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.05, green: 0.05, blue: 0.08))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.2, green: 0.8, blue: 0.5))
                            )
                    }
                    .disabled(inviteCode.isEmpty)
                    .opacity(inviteCode.isEmpty ? 0.5 : 1.0)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("グループ参加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }
    
    private func joinGroup() {
        guard let user = currentUser else { return }
        
        // グループを検索
        if let group = groups.first(where: { $0.inviteCode.uppercased() == inviteCode.uppercased() }) {
            // 既に参加しているかチェック
            if group.members.contains(where: { $0.id == user.id }) {
                errorMessage = "既にこのグループに参加しています"
                showError = true
                return
            }
            
            // グループに参加
            group.members.append(user)
            try? context.save()
            
            HapticsManager.unlockSuccess()
            dismiss()
        } else {
            errorMessage = "無効な招待コードです"
            showError = true
            HapticsManager.errorFeedback()
        }
    }
}

// MARK: - Invite to Group View

struct InviteToGroupView: View {
    @Environment(\.dismiss) private var dismiss
    let group: LaterGroup
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08)
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // QRコード風の表示（簡略版）
                    VStack(spacing: 24) {
                        Text(group.name)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        
                        // 招待コード
                        Text(group.inviteCode)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.5))
                            .padding(.horizontal, 32)
                            .padding(.vertical, 24)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.8))
                            )
                        
                        Text("このコードを友達に共有してください")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // シェアボタン
                    ShareLink(
                        item: "Laterグループ「\(group.name)」に参加しよう！招待コード: \(group.inviteCode)",
                        subject: Text("Laterグループ招待"),
                        message: Text("招待コード: \(group.inviteCode)")
                    ) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("招待リンクを共有")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.2, green: 0.8, blue: 0.5))
                        )
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("グループ招待")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }
}

#Preview {
    GroupManagementView()
        .modelContainer(for: [LaterPhoto.self, UserProfile.self, LaterGroup.self])
}
