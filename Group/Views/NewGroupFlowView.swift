import SwiftUI
import SwiftData
import PhotosUI
import CloudKit
import UIKit

// MARK: - 合言葉

/// グループの合言葉(例 hikari-2741)。Public DBに「invite_合言葉」のレコードとして登録し、
/// 重複したら発行し直す。参加する側の画面(合言葉を入力する)は別途作る。今は表示と発行だけ。
enum GroupPassphrase {
    private static let words = [
        "hikari", "sora", "kumo", "ame", "umi", "kaze", "hoshi", "tsuki", "mori", "yuki",
        "hana", "nagi", "asa", "yoru", "niji", "kawa", "michi", "tori", "aki", "natsu",
    ]
    private static let maxAttempts = 6

    static func generate() -> String {
        "\(words.randomElement()!)-\(Int.random(in: 1000...9999))"
    }

    /// 合言葉を発行して登録する。共有リンク(CKShareのURL)を合言葉から引けるようにしておく。
    @MainActor
    static func issue(for group: LaterGroup, shareURL: URL?, container: CKContainer) async throws -> String {
        let database = container.publicCloudDatabase
        for _ in 0..<maxAttempts {
            let code = generate()
            let record = CKRecord(recordType: AppRecordType.groupInvite, recordID: CKRecord.ID(recordName: "invite_\(code)"))
            record["shareURL"] = shareURL?.absoluteString
            record["groupID"] = group.id.uuidString
            do {
                // 既に同じ合言葉のレコードがあれば失敗する保存方法で、重複を防ぐ。
                let (results, _) = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged)
                if case .failure(let error) = results[record.recordID] {
                    if let ckError = error as? CKError, ckError.code == .serverRecordChanged { continue }
                    throw error
                }
                return code
            } catch let error as CKError where error.code == .serverRecordChanged {
                continue
            }
        }
        throw GroupSharingError.shareURLMissing
    }
}

// MARK: - グループ作成(4ステップ)

/// グループ作成:① 名前 → ② 写真 → ③ 呼ぶ → ④ できた。下から上がる全画面で開く。
/// 左上の「×」で閉じる(入力中は捨てる。③以降はグループが作成済みなので残る)。
struct NewGroupFlowView: View {
    let onClose: () -> Void

    private enum Step: Int {
        case name = 1, photo, invite, done
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]

    @State private var step: Step = .name
    @State private var name = ""
    @FocusState private var isNameFocused: Bool
    @State private var candidates: [UIImage] = []
    @State private var selectedCandidate: Int?
    @State private var photoData: Data?
    @State private var cropSource: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var createdGroup: LaterGroup?
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var passphrase: String?
    @State private var shareURL: URL?
    @State private var isShowingShare = false
    @State private var didCopy = false
    @State private var haptics = ExposureHaptics()

    private static let nameLimit = 12
    private var currentUser: UserProfile? { UserProfile.current(from: profiles) }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var photo: UIImage? { photoData.flatMap(UIImage.init(data:)) }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            GeometryReader { proxy in
                Ellipse()
                    .fill(RadialGradient(colors: [.white.opacity(0.12), .clear], center: .center, startRadius: 0, endRadius: proxy.size.width * 0.62))
                    .frame(width: proxy.size.width * 1.4, height: 420)
                    .position(x: proxy.size.width / 2, y: -25)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: 0) {
                        content
                            .id(step)
                            .transition(.opacity)
                    }
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.never)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .preferredColorScheme(.dark)
        .overlay {
            FilmGrainOverlay(opacity: 0.05, blendMode: .normal)
                .ignoresSafeArea()
        }
        .onAppear { haptics.prepare() }
        .onDisappear { haptics.tearDown() }
        .sheet(item: Binding(get: { cropSource.map(IdentifiedImage.init) }, set: { cropSource = $0?.image })) { item in
            SquareImageCropView(sourceImage: item.image) { data in
                photoData = Self.resized(data)
                cropSource = nil
            } onCancel: {
                cropSource = nil
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraImagePicker { image in
                isShowingCamera = false
                guard let image else { return }
                candidates.insert(image, at: 0)
                choose(0)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isShowingShare) {
            if let shareURL {
                ShareSheet(activityItems: [GroupJoinLink.buildURL(shareURL: shareURL) ?? shareURL]) { _ in
                    isShowingShare = false
                    go(to: .done)
                }
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    candidates.append(image)
                    choose(candidates.count - 1)
                }
                pickerItem = nil
            }
        }
    }

    // MARK: - 上部

    private var topBar: some View {
        ZStack {
            Text("NEW GROUP ・ \(step.rawValue) / 4")
                .font(.system(size: 10, design: .monospaced))
                .tracking(0.14 * 10)
                .foregroundStyle(.white.opacity(0.45))
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("閉じる")
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .name: nameStep
        case .photo: photoStep
        case .invite: inviteStep
        case .done: doneStep
        }
    }

    // MARK: - ① 名前

    private var nameStep: some View {
        VStack(spacing: 0) {
            GroupDotRing(photo: nil, initial: trimmedName.isEmpty ? "" : String(trimmedName.prefix(1)), memberCount: 1, diameter: 150, photoDiameter: 66)
                .padding(.top, 20)
            heading("グループに、\n名前をつけます。", "みんなに見える名前です。実名や学校名は避けて。")
            VStack(alignment: .leading, spacing: 6) {
                Text("グループの名前")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(Color(hex: "8E8E93"))
                HStack(alignment: .lastTextBaseline) {
                    TextField("", text: $name)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .tint(.white)
                        .focused($isNameFocused)
                        .submitLabel(.next)
                        .onSubmit { if !trimmedName.isEmpty { go(to: .photo) } }
                        .onChange(of: name) { _, value in
                            if value.count > Self.nameLimit { name = String(value.prefix(Self.nameLimit)) }
                        }
                        .accessibilityLabel("グループの名前")
                    Text("\(name.count) / \(Self.nameLimit)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(hex: "8E8E93"))
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 92)
            .background(glassShape(24))
            .padding(.horizontal, 28)
            .padding(.top, 22)

            primaryButton("つぎへ", height: 50, isEnabled: !trimmedName.isEmpty) { go(to: .photo) }
                .padding(.top, 20)
        }
        .onAppear { isNameFocused = true }
    }

    // MARK: - ② 写真

    private var photoStep: some View {
        VStack(spacing: 0) {
            GroupDotRing(photo: photo, initial: String(trimmedName.prefix(1)), memberCount: 1, diameter: 170, photoDiameter: 104)
                .padding(.top, 16)
            heading("グループの、\n顔になる写真を。", "あとから、いつでも変えられます。")

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(78), spacing: 10), count: 4), spacing: 12) {
                Button { isShowingCamera = true } label: {
                    gridCell { Image(systemName: "camera").font(.system(size: 20)).foregroundStyle(.white) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("カメラで撮る")

                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    gridCell { Image(systemName: "photo.on.rectangle").font(.system(size: 20)).foregroundStyle(.white) }
                }
                .accessibilityLabel("写真を選ぶ")

                ForEach(candidates.indices, id: \.self) { index in
                    let isSelected = selectedCandidate == index
                    Button { choose(index) } label: {
                        Image(uiImage: candidates[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 78, height: 78)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white, lineWidth: isSelected ? 2.4 : 0))
                            .overlay(alignment: .topTrailing) {
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white, .black)
                                        .padding(5)
                                }
                            }
                            .opacity(selectedCandidate == nil || isSelected ? 1 : 0.72)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("写真")
                    .accessibilityValue(isSelected ? "選択中" : "")
                    .accessibilityHint("選択")
                }
            }
            .padding(.top, 22)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 14)
            }

            primaryButton(isWorking ? "つくっています…" : "つぎへ", height: 56, isEnabled: !isWorking) { createGroup() }
                .padding(.top, 22)
            Button("写真なしで進む") {
                photoData = nil
                selectedCandidate = nil
                createGroup()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color(hex: "8E8E93"))
            .padding(.top, 12)
            .disabled(isWorking)
        }
    }

    private func gridCell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: 78, height: 78)
            .background(glassShape(16))
    }

    private func choose(_ index: Int) {
        guard candidates.indices.contains(index) else { return }
        selectedCandidate = index
        haptics.playTransient(intensity: 0.5, sharpness: 0.6)
        // 丸くトリミング:ドラッグ+ピンチで位置・大きさを決める(プロフィール写真と同じ操作)。
        cropSource = candidates[index]
    }

    // MARK: - ③ 呼ぶ

    private var inviteStep: some View {
        VStack(spacing: 0) {
            GroupDotRing(photo: photo, initial: String(trimmedName.prefix(1)), memberCount: createdGroup?.members.count ?? 1, diameter: 190, photoDiameter: 112)
                .padding(.top, 16)
            heading("つぎは、\n呼ぶ人を。", "4〜8人。合言葉を送ると、参加できます。")

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("合言葉")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(Color(hex: "8E8E93"))
                    Spacer()
                    if let passphrase {
                        Button(didCopy ? "コピーしました" : "コピー") {
                            UIPasteboard.general.string = passphrase
                            didCopy = true
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    }
                }
                Text(passphrase ?? "発行しています…")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .tracking(0.04 * 28)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel(passphrase.map { "合言葉、" + $0.map(String.init).joined(separator: " ") } ?? "合言葉を発行しています")
                Text("入力した人だけが、参加できます")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }
            .padding(18)
            .frame(height: 104)
            .background(glassShape(22))
            .padding(.horizontal, 28)
            .padding(.top, 22)

            primaryButton("リンクを送る", height: 56, isEnabled: shareURL != nil) { isShowingShare = true }
                .padding(.top, 22)
            Button("あとで送る") { go(to: .done) }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "8E8E93"))
                .padding(.top, 12)
        }
    }

    // MARK: - ④ できた

    private var doneStep: some View {
        let members = createdGroup?.members.count ?? 1
        let groupCount = (currentUser?.groups.filter { !$0.isPersonalSpace }.count) ?? 1
        return VStack(spacing: 0) {
            // ひらく前のこの画面だけ、参加ずみの点を写真の色(オレンジ・青・黄)で光らせる。
            GroupDotRing(
                photo: photo,
                initial: String(trimmedName.prefix(1)),
                memberCount: members,
                diameter: 210,
                photoDiameter: 128,
                dotSize: 6,
                litColor: { index in HomePalette.ringColor(atFraction: Double(index) / Double(GroupDotRing.slotCount)) }
            )
            .padding(.top, 16)
            heading("グループが、\nできました。", "\(trimmedName)\n撮ると、このグループの昨日も、一緒にひらきます。")
            Text("\(members) / 4 参加ずみ ・ グループ \(groupCount) / \(GroupMembershipPolicy.maxGroupsPerUser)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 14)
            primaryButton("Home にもどる", height: 56, isEnabled: true, action: onClose)
                .padding(.top, 24)
        }
        .onAppear { haptics.playTransient(intensity: 0.8, sharpness: 0.7) }
    }

    // MARK: - 共通の部品

    private func heading(_ title: String, _ description: String) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.045 * 26)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            Text(description)
                .font(.system(size: 12.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hex: "BCBBC0"))
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
    }

    private func glassShape(_ radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
    }

    private func primaryButton(_ title: String, height: CGFloat, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(isEnabled ? .black : Color(hex: "8E8E93"))
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(Capsule().fill(isEnabled ? Color.white : Color(hex: "1C1C1E")))
        }
        .buttonStyle(ShrinkPressStyle(scale: 0.97))
        .disabled(!isEnabled)
        .padding(.horizontal, 28)
    }

    private func go(to next: Step) {
        isNameFocused = false
        withAnimation(.easeInOut(duration: reduceMotion ? 0.2 : 0.35)) { step = next }
    }

    // MARK: - 作成

    /// 写真の段階から「つぎへ」で、グループを実際に作成する(既存のGroupSharingService.createGroupを使う)。
    private func createGroup() {
        guard !isWorking, createdGroup == nil else {
            go(to: .invite)
            return
        }
        guard let user = currentUser else { return }
        guard let cloudKitManager = CloudKitManager.current else {
            errorMessage = "iCloudへの接続が完了していません。しばらくしてから、もう一度お試しください。"
            return
        }
        let joinedGroupCount = user.groups.filter { !$0.isPersonalSpace }.count
        guard joinedGroupCount < GroupMembershipPolicy.maxGroupsPerUser else {
            errorMessage = "グループがいっぱいです"
            return
        }

        isWorking = true
        errorMessage = nil
        let group = LaterGroup(name: trimmedName, host: user, autoGenerateMission: false, isPrivate: true)
        group.iconImageData = photoData
        _ = group.addMember(user)
        modelContext.insert(group)

        Task { @MainActor in
            defer { isWorking = false }
            let sharingService = GroupSharingService(container: cloudKitManager.container, modelContext: modelContext, cloudKitManager: cloudKitManager)
            do {
                try await sharingService.createGroup(group, hostProfile: user)
            } catch GroupSharingError.quotaExceeded(groupCreatedWithoutImages: true) {
                // iCloudの容量不足で写真だけ除いて作成できた。グループ自体は作成済み。
                errorMessage = GroupSharingError.quotaExceeded(groupCreatedWithoutImages: true).errorDescription
            } catch {
                modelContext.delete(group)
                errorMessage = (error as? GroupSharingError)?.errorDescription ?? "グループをつくれませんでした。もう一度お試しください。"
                return
            }
            createdGroup = group
            shareURL = group.ckShareURL.flatMap(URL.init(string:))
            go(to: .invite)

            if let code = try? await GroupPassphrase.issue(for: group, shareURL: shareURL, container: cloudKitManager.container) {
                group.inviteCode = code
                try? modelContext.save()
                cloudKitManager.markForUpload(group: group)
                passphrase = code
            }
        }
    }

    /// 端末内で512×512に縮小する(フィルム加工はしない)。
    private static func resized(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let size = CGSize(width: 512, height: 512)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.jpegData(compressionQuality: 0.85) ?? data
    }
}

private struct IdentifiedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// その場で撮るカメラ(グループの写真用。Daily Shotのルールはここには適用しない)。
struct CameraImagePicker: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
