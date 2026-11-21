import SwiftUI

/// v108 §5-4:`/u/<ID>` を ひらいた 時の カード。申請 ボタン(相手から もう 申請が 来て いれば 承認)。自分の ID なら 自分の QR。
struct FriendLinkSheetV108: View {
    let handle: String
    let myName: String
    let myUsername: String
    var onShowMine: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var profile: UserDirectoryService.DirectoryProfile?
    @State private var incoming: FriendRequests.Request?
    @State private var state: Phase = .loading
    enum Phase { case loading, ready, sent, connected, missing, mine }

    var body: some View {
        VStack(spacing: 14) {
            Capsule().fill(.white.opacity(0.2)).frame(width: 36, height: 4).padding(.top, 8)
            switch state {
            case .loading: ProgressView().tint(.white).padding(.vertical, 40)
            case .missing:
                Text("見つかりませんでした").font(Typo.ui(800, 17)).foregroundStyle(.white).padding(.top, 20)
                Text("リンクを もう一度 送って もらって ください").font(Typo.ui(500, 13)).foregroundStyle(HV.gray)
            default:
                let name = profile?.name ?? handle
                Text(String(name.prefix(1))).font(Typo.ui(800, 30)).foregroundStyle(HV.ink).frame(width: 84, height: 84).background(Color(hex: "61DD7A"), in: Circle()).padding(.top, 10)
                Text(name).font(Typo.ui(800, 20)).foregroundStyle(.white)
                Text("@\(handle)").font(Typo.ui(600, 14)).foregroundStyle(HV.gray)
                action
            }
            Button("とじる") { dismiss() }.font(Typo.ui(700, 14)).foregroundStyle(HV.gray).frame(height: 44)
        }
        .padding(.horizontal, 24).padding(.bottom, 16).frame(maxWidth: .infinity)
        .background(Color(hex: "111113").ignoresSafeArea()).preferredColorScheme(.dark)
        .presentationDetents([.height(380)])
        .task { await load() }
    }

    @ViewBuilder private var action: some View {
        switch state {
        case .mine:
            PopButton(title: "自分の QR を 見る", kind: .lime) { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onShowMine() } }.padding(.top, 8)
        case .sent: pill("申請を 送りました", dim: true)
        case .connected: pill("友だちに なりました", dim: true)
        default:
            PopButton(title: incoming != nil ? "承認" : "友だち申請", kind: .lime) { Task { await tap() } }.padding(.top, 8)
        }
    }

    private func pill(_ t: String, dim: Bool = false) -> some View {
        Text(t).font(Typo.ui(800, 16)).foregroundStyle(.white.opacity(0.7)).frame(maxWidth: .infinity).frame(height: 50)
            .background(PopColor.raised, in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1)).padding(.top, 8)
    }

    private func load() async {
        if HandleRules.normalize(myUsername) == handle { state = .mine; return }
        let hit = await UserDirectoryService.searchUsers(handle).first { $0.kind == .exact }?.profile
        guard let hit, let rn = hit.cloudKitUserRecordName else { state = .missing; return }
        profile = hit
        incoming = await FriendRequests.incoming().first { $0.fromUserID == rn }
        state = .ready
    }

    private func tap() async {
        guard let p = profile, let rn = p.cloudKitUserRecordName else { return }
        Haptics.play(.click)
        if let r = incoming {
            let ok = await FriendRequests.respond(to: r, accept: true, myName: myName)
            Haptics.play(ok ? .success : .warn); if ok { state = .connected }
        } else {
            let ok = await FriendRequests.send(to: rn, toName: p.name, myName: myName, myUsername: myUsername)
            Haptics.play(ok ? .success : .warn); if ok { state = .sent }
        }
    }
}
