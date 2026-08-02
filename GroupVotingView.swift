import SwiftUI
import SwiftData

/// グループの「今日の一枚」投票画面。票数・順位はここにも一切表示しない。
struct GroupVotingView: View {
    let group: LaterGroup
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \PhotoVote.votedAt) private var allVotes: [PhotoVote]

    @State private var currentIndex = 0

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    private var candidatePhotos: [LaterPhoto] {
        let calendar = Calendar.current
        return group.photos
            .filter { $0.isUnlocked && calendar.isDate($0.captureDate, inSameDayAs: date) }
            .sorted { $0.captureDate < $1.captureDate }
    }

    private var isEligible: Bool {
        guard let user = currentUser else { return false }
        return VotingManager.shared.isEligibleToVote(voter: user, group: group, date: date)
    }

    private var myVotedPhotoID: UUID? {
        guard let user = currentUser else { return nil }
        let calendar = Calendar.current
        return allVotes.first {
            $0.voter?.id == user.id && calendar.isDate($0.photo?.captureDate ?? .distantPast, inSameDayAs: date)
        }?.photo?.id
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("今日の一枚に投票")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("1人1票、確定前まで変更できます")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding()

                    if !isEligible {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.exclamationmark")
                                .font(.system(size: 44))
                                .foregroundStyle(.white.opacity(0.5))
                            Text("投票資格がありません")
                                .foregroundStyle(.white)
                            Text("本日撮影したメンバーだけが投票できます")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                    } else if candidatePhotos.isEmpty {
                        Spacer()
                        Text("解禁された写真がありません")
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                    } else {
                        TabView(selection: $currentIndex) {
                            ForEach(Array(candidatePhotos.enumerated()), id: \.element.id) { index, photo in
                                VStack(spacing: 16) {
                                    Spacer()

                                    if let uiImage = UIImage(data: photo.imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFit()
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .padding()
                                    }

                                    Text("撮影: \(photo.owner?.name ?? photo.authorNameCache ?? "不明")")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.7))

                                    Button {
                                        guard let user = currentUser else { return }
                                        _ = VotingManager.shared.castVote(photo: photo, voter: user, context: modelContext)
                                    } label: {
                                        HStack {
                                            Image(systemName: myVotedPhotoID == photo.id ? "checkmark.circle.fill" : "circle")
                                            Text(myVotedPhotoID == photo.id ? "投票済み" : "この一枚に投票")
                                        }
                                        .font(.headline)
                                        .foregroundStyle(Color.black)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(myVotedPhotoID == photo.id ? Color.green : Color.brandGreen)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                    .padding(.horizontal)

                                    Spacer()
                                }
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .always))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color.brandGreen)
                }
            }
        }
    }
}
