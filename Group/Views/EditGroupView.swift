import SwiftUI
import SwiftData
import PhotosUI

/// グループ名・アイコンの編集画面。オーナーに限らず、全メンバーが開いて変更できる
/// (招待リンク発行はホスト限定のままだが、名前/アイコンはグループ全体の持ち物という
/// 位置づけのため誰でも編集可能にしている)。保存はCKShareのpublicPermission=.readWrite
/// (GroupSharingService.createGroup参照)により、ホスト以外の端末からのCloudKit書き込みも
/// 許可されている前提。
struct EditGroupView: View {
    let group: LaterGroup

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String
    @State private var iconImageData: Data?
    @State private var selectedIconItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(group: LaterGroup) {
        self.group = group
        _name = State(initialValue: group.name)
        _iconImageData = State(initialValue: group.iconImageData)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        PhotosPicker(selection: $selectedIconItem, matching: .images) {
                            ZStack {
                                GroupIconView(iconImageData: iconImageData, groupName: trimmedName, size: 88)

                                Circle()
                                    .strokeBorder(Color.brandGreen.opacity(0.4), lineWidth: 1.5)
                                    .frame(width: 88, height: 88)

                                Circle()
                                    .fill(Color.brandGreen)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.black)
                                    )
                                    .offset(x: 30, y: 30)
                            }
                        }
                        .padding(.top, 24)
                        .onChange(of: selectedIconItem) { _, newItem in
                            Task {
                                guard let newItem, let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                                iconImageData = data
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("グループ名")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))

                            TextField("グループ名", text: $name)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        .padding(.horizontal, 20)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundStyle(.red.opacity(0.85))
                                .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .navigationTitle("グループを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("保存").fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(Color.brandGreen)
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() async {
        guard canSave, let cloudKitManager = CloudKitManager.current else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        group.name = trimmedName
        group.iconImageData = iconImageData
        do {
            try modelContext.save()
        } catch {
            errorMessage = "保存に失敗しました。もう一度お試しください。"
            return
        }

        cloudKitManager.markForUpload(group: group)
        await cloudKitManager.sendPendingChangesNow()
        HapticsManager.tick()
        dismiss()
    }
}
