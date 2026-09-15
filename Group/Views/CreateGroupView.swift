import SwiftUI
import SwiftData
import Photos

/// グループ作成フロー
struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    let onComplete: (LaterGroup) -> Void
    
    @State private var groupName = ""
    @State private var missionText = ""
    @State private var autoGenerateMission = false
    @State private var isPrivate = true
    @State private var currentStep = 1
    @State private var createdGroup: LaterGroup?
    @State private var showingQRCode = false
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isCreatingGroup = false
    @State private var showSuccessAnimation = false
    @State private var isSavingToPhotos = false
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    private var isStepValid: Bool {
        switch currentStep {
        case 1:
            return !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2:
            return true // Mission is optional
        case 3:
            return true // Settings are always valid
        default:
            return false
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress Indicator
                    progressIndicator
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            switch currentStep {
                            case 1:
                                groupNameStep
                            case 2:
                                missionStep
                            case 3:
                                settingsStep
                            case 4:
                                qrCodeStep
                            default:
                                EmptyView()
                            }
                        }
                        .padding(24)
                    }
                    
                    // Bottom Actions
                    bottomActions
                        .padding(20)
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...4, id: \.self) { step in
                if step <= currentStep {
                    Circle()
                        .fill(Color.brandGreen)
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
        }
    }
    
    // MARK: - Step 1: Group Name
    
    private var groupNameStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.brandGreen, .brandGreen.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Name Your Circle")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("Choose a name that represents\nyour group's vibe")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Group Name")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                
                TextField("e.g., Weekend Warriors", text: $groupName)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.brandDarkGray)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                groupName.isEmpty ? Color.white.opacity(0.1) : Color.brandGreen,
                                lineWidth: 1
                            )
                    )
                
                Text("\(groupName.count)/30 characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            
            Spacer()
        }
    }
    
    // MARK: - Step 2: Mission
    
    private var missionStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "target")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.brandGreen, .brandGreen.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Set Daily Mission")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("Optional: Set a daily theme\nfor your group to follow")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Auto-generate toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto-generate Daily Themes")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    
                    Text("System will suggest creative themes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $autoGenerateMission)
                    .tint(.brandGreen)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.brandDarkGray)
            )
            
            if !autoGenerateMission {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Custom Mission (Optional)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    
                    TextField("e.g., Capture something blue", text: $missionText)
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.brandDarkGray)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Step 3: Settings
    
    private var settingsStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.brandGreen, .brandGreen.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Privacy Settings")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("Choose who can find and\njoin your group")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            VStack(spacing: 12) {
                // Private option
                PrivacyOptionCard(
                    icon: "lock.fill",
                    title: "Invite Only",
                    description: "Members can only join via QR code",
                    isSelected: isPrivate
                ) {
                    isPrivate = true
                }
                
                // Public option
                PrivacyOptionCard(
                    icon: "magnifyingglass",
                    title: "Discoverable",
                    description: "Anyone can search and request to join",
                    isSelected: !isPrivate
                ) {
                    isPrivate = false
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Step 4: QR Code
    
    private var qrCodeStep: some View {
        VStack(spacing: 24) {
            // Success Animation
            ZStack {
                if showSuccessAnimation {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.brandGreen)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: showSuccessAnimation ? 80 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showSuccessAnimation)
            
            VStack(spacing: 12) {
                Text("✨ Circle Created!")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                
                Text("招待リンクをシェアしてメンバーを招待しましょう")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, showSuccessAnimation ? 0 : 40)
            
            if let group = createdGroup {
                VStack(spacing: 20) {
                    // QR Code
                    if let qrImage = generateQRCode(for: group) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 250, height: 250)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .brandGreen.opacity(0.3), radius: 20)
                    }
                    
                    // Group info
                    VStack(spacing: 8) {
                        Text(group.name)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        
                        HStack(spacing: 8) {
                            Text("合言葉:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(group.inviteCode)
                                .font(.caption.bold())
                                .foregroundStyle(.brandGreen)
                        }
                        .fontDesign(.monospaced)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.brandDarkGray)
                        )
                    }
                }
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                // Share button
                Button(action: shareInvite) {
                    Label("Share Invite", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.brandGreen)
                        )
                }
                
                // Save to Photos button
                Button(action: saveQRCodeToPhotos) {
                    HStack {
                        if isSavingToPhotos {
                            ProgressView()
                                .tint(.brandGreen)
                        } else {
                            Label("Save Image", systemImage: "arrow.down.circle")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.brandGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.brandGreen, lineWidth: 1.5)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.brandGreen.opacity(0.1))
                            )
                    )
                }
                .disabled(isSavingToPhotos)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if !shareItems.isEmpty {
                ShareSheet(activityItems: shareItems)
            }
        }
    }
    
    // MARK: - Bottom Actions
    
    private var bottomActions: some View {
        HStack(spacing: 12) {
            if currentStep > 1 && currentStep < 4 {
                Button(action: {
                    withAnimation {
                        currentStep -= 1
                    }
                }) {
                    Text("Back")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.brandDarkGray)
                        )
                }
            }
            
            Button(action: handleNext) {
                HStack {
                    if isCreatingGroup {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(currentStep == 4 ? "Done" : "Next")
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isStepValid && !isCreatingGroup ? Color.brandGreen : Color.gray.opacity(0.3))
                )
            }
            .disabled(!isStepValid || isCreatingGroup)
        }
    }
    
    // MARK: - Helpers
    
    private func handleNext() {
        HapticsManager.swipeFeedback()
        
        if currentStep < 3 {
            withAnimation {
                currentStep += 1
            }
        } else if currentStep == 3 {
            // Create the group with loading state
            Task {
                await createGroup()
            }
        } else {
            // Done - 画面を閉じる
            if let group = createdGroup {
                onComplete(group)
            }
            dismiss()
        }
    }
    
    private func createGroup() async {
        guard let user = currentUser else { return }
        
        // Loading state開始
        await MainActor.run {
            isCreatingGroup = true
        }
        
        // グループを作成
        let group = LaterGroup(
            name: groupName,
            host: user,
            autoGenerateMission: autoGenerateMission,
            isPrivate: isPrivate
        )
        
        // カスタムミッションがある場合は設定
        if !missionText.isEmpty {
            group.currentDailyMission = missionText
            group.missionGeneratedDate = Date()
        }
        
        // ホストをメンバーとして追加
        group.members.append(user)
        
        // SwiftDataに保存
        await MainActor.run {
            modelContext.insert(group)
            do {
                try modelContext.save()
                createdGroup = group
                
                // Success animation
                withAnimation {
                    showSuccessAnimation = true
                }
                
                HapticsManager.unlockSuccess()
                
                // アニメーション後にステップ4へ
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation {
                        currentStep = 4
                        isCreatingGroup = false
                    }
                }
            } catch {
                print("Error saving group: \(error)")
                isCreatingGroup = false
            }
        }
    }
    
    private func generateQRCode(for group: LaterGroup) -> UIImage? {
        let qrData = QRCodeGenerator.createGroupQRData(
            groupID: group.id.uuidString,
            groupName: group.name
        )
        return QRCodeGenerator.generateStyledQRCode(from: qrData, size: 512)
    }
    
    private func shareInvite() {
        guard let group = createdGroup else { return }
        
        HapticsManager.swipeFeedback()
        
        // QRコード画像を生成
        guard let qrImage = generateQRCode(for: group) else { return }
        
        // シェアメッセージを作成
        let message = "laterで新しいサークル「\(group.name)」を作りました。合言葉は『\(group.inviteCode)』です。一緒に現像しましょう！"
        
        // シェアアイテムを設定
        shareItems = [message, qrImage]
        showingShareSheet = true
    }
    
    private func saveQRCodeToPhotos() {
        guard let group = createdGroup,
              let qrImage = generateQRCode(for: group) else { return }
        
        HapticsManager.swipeFeedback()
        isSavingToPhotos = true
        
        // カメラロールに保存
        Task {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: qrImage)
                }
                await MainActor.run {
                    isSavingToPhotos = false
                    HapticsManager.unlockSuccess()
                }
            } catch {
                await MainActor.run {
                    isSavingToPhotos = false
                    print("Error saving image: \(error.localizedDescription)")
                    HapticsManager.errorFeedback()
                }
            }
        }
    }
}

// MARK: - Privacy Option Card

struct PrivacyOptionCard: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? .brandGreen : .secondary)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.brandGreen)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.brandGreen.opacity(0.1) : Color.brandDarkGray)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.brandGreen : Color.white.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, LaterGroup.self, configurations: config)
    
    CreateGroupView { group in
        print("Created group: \(group.name)")
    }
    .modelContainer(container)
}
