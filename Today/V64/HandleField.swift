import SwiftUI

// v94 B-3:ID の 入力欄(共通部品)。入力中 → たしかめて います… / つかえる ✓ / つかわれて います + 候補 / きまり違反。
// 高さ 56 ・ 角丸 18 ・ 左に ライムの @ ・ 字は Space Mono 19 太。

struct HandleField: View {
    @Binding var text: String
    var ownerKey: String
    var suggestions: [String] = []
    var autofocus = false
    var onResult: (HandleService.Availability) -> Void = { _ in }

    @State private var state: HandleService.Availability = .unknown
    @State private var checking = false
    @State private var task: Task<Void, Never>?
    @State private var altChips: [String] = []
    @FocusState private var focus: Bool
    private let lime = HV.lime, red = Color(hex: "FF453A")

    private var bad: Bool { if case .taken = state { return true }; if case .invalid = state { return !text.isEmpty }; return false }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("@").font(Typo.ui(800, 20)).foregroundStyle(lime)
                TextField("", text: $text, prompt: Text("your_id").foregroundColor(.white.opacity(0.25)))
                    .font(Typo.label(19)).foregroundStyle(.white).tint(lime).focused($focus)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.asciiCapable).submitLabel(.done)
                    .onChange(of: text) { _, v in
                        let n = HandleRules.normalize(v)
                        if n != v { text = n; return }
                        if n.count > HandleRules.maxLength { text = String(n.prefix(HandleRules.maxLength)); return }
                        schedule(n)
                    }
                trailing
            }
            .padding(.horizontal, 16).frame(height: 56)
            .background(Color(hex: "1C1C1F"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(bad ? red : (focus ? lime.opacity(0.65) : .white.opacity(0.08)), lineWidth: 1.5))
            statusLine
            if case .taken = state, !altChips.isEmpty {
                HStack(spacing: 8) {
                    ForEach(altChips, id: \.self) { c in
                        Button { Haptics.play(.tick); text = c } label: { Text(c).font(Typo.label(12)).foregroundStyle(lime).padding(.horizontal, 12).frame(minHeight: 44).background(lime.opacity(0.10), in: Capsule()) }.buttonStyle(.plain)
                    }
                }.transition(.opacity)
            }
        }
        .onAppear { if autofocus { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focus = true } }; if !text.isEmpty { schedule(text) } }
        .onDisappear { task?.cancel() }
    }

    @ViewBuilder private var trailing: some View {
        if checking { ProgressView().tint(lime) }
        else {
            switch state {
            case .ok, .mine: Image(systemName: "checkmark").font(.system(size: 15, weight: .black)).foregroundStyle(HV.ink).frame(width: 26, height: 26).background(lime, in: Circle())
            case .taken: Text("!").font(Typo.ui(900, 15)).foregroundStyle(.white).frame(width: 26, height: 26).background(red, in: Circle())
            case .invalid: if !text.isEmpty { Text("!").font(Typo.ui(900, 15)).foregroundStyle(.white).frame(width: 26, height: 26).background(red, in: Circle()) }
            case .unknown: EmptyView()
            }
        }
    }

    @ViewBuilder private var statusLine: some View {
        Group {
            if checking { Text("たしかめて います…").foregroundStyle(.white.opacity(0.45)) }
            else {
                switch state {
                case .ok, .mine: Text("@\(text) は つかえます").foregroundStyle(lime)
                case .taken: Text("もう つかわれて います").foregroundStyle(red)
                case .invalid(let p): if text.isEmpty { Text("英小文字 ・ 数字 ・ _ ・ . ／ \(HandleRules.minLength)〜\(HandleRules.maxLength)文字").foregroundStyle(.white.opacity(0.45)) } else { Text(p.message).foregroundStyle(red) }
                case .unknown: Text("ネットワークを たしかめて ください").foregroundStyle(.white.opacity(0.45))
                }
            }
        }.font(Typo.ui(600, 13)).padding(.leading, 4)
    }

    /// 0.35秒 まって から たしかめる
    private func schedule(_ h: String) {
        task?.cancel()
        if let p = HandleRules.validate(h) { checking = false; state = .invalid(p); onResult(state); return }
        checking = true
        task = Task {
            try? await Task.sleep(for: .milliseconds(350))
            if Task.isCancelled { return }
            let r = await HandleService.check(h, ownerKey: ownerKey)
            if Task.isCancelled || HandleRules.normalize(text) != h { return }
            await MainActor.run {
                checking = false
                withAnimation(.easeOut(duration: 0.2)) { state = r }
                if r == .ok || r == .mine { Haptics.play(.tick) } else if r == .taken { Haptics.play(.warn) }
                if r == .taken {
                    let pool = suggestions + HandleRules.suggestions(fromName: h, salt: h.count + 3)
                    altChips = Array(NSOrderedSet(array: pool.filter { $0 != h })).compactMap { $0 as? String }.prefix(3).map { $0 }
                }
                onResult(r)
            }
        }
    }
}
