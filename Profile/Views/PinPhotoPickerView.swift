import SwiftUI

/// Pinsエリアの「+」から開く、これまでの解禁済み写真からピン留めする写真を選ぶシート。
/// 既にピン留め済みの写真は「ピン留め済み」バッジ付きで識別できるが選び直しはできない
/// (解除はPinsエリア側のxボタン/長押しで行う)。残り枠数を超えては選択できない。
struct PinPhotoPickerView: View {
    let photos: [LaterPhoto]
    let alreadyPinnedIDs: Set<UUID>
    let remainingSlots: Int
    let onConfirm: (_ newlyPinnedIDs: [UUID]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection: [UUID] = []

    private static let columnCount = 3
    private static let gridSpacing: CGFloat = 3
    private static let columns = Array(
        repeating: GridItem(.flexible(), spacing: gridSpacing),
        count: columnCount
    )

    /// LazyVGrid + `.aspectRatio(1, contentMode: .fill)` の組み合わせは、行の高さを
    /// 提案できない状況(特に最終行)でセルが異常に巨大化することがあるため、
    /// GeometryReaderで実測した幅から正方形のセルサイズを計算し、全セルへ
    /// 明示的な.frame(width:height:)を与える(サイズをレイアウトエンジンの
    /// 推論任せにしない)。
    private func cellSize(for totalWidth: CGFloat) -> CGFloat {
        let totalSpacing = Self.gridSpacing * CGFloat(Self.columnCount - 1)
        return max(0, (totalWidth - totalSpacing) / CGFloat(Self.columnCount))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    Text("あと\(remainingSlots)枚までピン留めできます")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)

                    if photos.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: Self.columns, spacing: Self.gridSpacing) {
                            ForEach(photos, id: \.id) { photo in
                                photoCell(photo, cellSize: cellSize(for: proxy.size.width))
                            }
                        }
                    }
                }
                .background(Color.brandBlack.ignoresSafeArea())
            }
            .navigationTitle("ピン留めする写真を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .safeAreaInset(edge: .bottom) {
                confirmButton
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.3))
            Text("ピン留めできる写真がまだありません")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func photoCell(_ photo: LaterPhoto, cellSize: CGFloat) -> some View {
        let isAlreadyPinned = alreadyPinnedIDs.contains(photo.id)
        let isSelected = selection.contains(photo.id)
        let canToggle = !isAlreadyPinned && (isSelected || selection.count < remainingSlots)

        return Button {
            guard canToggle else { return }
            if isSelected {
                selection.removeAll { $0 == photo.id }
            } else {
                selection.append(photo.id)
            }
            HapticsManager.tick()
        } label: {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let uiImage = UIImage(data: photo.imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.white.opacity(0.05)
                    }
                }
                .frame(width: cellSize, height: cellSize)
                .clipped()

                if isAlreadyPinned {
                    Text("ピン留め済み")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.6), in: Capsule())
                        .padding(6)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.brandGreen)
                        .background(Circle().fill(.black.opacity(0.5)))
                        .padding(6)
                }
            }
            .overlay(
                Rectangle()
                    .strokeBorder(isSelected ? Color.brandGreen : .clear, lineWidth: 2)
            )
            .opacity(isAlreadyPinned ? 0.4 : (canToggle || isSelected ? 1 : 0.35))
        }
        .buttonStyle(.plain)
        .disabled(isAlreadyPinned || (!canToggle && !isSelected))
    }

    private var confirmButton: some View {
        Button {
            onConfirm(selection)
            dismiss()
        } label: {
            Text(selection.isEmpty ? "この写真をピン留め" : "\(selection.count)枚をピン留め")
                .font(.headline)
                .foregroundStyle(selection.isEmpty ? .white.opacity(0.4) : .black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selection.isEmpty ? Color.white.opacity(0.08) : Color.brandGreen)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(selection.isEmpty)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(Color.brandBlack)
    }
}
