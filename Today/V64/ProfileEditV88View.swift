import SwiftUI

// v88 B:プロフィールの 編集 = 黒い プロフィールの 上で その場で(F23 F24)。古い 白い 画面は 使わない。
// 上の 帯(104):キャンセル ・ 編集 ・ 完了。箱:写真 ・ 名前 ・ タグ。保存は 今までと 同じ(name / selfTags)

struct ProfileEditV88View: View {
    let initialName: String
    let initialTags: [String]
    var avatar: UIImage?
    var onPhoto: () -> Void
    var onSave: (_ name: String, _ tags: [String]) -> Void
    var onClose: () -> Void

    @State private var name: String
    @State private var tags: [String]
    @State private var custom = ""
    @State private var writing = false
    @State private var toast: String?
    @State private var confirmDiscard = false
    @State private var shown = false
    @FocusState private var focus: Bool

    private let box = Color(hex: "121315")
    private let candidates = ["カフェ", "音楽", "夜型", "夕焼け", "放課後", "帰り道", "散歩", "映画"]
    private let chip: [(String, String)] = [("C8F25A", "0B0C0D"), ("EE5E9C", "FFFFFF"), ("9ED8FF", "0B0C0D")]

    init(name: String, tags: [String], avatar: UIImage?, onPhoto: @escaping () -> Void, onSave: @escaping (String, [String]) -> Void, onClose: @escaping () -> Void) {
        initialName = name; initialTags = tags; self.avatar = avatar; self.onPhoto = onPhoto; self.onSave = onSave; self.onClose = onClose
        _name = State(initialValue: name); _tags = State(initialValue: tags)
    }

    private var changed: Bool { name != initialName || tags != initialTags }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "0B0C0D").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 12) {
                    Color.clear.frame(height: 104)
                    ProfileChekiArea(name: name.isEmpty ? initialName : name, avatar: avatar, tags: tags, editing: true, onPhoto: onPhoto, onName: { focus = true }, onRemoveTag: { i in
                        withAnimation(.easeOut(duration: 0.2)) { if tags.indices.contains(i) { tags.remove(at: i) } }
                    }).rise(shown, 0).padding(.horizontal, -16)
                    nameBox.rise(shown, 1)
                    tagBox.rise(shown, 2)
                    Color.clear.frame(height: 80)
                }.padding(.horizontal, 16)
            }.scrollDismissesKeyboard(.interactively)
            bar
            if let toast { Text(toast).font(LF.inter(700, 13)).foregroundStyle(HV.ink).padding(.horizontal, 16).frame(height: 36).background(.white, in: Capsule()).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 60).transition(.opacity) }
        }
        .environment(\.colorScheme, .dark)
        .onAppear { Haptics.play(.pop); withAnimation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.45)) { shown = true } }
        .confirmationDialog("変更を すてますか?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("すてる", role: .destructive) { onClose() }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private var bar: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(.ultraThinMaterial).overlay(Color.black.opacity(0.82)).frame(height: 104).ignoresSafeArea(edges: .top)
            HStack {
                Button { Haptics.play(.tick); if changed { confirmDiscard = true } else { onClose() } } label: {
                    Text("キャンセル").font(LF.inter(700, 14)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8).padding(.horizontal, 14).frame(minWidth: 44, minHeight: 44).background(.white.opacity(0.1), in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
                }.buttonStyle(.plain)
                Spacer()
                Text("編集").font(LF.inter(900, 17)).foregroundStyle(.white)
                Spacer()
                Button { done() } label: {
                    Text("完了").font(LF.inter(800, 14)).foregroundStyle(changed ? HV.ink : .white.opacity(0.35)).padding(.horizontal, 18).frame(minWidth: 44, minHeight: 44)
                        .background(changed ? HV.lime : .white.opacity(0.08), in: Capsule()).shadow(color: changed ? HV.lime.opacity(0.5) : .clear, radius: 10)
                }.buttonStyle(.plain)
            }.padding(.horizontal, 16).padding(.top, 50)
        }.frame(height: 104, alignment: .top).offset(y: shown ? 0 : -110)
    }

    private func title(_ t: String, _ right: String? = nil) -> some View {
        HStack { Text(t).font(LF.inter(800, 15)).foregroundStyle(.white); Spacer(); if let right { Text(right).font(LF.mono(11)).foregroundStyle(.white.opacity(0.45)) } }
    }

    private var photoBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            title("写真")
            HStack(spacing: 10) {
                Button { Haptics.play(.click); onPhoto() } label: {
                    VStack(spacing: 6) { Image(systemName: "camera.fill").font(.system(size: 20, weight: .bold)); Text("えらぶ").font(LF.inter(800, 11)) }
                        .foregroundStyle(HV.ink).frame(width: 54, height: 68).background(HV.lime, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }.buttonStyle(HVPress(scale: 0.94))
                ZStack { if let avatar { Image(uiImage: avatar).resizable().scaledToFill() } else { Circle().fill(LinearGradient(colors: [Color(hex: "61D278"), Color(hex: "EE5E9C")], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay(Text(String(name.prefix(1))).font(LF.inter(900, 24)).foregroundStyle(.white)) } }
                    .frame(width: 60, height: 60).clipShape(Circle()).overlay(Circle().strokeBorder(HV.lime, lineWidth: 2.5))
                Spacer(minLength: 0)
            }
        }.padding(16).background(box, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var nameBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            title("名前", "\(name.count) / \(ProfileShelfEditRules.nameMaxLength)")
            HStack {
                TextField("名前を 入れてください", text: $name).focused($focus).font(LF.inter(800, 19)).foregroundStyle(.white).textContentType(.nickname)
                    .onChange(of: name) { _, v in let c = ProfileShelfEditRules.clampName(v); if c != v { name = c } }
                if !name.isEmpty { Button { Haptics.play(.tick); name = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.4)).frame(width: 44, height: 44) }.buttonStyle(.plain) }
            }.padding(.leading, 16).frame(height: 54).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(focus ? HV.lime : .clear, lineWidth: 1.5))
        }.padding(16).background(box, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var tagBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            title("タグ", "\(tags.count) / \(ProfileShelfEditRules.maxTags)")
            HStack(spacing: 8) {
                ForEach(Array(tags.enumerated()), id: \.offset) { i, t in
                    let c = chip[i % 3]
                    Button { Haptics.play(.tick); withAnimation(.easeOut(duration: 0.2)) { tags.remove(at: i) } } label: {
                        HStack(spacing: 6) { Text("#\(t)").lineLimit(1); Image(systemName: "xmark").font(.system(size: 9, weight: .black)) }
                            .font(LF.inter(900, 15)).foregroundStyle(Color(hex: c.1)).padding(.horizontal, 12).frame(minHeight: 44).background(Color(hex: c.0), in: Capsule())
                    }.buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { cands }
                VStack(alignment: .leading, spacing: 8) { cands }
            }
            if writing {
                HStack {
                    TextField("タグ", text: $custom).font(LF.inter(800, 17)).foregroundStyle(.white).submitLabel(.done).onSubmit { addCustom() }
                    Button("追加") { addCustom() }.font(LF.inter(800, 14)).foregroundStyle(HV.lime).frame(minWidth: 44, minHeight: 44)
                }.padding(.leading, 16).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                Button { Haptics.play(.tick); writing = true } label: {
                    Text("# じぶんで 書く").font(LF.inter(800, 14)).foregroundStyle(HV.lime).padding(.horizontal, 14).frame(minHeight: 44)
                        .overlay(Capsule().strokeBorder(HV.lime.opacity(0.6), style: StrokeStyle(lineWidth: 1.4, dash: [4, 3])))
                }.buttonStyle(.plain)
            }
        }.padding(16).background(box, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder private var cands: some View {
        ForEach(candidates.filter { !tags.contains($0) }.prefix(4), id: \.self) { c in
            Button { add(c) } label: { Text("#\(c)").font(LF.inter(700, 14)).foregroundStyle(.white.opacity(0.85)).padding(.horizontal, 12).frame(minHeight: 44).background(.white.opacity(0.08), in: Capsule()) }.buttonStyle(.plain)
        }
    }

    private func add(_ raw: String) {
        switch ProfileShelfEditRules.add(raw, to: tags) {
        case .added(let t): Haptics.play(.pop); withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { tags = t }
        case .full: Haptics.play(.warn); say("タグは \(ProfileShelfEditRules.maxTags)つまで")
        case let r: Haptics.play(.warn); if let m = r.message { say(m) }
        }
    }
    private func addCustom() { add(custom); custom = ""; writing = false }
    private func say(_ m: String) { withAnimation { toast = m }; DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { withAnimation { toast = nil } } }

    private func done() {
        guard changed else { return }
        switch ProfileShelfEditRules.savedName(name) {
        case .looksLikeContact: Haptics.play(.warn); say("URL や メールは 入れられません")
        case .ok(let n):
            Haptics.play(.success)
            onSave(n, ProfileShelfEditRules.savedTags(draft: tags, previous: initialTags))
        }
    }
}
