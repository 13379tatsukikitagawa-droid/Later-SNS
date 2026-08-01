import SwiftUI
import SwiftData

// MARK: - Circle Management View (グループ管理画面)
/// 所属するCircle（グループ）の管理、新規作成、招待共有を一元管理

struct CircleManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]
    
    @State private var showCreateGroup = false
    @State private var selectedGroup: LaterGroup?
    @State private var showGroupDetail = false
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    // ユーザーが所属しているグループ
    private var userGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { group in
            group.members.contains(where: { $0.id == user.id })
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                LiquidBackgroundView()
                    .opacity(0.2)
                
                if userGroups.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // グループカードリスト
                            ForEach(userGroups, id: \.id) { group in
                                CircleCard(group: group) {
                                    selectedGroup = group
                                    showGroupDetail = true
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Circles")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateGroup = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Text("Create")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(Color.brandGreen)
                    }
                }
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView { newGroup in
                    showCreateGroup = false
                }
            }
            .sheet(isPresented: $showGroupDetail) {
                if let group = selectedGroup {
                    CircleDetailView(group: group)
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "circle.hexagongrid")
                .font(.system(size: 80))
                .foregroundStyle(Color.brandGreen.opacity(0.4))
                .symbolEffect(.pulse)
            
            VStack(spacing: 12) {
                Text("まだCircleがありません")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("友達とグループを作成して\n一緒に写真を現像しましょう")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            Button {
                showCreateGroup = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("最初のCircleを作成")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.brandGreen, Color.brandGreen.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color.brandGreen.opacity(0.4), radius: 12, x: 0, y: 6)
            }
        }
        .padding()
    }
}

// MARK: - Circle Card
struct CircleCard: View {
    let group: LaterGroup
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                // ヘッダー
                HStack {
                    // グループアイコン
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.brandGreen.opacity(0.8),
                                        Color.blue.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "circle.hexagongrid.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    
                    // グループ情報
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                        
                        HStack(spacing: 8) {
                            // メンバー数
                            Label("\(group.members.count)", systemImage: "person.2.fill")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.brandGreen)
                            
                            // プライバシー
                            if group.isPrivate {
                                Label("Private", systemImage: "lock.fill")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 矢印アイコン
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                // ミッション
                if !group.missionText.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.brandGreen.opacity(0.8))
                        
                        Text(group.missionText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                
                // 統計情報
                HStack(spacing: 20) {
                    StatItem(icon: "photo.fill", value: "\(group.photos.count)", label: "Photos")
                    StatItem(icon: "calendar", value: "\(daysActive)", label: "Days")
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var daysActive: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: group.createdAt, to: Date()).day ?? 0
        return max(1, days)
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.brandGreen)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
            }
        }
    }
}

// MARK: - Circle Detail View
struct CircleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let group: LaterGroup
    
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // グループヘッダー
                        groupHeader
                        
                        // 招待セクション
                        inviteSection
                        
                        // メンバーリスト
                        membersSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandGreen)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if #available(iOS 16.0, *) {
                    ActivityViewController(items: shareItems)
                }
            }
        }
    }
    
    // MARK: - Group Header
    private var groupHeader: some View {
        VStack(spacing: 16) {
            // グループアイコン
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.brandGreen.opacity(0.8),
                                Color.blue.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            // グループ名
            Text(group.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            
            // ミッション
            if !group.missionText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.brandGreen)
                    
                    Text(group.missionText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
            }
            
            // 統計
            HStack(spacing: 32) {
                VStack(spacing: 6) {
                    Text("\(group.members.count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.brandGreen)
                    
                    Text("Members")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .textCase(.uppercase)
                }
                
                VStack(spacing: 6) {
                    Text("\(group.photos.count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.brandGreen)
                    
                    Text("Photos")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .textCase(.uppercase)
                }
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
    
    // MARK: - Invite Section
    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("招待")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            
            // 合言葉
            VStack(spacing: 12) {
                HStack {
                    Text("合言葉")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Spacer()
                }
                
                HStack {
                    Text(group.inviteCode)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.brandGreen)
                    
                    Spacer()
                    
                    Button {
                        UIPasteboard.general.string = group.inviteCode
                        HapticsManager.swipeFeedback()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.brandGreen)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.brandGreen.opacity(0.15))
                            )
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            
            // シェアボタン
            Button {
                shareInvite()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("招待リンクをシェア")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.brandGreen, Color.brandGreen.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.brandGreen.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
    }
    
    // MARK: - Members Section
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("メンバー")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            
            LazyVStack(spacing: 12) {
                ForEach(group.members, id: \.id) { member in
                    MemberCard(member: member)
                }
            }
        }
    }
    
    // MARK: - Share Invite
    private func shareInvite() {
        HapticsManager.swipeFeedback()
        
        // QRコード生成
        let qrData = QRCodeGenerator.createGroupQRData(
            groupID: group.id.uuidString,
            groupName: group.name
        )
        guard let qrImage = QRCodeGenerator.generateStyledQRCode(from: qrData, size: 512) else {
            return
        }
        
        // シェアメッセージ
        let message = "laterで新しいサークル「\(group.name)」を作りました。合言葉は『\(group.inviteCode)』です。一緒に現像しましょう！"
        
        shareItems = [message, qrImage]
        showShareSheet = true
    }
}

// MARK: - Member Card
struct MemberCard: View {
    let member: UserProfile
    
    var body: some View {
        HStack(spacing: 12) {
            // プロフィール画像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.7),
                                Color.purple.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Text(String(member.name.prefix(1).uppercased()))
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            
            // ユーザー情報
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text("@\(member.name.lowercased())")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Activity View Controller (Share Sheet)
struct ActivityViewController: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview
#Preview {
    CircleManagementView()
        .modelContainer(for: [LaterPhoto.self, UserProfile.self, LaterGroup.self])
}
