import SwiftUI

/// 友だちとの 1対1 チャット(F07)。黒い 画面 + 吹き出し + 下の 入力。5秒ごとに 読みなおす。
struct DirectMessageView: View {
    let friendID: String
    let friendName: String
    @State private var messages: [DirectMessages.Message] = []
    @State private var draft = ""
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: { Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44).background(Color.white.opacity(0.1), in: Circle()) }
                Text(String(friendName.prefix(1))).font(LF.inter(800, 15)).foregroundStyle(.white).frame(width: 40, height: 40).background(Color(hex: "61DD7A"), in: Circle())
                Text(friendName).font(LF.serif(26)).foregroundStyle(.white)
                Spacer()
            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { m in
                            let mine = m.senderID == DirectMessages.me
                            Text(m.text).font(LF.inter(600, 15)).foregroundStyle(mine ? HV.ink : .white)
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(mine ? HV.lime : Color(hex: "1C1C1F"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading).id(m.id)
                        }
                    }.padding(16)
                }
                .onChange(of: messages.count) { _, _ in if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } } }
            }
            HStack(spacing: 8) {
                TextField("", text: $draft, prompt: Text("メッセージ").foregroundColor(HV.gray)).font(LF.inter(600, 15)).foregroundStyle(.white).focused($focused)
                    .padding(.horizontal, 16).frame(height: 46).background(Color(hex: "1C1C1F"), in: Capsule()).submitLabel(.send).onSubmit(send)
                Button(action: send) { Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold)).foregroundStyle(HV.ink).frame(width: 46, height: 46).background(DirectMessages.clean(draft) == nil ? Color.white.opacity(0.2) : HV.lime, in: Circle()) }
                    .buttonStyle(.plain).disabled(DirectMessages.clean(draft) == nil)
            }.padding(12)
        }
        .background(Color(hex: "0A0A0B").ignoresSafeArea()).preferredColorScheme(.dark)
        .task { while !Task.isCancelled { messages = await DirectMessages.fetch(with: friendID); try? await Task.sleep(for: .seconds(5)) } }
    }

    private func send() {
        guard let text = DirectMessages.clean(draft) else { return }
        draft = ""
        Haptics.play(.pop)
        Task { if let m = await DirectMessages.send(text, to: friendID) { messages.append(m) } }
    }
}
