import SwiftUI
import SwiftData

// v94 B-4:ID を かえる シート(下から ・ 黒 ・ 角丸 38)。14日に 1回。F33 F34。

struct HandleChangeHost: View {
    var forced = false
    var onDone: (String?) -> Void
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var text = ""
    @State private var state: HandleService.Availability = .unknown
    @State private var saving = false
    @State private var errorText: String?

    private var me: UserProfile? { UserProfile.current(from: profiles) }
    private var daysLeft: Int { HandleRules.daysUntilChange(lastChange: HandleService.lastChange) }
    private var canSave: Bool { daysLeft == 0 && (state == .ok || (forced && state == .mine)) && !saving && (forced || text != me?.username) }
    private let lime = HV.lime

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("ID").font(LF.serif(34, italic: true)).foregroundStyle(.white)
                Spacer()
                if !forced || state == .unknown { Button { Haptics.play(.tick); onDone(nil) } label: { Image(systemName: forced ? "clock" : "xmark").font(.system(size: 15, weight: .black)).foregroundStyle(.white).frame(width: 44, height: 44).background(.white.opacity(0.1), in: Circle()) }.buttonStyle(.plain) }
            }.padding(.top, 22)
            Text("いま @\(me?.username ?? "")").font(LF.mono(13)).foregroundStyle(.white.opacity(0.5)).padding(.top, 2)
            HandleField(text: $text, ownerKey: me?.id.uuidString ?? "", suggestions: HandleRules.suggestions(fromName: me?.name ?? ""), autofocus: daysLeft == 0) { state = $0 }.padding(.top, 18)
            VStack(alignment: .leading, spacing: 8) {
                rule("英小文字 ・ 数字 ・ _ ・ . が つかえます(\(HandleRules.minLength)〜\(HandleRules.maxLength)文字)")
                rule("かえられるのは \(HandleRules.changeIntervalDays)日に 1回")
                rule("前の ID は \(HandleRules.changeIntervalDays)日間 だれも とれません")
            }.padding(.top, 16)
            if let errorText { Text(errorText).font(LF.inter(700, 13)).foregroundStyle(Color(hex: "FF453A")).padding(.top, 10) }
            Button { save() } label: {
                Text(daysLeft > 0 ? "あと \(daysLeft)日で かえられます" : (saving ? "保存して います…" : "保存")).font(LF.inter(800, 17)).foregroundStyle(canSave ? HV.ink : .white.opacity(0.3))
                    .frame(maxWidth: .infinity).frame(height: 56).background(canSave ? lime : Color.white.opacity(0.08), in: Capsule())
            }.buttonStyle(HVPress(scale: 0.97)).disabled(!canSave).padding(.top, 16).padding(.bottom, 16)
        }
        .padding(.horizontal, 20)
        .sheetFitsContent()
        .background(Color(hex: "0F1011").ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .onAppear { if text.isEmpty { let cur = me?.username ?? ""; text = (forced && HandleRules.validate(cur) == nil) ? cur : (HandleRules.suggestions(fromName: me?.name ?? "").first ?? "") } }
        .interactiveDismissDisabled(forced)
        .presentationCornerRadius(38).presentationBackground(Color(hex: "0F1011")).presentationDragIndicator(.visible)
    }

    private func rule(_ t: String) -> some View {
        HStack(alignment: .top, spacing: 8) { Circle().fill(lime).frame(width: 5, height: 5).padding(.top, 6); Text(t).font(LF.inter(600, 13)).foregroundStyle(.white.opacity(0.6)) }
    }

    private func save() {
        guard let me, canSave else { return }
        saving = true; errorText = nil
        let new = HandleRules.normalize(text)
        let old = me.username
        Task { @MainActor in
            let r = await HandleService.claim(new, ownerKey: me.id.uuidString, previous: (forced || old.isEmpty) ? nil : old)
            saving = false
            if r == .mine || r == .ok {
                me.username = new; me.profileUpdatedAt = Date(); try? context.save()
                await UserDirectoryService.publish(me)
                Haptics.play(.success)
                onDone(new)
            } else { Haptics.play(.warn); errorText = r == .taken ? "もう つかわれて います" : "保存できませんでした。もう一度 ためして ください" }
        }
    }
}
