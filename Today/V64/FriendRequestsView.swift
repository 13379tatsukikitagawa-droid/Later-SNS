import SwiftUI

/// 申請の 一覧(承認 / 見おくり)。Friends ページの「Requests」から ひらく。
struct FriendRequestsView: View {
    let myName: String
    @State private var items: [FriendRequests.Request] = []
    @State private var names: [String: String] = [:]
    @State private var loading = true
    var onChanged: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Requests").font(LF.serif(40)).foregroundStyle(.white)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44).background(Color.white.opacity(0.1), in: Circle()) }
            }
            if loading { ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 40) }
            else if items.isEmpty { Text("申請は ありません").font(LF.inter(600, 14)).foregroundStyle(HV.gray).frame(maxWidth: .infinity).padding(.top, 40) }
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(items) { r in
                        let name = names[r.fromUserID] ?? (r.fromName.isEmpty ? "ともだち" : r.fromName)
                        HStack(spacing: 12) {
                            Text(String(name.prefix(1))).font(LF.inter(800, 15)).foregroundStyle(.white).frame(width: 42, height: 42).background(Color(hex: "61DD7A"), in: Circle())
                            Text(name).font(LF.inter(800, 16)).foregroundStyle(.white)
                            Spacer()
                            Button { answer(r, accept: false) } label: { Text("見おくり").font(LF.inter(700, 13)).foregroundStyle(HV.gray).frame(height: 44).padding(.horizontal, 6) }.buttonStyle(.plain)
                            Button { answer(r, accept: true) } label: { Text("承認").font(LF.inter(900, 14)).foregroundStyle(HV.ink).padding(.horizontal, 18).frame(height: 40).background(HV.lime, in: Capsule()) }.buttonStyle(HVPress(scale: 0.94))
                        }
                        .padding(12).background(Color(hex: "1C1C1F"), in: RoundedRectangle(cornerRadius: 22))
                    }
                }
            }
        }
        .padding(20).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(hex: "0A0A0B").ignoresSafeArea()).preferredColorScheme(.dark)
        .task { await load() }
    }

    private func load() async {
        items = await FriendRequests.incoming()
        loading = false
        for r in items where names[r.fromUserID] == nil {
            if let p = await UserDirectoryService.fetchProfile(cloudKitUserRecordName: r.fromUserID), !p.name.isEmpty { names[r.fromUserID] = p.name }
        }
    }

    private func answer(_ r: FriendRequests.Request, accept: Bool) {
        Haptics.play(accept ? .success : .soft)
        withAnimation(.easeOut(duration: 0.25)) { items.removeAll { $0.id == r.id } }
        Task { _ = await FriendRequests.respond(to: r, accept: accept, myName: myName); onChanged() }
    }
}
