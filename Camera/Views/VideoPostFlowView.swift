//
//  VideoPostFlowView.swift
//  Later 再度
//
//  動画専用の投稿準備画面。写真のPostTargetGroupSelectionView(BeReal+setlog融合UI、
//  キャプション入力→投稿先グループ選択→送信を1画面にまとめた構成)と同じ考え方だが、
//  Viewとしては独立させている。写真にある「現像中」の段階的な質感変化の演出は動画には
//  一切適用せず、サムネイルをそのまま表示する(要件)。
//

import SwiftUI
import SwiftData

struct VideoPostFlowView: View {
    /// FilmEmulationVideoExporterが書き出した加工済み.mp4の一時ファイルURL。
    let videoURL: URL
    let thumbnail: UIImage?
    let durationSeconds: Double
    var locationName: String? = nil
    let onFinished: (_ success: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]

    @State private var caption: String = ""
    @State private var isEditingCaption = false
    @FocusState private var isCaptionFocused: Bool
    @State private var selectedGroupIDs: Set<UUID> = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var isShowingDestinationPicker = false

    private static let chekiFrameColor = Color(red: 0.969, green: 0.961, blue: 0.933) // #f7f5ee
    private static let captionAccent = Color.brandGreen
    private static let captionPlaceholderColor = Color(hex: "d8d6cf")
    private static let captionTextColor = Color(hex: "f5f3ee")

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    private var userGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }.meFirstOrdered()
    }

    private var meGroup: LaterGroup? {
        userGroups.first(where: \.isPersonalSpace)
    }

    /// 動画も写真と同じ枚数カウント対象・上限になる(仕様変更)。時間帯制限の撤廃に伴い
    /// 状態を問わずいつでも投稿でき、写真+動画の合算枚数が上限未満であることだけを見る
    /// (PostTargetGroupSelectionView.isSelectableと同じ考え方)。
    private func isSelectable(_ group: LaterGroup) -> Bool {
        guard let myID = currentUser?.id else { return false }
        return group.currentCycleContentCount(ownerID: myID) < GroupUnlockPolicy.individualMaximumPhotoCount(for: group)
    }

    private var selectableGroups: [LaterGroup] {
        userGroups.filter(isSelectable)
    }

    var body: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
                .onTapGesture { isCaptionFocused = false }

            VStack(spacing: 0) {
                header

                Divider().background(Color.white.opacity(0.08))

                ScrollView {
                    videoPreview
                        .padding(.top, 24)
                        .padding(.bottom, 12)
                }
                .scrollDismissesKeyboard(.interactively)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.red.opacity(0.85))
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                }

                submitButton
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            initializeSelectionIfNeeded()
        }
        .sheet(isPresented: $isShowingDestinationPicker) {
            PostTargetSelectionSheet(
                userGroups: userGroups,
                currentUser: currentUser,
                selectedGroupIDs: $selectedGroupIDs
            )
        }
    }

    // MARK: - ヘッダー

    private var header: some View {
        HStack {
            Button {
                cleanupLocalFileIfNeeded()
                onFinished(false)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }

            Spacer()

            Text("動画を投稿")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            destinationButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var destinationButton: some View {
        Button {
            isShowingDestinationPicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(selectedGroupIDs.count)件")
                    .font(.system(size: 15, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Self.captionAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Self.captionAccent.opacity(0.12)))
            .overlay(Capsule().strokeBorder(Self.captionAccent, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 動画プレビュー(「現像中」演出なし。サムネイルをそのまま明るく表示する)

    private var videoPreview: some View {
        VStack(spacing: 0) {
            thumbnailArea
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .padding(14)

            HStack {
                Image(systemName: "video.fill")
                    .font(.system(size: 12, weight: .medium))
                Text(String(format: "%.0f秒の動画", durationSeconds.rounded()))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(Color.black.opacity(0.5))
            .frame(height: 48)
        }
        .background(Self.chekiFrameColor)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 22, x: 0, y: 10)
        .padding(.horizontal, 8)
    }

    private var thumbnailArea: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.black.opacity(0.6)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { isCaptionFocused = false }

            Image(systemName: "play.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.85))
                .shadow(radius: 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

            captionOverlay
                .padding(14)
        }
        .clipped()
    }

    // MARK: - キャプション入力(写真のPostTargetGroupSelectionViewと同じUIパターンを踏襲)

    private var captionOverlay: some View {
        Group {
            if isEditingCaption {
                TextField("キャプションを入力", text: $caption)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Self.captionTextColor)
                    .tint(Self.captionAccent)
                    .focused($isCaptionFocused)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: 240, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial))
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.65)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Self.captionAccent, lineWidth: 1))
            } else {
                Button {
                    isEditingCaption = true
                    DispatchQueue.main.async {
                        isCaptionFocused = true
                    }
                } label: {
                    HStack(spacing: 5) {
                        if caption.isEmpty {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(caption.isEmpty ? "キャプション" : caption)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Self.captionPlaceholderColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: 240, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial))
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.5)))
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: isCaptionFocused) { _, focused in
            if !focused {
                isEditingCaption = false
            }
        }
    }

    // MARK: - 送信ボタン

    private var submitButton: some View {
        Button(action: submitPost) {
            Group {
                if isSubmitting {
                    ProgressView().tint(.black)
                } else {
                    Text("送信する")
                }
            }
            .font(.headline)
            .foregroundStyle(selectedGroupIDs.isEmpty ? .white.opacity(0.4) : .black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(selectedGroupIDs.isEmpty ? Color.white.opacity(0.08) : Color.brandGreen)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(selectedGroupIDs.isEmpty || isSubmitting)
    }

    private func initializeSelectionIfNeeded() {
        guard selectedGroupIDs.isEmpty else { return }
        var defaults = Set(selectableGroups.map(\.id))
        if let meGroup, isSelectable(meGroup) {
            defaults.insert(meGroup.id)
        }
        selectedGroupIDs = defaults
    }

    // MARK: - 投稿処理

    private func submitPost() {
        guard let user = currentUser, !selectedGroupIDs.isEmpty, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        isCaptionFocused = false

        let now = Date()
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let thumbnailData = thumbnail?.jpegData(compressionQuality: 0.8) ?? Data()

        let targets = selectedGroupIDs.compactMap { id in userGroups.first(where: { $0.id == id }) }

        var inserted: [(video: LaterVideo, group: LaterGroup)] = []

        for group in targets {
            guard isSelectable(group) else { continue }

            // unlockDateは「撮影日の翌朝9:00」で撮影直後に確定する(LaterPhotoと同じ方針、
            // GroupUnlockPolicy.nextUnlockThreshold参照)。
            let newVideo = LaterVideo(
                thumbnailData: thumbnailData,
                durationSeconds: durationSeconds,
                captureDate: now,
                unlockDate: GroupUnlockPolicy.nextUnlockThreshold(after: now),
                owner: user,
                caption: trimmedCaption.isEmpty ? nil : trimmedCaption
            )
            newVideo.authorCloudKitUserRecordName = CloudKitManager.current?.currentUserRecordName
            newVideo.authorNameCache = user.name
            newVideo.locationName = locationName
            newVideo.groupID = group.id
            newVideo.groupNameCache = group.name

            // 投稿先グループごとに独立したローカルコピーを持たせる。1つのファイルを
            // 複数のLaterVideoで共有すると、片方のアップロード確認(markSynced)で
            // ファイルが削除された時点でもう片方が送信不能になるため、必ず1件=1ファイルにする。
            guard let persistedURL = persistVideoCopy(forVideoID: newVideo.id) else { continue }
            newVideo.localFilePath = persistedURL.path

            context.insert(newVideo)
            group.videos.append(newVideo)
            inserted.append((newVideo, group))
        }

        // 全コピーが終わった後、撮影直後のtmp書き出しファイル自体はもう不要。
        try? FileManager.default.removeItem(at: videoURL)

        guard !inserted.isEmpty else {
            isSubmitting = false
            errorMessage = "投稿できるグループがありませんでした。時間帯をご確認ください。"
            return
        }

        do {
            try context.save()
        } catch {
            print("[VideoSave Error] 一括投稿のローカル保存に失敗: \(error)")
            for (video, _) in inserted {
                if let path = video.localFilePath { try? FileManager.default.removeItem(atPath: path) }
                context.delete(video)
            }
            isSubmitting = false
            errorMessage = "保存に失敗しました。もう一度お試しください。"
            return
        }

        if let cloudKitManager = CloudKitManager.current {
            Task {
                for (video, group) in inserted {
                    await cloudKitManager.markForUpload(video: video, in: group)
                    cloudKitManager.markGroupDirty(group.id)
                }
                await cloudKitManager.evaluateGroupUnlockConditions()
                await cloudKitManager.sendPendingChangesNow()
            }
        }

        isSubmitting = false
        HapticsManager.shutterClick()
        onFinished(true)
    }

    /// 撮影直後のtmp書き出しファイルを、アップロード完了まで消えない永続領域
    /// (Application Support)へコピーする。tmpはOSにいつ消されるか保証が無いため、
    /// アップロードが完了するまでの間だけ確実に残しておく必要がある
    /// (アップロード確認後はCloudKitManager.markSyncedが削除する)。
    private func persistVideoCopy(forVideoID id: UUID) -> URL? {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PendingVideos", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent("\(id.uuidString).mp4")
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: videoURL, to: destination)
            return destination
        } catch {
            print("[VideoSave Error] 動画ファイルの永続化に失敗: \(error)")
            return nil
        }
    }

    /// 投稿せずに画面を閉じた場合、tmpに残った加工済み動画ファイルを削除する。
    private func cleanupLocalFileIfNeeded() {
        try? FileManager.default.removeItem(at: videoURL)
    }
}
