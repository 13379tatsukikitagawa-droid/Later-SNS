import SwiftUI

import SwiftUI

// MARK: - フォロー機能デモ・プレイグラウンド
// このファイルは、フォロー機能をテストするためのデモ画面を提供します。
// 実際のコンポーネントは以下のファイルを使用してください:
// - SimpleFollowButton など: FollowingComponents.swift
// - ModernFollowButton など: ModernFollowButton.swift

/// フォロー機能のデモを統合した画面
struct FollowingFeatureDemo: View {
    @State private var followingManager = FollowingManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // タブ選択
                    Picker("デモ選択", selection: $selectedTab) {
                        Text("シンプル").tag(0)
                        Text("モダン").tag(1)
                        Text("統計").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    // コンテンツ
                    TabView(selection: $selectedTab) {
                        simpleComponentsDemo
                            .tag(0)
                        
                        modernComponentsDemo
                            .tag(1)
                        
                        statisticsDemo
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("フォロー機能デモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("リセット") {
                        followingManager.resetAll()
                    }
                    .foregroundStyle(.red)
                }
            }
        }
    }
    
    // MARK: - シンプルコンポーネントのデモ
    
    private var simpleComponentsDemo: some View {
        ScrollView {
            VStack(spacing: 24) {
                demoSection(title: "SimpleFollowButton") {
                    VStack(spacing: 16) {
                        SimpleFollowButton(userID: "demo1")
                        SimpleFollowButton(userID: "demo2")
                        SimpleFollowButton(userID: "demo3")
                    }
                }
                
                demoSection(title: "FollowingBadge") {
                    VStack(spacing: 12) {
                        HStack {
                            Text("ユーザーA")
                            Spacer()
                            FollowingBadge(userID: "demo1")
                        }
                        HStack {
                            Text("ユーザーB")
                            Spacer()
                            FollowingBadge(userID: "demo2")
                        }
                        HStack {
                            Text("ユーザーC")
                            Spacer()
                            FollowingBadge(userID: "notFollowed")
                        }
                    }
                    .foregroundStyle(.white)
                }
                
                demoSection(title: "UserListItem") {
                    VStack(spacing: 12) {
                        UserListItem(
                            userID: "demo1",
                            userName: "田中太郎",
                            userImage: nil
                        )
                        UserListItem(
                            userID: "demo2",
                            userName: "佐藤花子",
                            userImage: nil
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - モダンコンポーネントのデモ
    
    private var modernComponentsDemo: some View {
        ScrollView {
            VStack(spacing: 24) {
                demoSection(title: "ModernFollowButton") {
                    VStack(spacing: 16) {
                        ModernFollowButton(
                            userID: "demo4",
                            userName: "山田大輔"
                        )
                        ModernFollowButton(
                            userID: "demo5",
                            userName: "中村愛美"
                        )
                    }
                }
                
                demoSection(title: "CompactFollowButton") {
                    HStack(spacing: 16) {
                        CompactFollowButton(userID: "demo6")
                        CompactFollowButton(userID: "demo7")
                        CompactFollowButton(userID: "demo8")
                    }
                }
                
                demoSection(title: "ModernUserListItem") {
                    VStack(spacing: 12) {
                        ModernUserListItem(
                            userID: "demo4",
                            userName: "山田大輔",
                            userImage: nil
                        )
                        ModernUserListItem(
                            userID: "demo5",
                            userName: "中村愛美",
                            userImage: nil
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - 統計情報デモ
    
    private var statisticsDemo: some View {
        ScrollView {
            VStack(spacing: 24) {
                // フォロー状態カード
                followingStatsCard
                
                // アクションボタン
                demoSection(title: "クイックアクション") {
                    VStack(spacing: 12) {
                        Button {
                            followSampleUsers()
                        } label: {
                            Label("サンプルユーザーをフォロー", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Button {
                            followingManager.resetAll()
                        } label: {
                            Label("全てアンフォロー", systemImage: "person.badge.minus")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Button {
                            followingManager.printFollowingList()
                        } label: {
                            Label("コンソールに出力", systemImage: "terminal")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.6))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                
                // フォロー中のユーザー一覧
                followingUsersList
            }
            .padding()
        }
    }
    
    private var followingStatsCard: some View {
        VStack(spacing: 20) {
            // タイトル
            Text("フォロー統計")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            // 統計数値
            HStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text("\(followingManager.followingCount)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.brandGreen)
                    
                    Text("フォロー中")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                VStack(spacing: 8) {
                    Text("\(allDemoUserIDs.count)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                    
                    Text("デモユーザー")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            // プログレスバー
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 12)
                        
                        // プログレス
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [.brandGreen, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * followingProgress,
                                height: 12
                            )
                    }
                }
                .frame(height: 12)
                
                Text("\(Int(followingProgress * 100))% のデモユーザーをフォロー中")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var followingUsersList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("フォロー中のユーザー")
                .font(.headline)
                .foregroundStyle(.white)
            
            if followingManager.followingCount == 0 {
                VStack(spacing: 12) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    
                    Text("まだ誰もフォローしていません")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(followingManager.allFollowingIDs, id: \.self) { userID in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.brandGreen)
                            
                            Text(userID)
                                .font(.body)
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            Button {
                                followingManager.unfollow(userID: userID)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - ヘルパー
    
    private func demoSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
            
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var allDemoUserIDs: [String] {
        ["demo1", "demo2", "demo3", "demo4", "demo5", "demo6", "demo7", "demo8"]
    }
    
    private var followingProgress: Double {
        let demoCount = allDemoUserIDs.count
        guard demoCount > 0 else { return 0 }
        
        let followingDemoCount = allDemoUserIDs.filter { userID in
            followingManager.isFollowing(userID: userID)
        }.count
        
        return Double(followingDemoCount) / Double(demoCount)
    }
    
    private func followSampleUsers() {
        followingManager.followMultiple(userIDs: allDemoUserIDs)
    }
}

// MARK: - インタラクティブデモビュー

/// 各コンポーネントをインタラクティブにテストできるビュー
struct InteractiveComponentTest: View {
    @State private var testUserID = "test-user-1"
    @State private var followingManager = FollowingManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // ユーザーID入力
                        userIDInput
                        
                        // 現在の状態表示
                        currentStateDisplay
                        
                        // テストボタン群
                        testActions
                    }
                    .padding()
                }
            }
            .navigationTitle("インタラクティブテスト")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var userIDInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("テストユーザーID")
                .font(.headline)
                .foregroundStyle(.white)
            
            TextField("ユーザーIDを入力", text: $testUserID)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
        }
    }
    
    private var currentStateDisplay: some View {
        VStack(spacing: 16) {
            HStack {
                Text("現在の状態:")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                if followingManager.isFollowing(userID: testUserID) {
                    Label("フォロー中", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.brandGreen)
                        .font(.subheadline.bold())
                } else {
                    Label("未フォロー", systemImage: "circle")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("総フォロー数: \(followingManager.followingCount)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                
                if !followingManager.allFollowingIDs.isEmpty {
                    Text("フォロー中: \(followingManager.allFollowingIDs.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var testActions: some View {
        VStack(spacing: 12) {
            Button {
                followingManager.follow(userID: testUserID)
            } label: {
                Label("フォローする", systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandGreen)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Button {
                followingManager.unfollow(userID: testUserID)
            } label: {
                Label("フォロー解除", systemImage: "person.badge.minus")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Button {
                followingManager.toggleFollow(userID: testUserID)
            } label: {
                Label("トグル", systemImage: "arrow.left.arrow.right")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - プレビュー

#Preview("フォロー機能デモ") {
    FollowingFeatureDemo()
}

#Preview("インタラクティブテスト") {
    InteractiveComponentTest()
}
