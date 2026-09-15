import SwiftUI

/// 解禁後、自分が撮影したチェキ写真の下に表示する「保存」「共有」ボタン行。
/// チェキフレーム込みの画像(ChekiImageExporter)を生成してPHPhotoLibraryへ保存/
/// 共有シートへ渡す。呼び出し側で「自分が撮影した写真かどうか」を判定してから
/// このViewごと表示・非表示を切り替える(このView自体は判定を持たない)。
struct ChekiSaveShareButtons: View {
    let photo: LaterPhoto

    @State private var isSaving = false
    @State private var toastMessage: String?
    @State private var shareImage: UIImage?
    @State private var showingShareSheet = false

    private static let accentGreen = Color.brandGreen
    private static let saveIconColor = Color(hex: "d8d6cf")
    private static let saveLabelColor = Color(hex: "7a7a75")

    var body: some View {
        HStack(spacing: 14) {
            roundButton(
                systemImage: "arrow.down.to.line",
                label: "保存",
                iconColor: Self.saveIconColor,
                labelColor: Self.saveLabelColor,
                background: Color.white.opacity(0.06),
                border: Color.white.opacity(0.1),
                showsProgress: isSaving
            ) {
                Task { await saveTapped() }
            }
            .disabled(isSaving)

            roundButton(
                systemImage: "square.and.arrow.up",
                label: "共有",
                iconColor: Self.accentGreen,
                labelColor: Self.accentGreen,
                background: Self.accentGreen.opacity(0.12),
                border: Self.accentGreen,
                showsProgress: false
            ) {
                shareTapped()
            }
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                Text(toastMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.85)))
                    .offset(y: -44)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let shareImage {
                ShareSheet(activityItems: [shareImage])
            }
        }
    }

    private func roundButton(
        systemImage: String,
        label: String,
        iconColor: Color,
        labelColor: Color,
        background: Color,
        border: Color,
        showsProgress: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(background)
                        .frame(width: 52, height: 52)
                        .overlay(
                            Circle().strokeBorder(border, lineWidth: 1)
                        )
                    if showsProgress {
                        ProgressView()
                            .tint(iconColor)
                    } else {
                        Image(systemName: systemImage)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(iconColor)
                    }
                }
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(labelColor)
            }
        }
        .buttonStyle(.plain)
    }

    private func saveTapped() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        guard let image = ChekiImageExporter.renderImage(for: photo) else {
            showToast("保存に失敗しました")
            return
        }
        do {
            try await PhotoLibrarySaver.save(image)
            HapticsManager.unlockSuccess()
            showToast("保存しました")
        } catch {
            HapticsManager.errorFeedback()
            showToast("写真へのアクセスが許可されていません")
        }
    }

    private func shareTapped() {
        guard let image = ChekiImageExporter.renderImage(for: photo) else { return }
        shareImage = image
        showingShareSheet = true
        HapticsManager.tick()
    }

    private func showToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                toastMessage = nil
            }
        }
    }
}
