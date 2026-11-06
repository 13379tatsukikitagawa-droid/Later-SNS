import SwiftUI

// 層からひらくシート:友だち / よぶ / 7日のフィルムの1こま / 今月の光った日

struct LayerSheetContent: View {
    let sheet: LayerSheet
    let state: HomeState
    let now: Date
    let data: HomeLayerData
    let actions: HomeLayerActions
    let onClose: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Group {
            switch sheet {
            case .friend(let friend):
                LayerFriendSheet(friend: friend, state: state, windowKey: data.windowKey, actions: actions, onClose: onClose)
                    .presentationDetents([.height(friend.isMe ? 360 : 520), .large])
            case .invite:
                LayerInviteSheet(groups: data.inviteGroups, actions: actions, onClose: onClose)
                    .presentationDetents([.medium])
            case .film(let day):
                LayerPrintSheet(
                    data: Self.filmData(day),
                    stamp: day.ago == 0 ? "今日" : Self.stamp(day.date),
                    title: day.ago == 0 ? "今日の1枚" : "\(Self.stamp(day.date)) の1枚",
                    note: "あと\(HomeLayerRules.filmDaysLeft(ago: day.ago))日、のこります。日がたつほど、少しずつうすくなります。",
                    opacity: HomeLayerRules.filmOpacity(ago: day.ago)
                )
                .presentationDetents([.large])
            case .pick(let pick):
                let ago = LampRules.daysAgo(day: pick.day, now: now) ?? 0
                LayerPrintSheet(
                    data: pick.thumbnail,
                    stamp: Self.stamp(LampRules.date(fromDayKey: pick.day) ?? now),
                    title: "グループの一枚",
                    note: "あと\(max(0, LampRules.keepDays - ago))日、のこります。",
                    opacity: LampRules.fadeOpacity(daysAgo: ago)
                )
                .presentationDetents([.large])
            }
        }
        .presentationBackground(palette.bg)
        .presentationDragIndicator(.visible)
        .environment(\.colorScheme, palette.isNight ? .dark : .light)
    }

    private static func filmData(_ day: HomeFilmDay) -> Data? {
        if case .photo(let data) = day.kind { return data }
        return nil
    }

    static func stamp(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.month, .day], from: date)
        return String(format: "%d.%02d", c.month ?? 0, c.day ?? 0)
    }
}

// MARK: - 友だち

/// 名前 / 撮った・まだ / 市区町村 / 今日のモザイク + タグ。写真そのものは出さない。
private struct LayerFriendSheet: View {
    let friend: HomeFriend
    let state: HomeState
    let windowKey: String
    let actions: HomeLayerActions
    let onClose: () -> Void

    @Environment(\.palette) private var palette
    @State private var knocks = KnockStore.shared

    private var knocked: Bool { knocks.hasKnocked(friend.id, window: windowKey) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack {
                    if friend.hasShot {
                        Circle().strokeBorder(palette.accent, lineWidth: 3)
                    } else {
                        Circle().strokeBorder(palette.sub.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
                    }
                    LayerAvatar(data: friend.avatarData, seed: friend.seed, name: friend.name)
                        .frame(width: 84, height: 84)
                }
                .frame(width: 98, height: 98)
                .padding(.top, 28)
                .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text(friend.isMe ? "わたし" : friend.name)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: 6) {
                        Image(systemName: friend.hasShot ? "checkmark.circle.fill" : "circle.dashed")
                        Text(friend.hasShot ? (state.isNight ? "きのう、撮った" : "撮った") : "まだ")
                        if friend.hasShot, let city = friend.city {
                            Text("・")
                            Text(city)
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(friend.hasShot ? palette.accentText : palette.sub)
                    .accessibilityElement(children: .combine)
                }

                if !friend.isMe, friend.hasShot {
                    VStack(spacing: 8) {
                        MosaicView(tiny: friend.mosaicTiny, key: friend.mosaicKey)
                            .aspectRatio(0.8, contentMode: .fit)
                            .frame(width: 150)
                            .clipped()
                            .chicPrint(side: 7, bottom: 26, rotation: -2)
                        if let tag = friend.tag {
                            Text("#\(tag)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(palette.ink)
                        }
                        Text("写真は、撮った人どうしで、あしたひらきます")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.sub)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("今日の1枚のモザイク\(friend.tag.map { "。#\($0)" } ?? "")")
                }

                if !friend.isMe, !friend.hasShot {
                    knockArea
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private var knockArea: some View {
        if HomeLayerRules.canKnock(state: state, friend: friend, knockedToday: knocked) {
            VStack(spacing: 8) {
                Button {
                    LayerHaptics.knock()
                    actions.knock(friend)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                        Text("ノックする")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(palette.isNight ? Palette.day.ink : Color.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Capsule().fill(palette.ink))
                }
                .buttonStyle(PressScaleStyle(scale: 0.97, duration: 0.15))
                .accessibilityHint("文字なしで、ブブッと知らせます。1日に1回")
                Text("文字は送れません。1人に、1日1回。")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.sub)
            }
            .padding(.top, 8)
        } else {
            Text(knockNote)
                .font(.system(size: 12))
                .foregroundStyle(palette.sub)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }

    private var knockNote: String {
        if knocked { return "今日は、ノックしました。" }
        if friend.knockOff { return "ノックを受けとっていません。" }
        if state.isNight { return "夜は、ノックできません。" }
        return ""
    }
}

// MARK: - よぶ

private struct LayerInviteSheet: View {
    let groups: [HomeInviteGroup]
    let actions: HomeLayerActions
    let onClose: () -> Void

    @Environment(\.palette) private var palette
    @State private var selected: UUID?
    @State private var link: URL?
    @State private var loading = false
    @State private var failed = false

    private var current: HomeInviteGroup? {
        groups.first { $0.id == selected } ?? groups.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ともだちを、よぶ")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 28)

            if groups.isEmpty {
                Text("グループをつくると、ともだちをよべます。")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.sub)
                Button {
                    onClose()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { actions.createGroup() }
                } label: {
                    primaryLabel("グループをつくる", icon: "plus")
                }
                .buttonStyle(PressScaleStyle(scale: 0.97, duration: 0.15))
            } else {
                Text("グループの招待リンクを、送ります。")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.sub)
                if groups.count > 1 {
                    VStack(spacing: 0) {
                        ForEach(groups) { group in
                            Button {
                                LayerHaptics.light()
                                selected = group.id
                            } label: {
                                HStack {
                                    Text(group.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(palette.ink)
                                    Spacer()
                                    Image(systemName: current?.id == group.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(current?.id == group.id ? palette.ink : palette.sub)
                                }
                                .frame(minHeight: 46)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(current?.id == group.id ? .isSelected : [])
                        }
                    }
                }
                if let link, let current {
                    ShareLink(item: link, message: Text(InviteConfig.shareMessage(groupName: current.name, url: link))) {
                        primaryLabel("招待リンクを送る", icon: "square.and.arrow.up")
                    }
                    .simultaneousGesture(TapGesture().onEnded { LayerHaptics.light() })
                } else if failed {
                    Text("リンクをつくれませんでした。つながってから、もう一度。")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.sub)
                } else {
                    primaryLabel(loading ? "リンクを用意しています…" : "招待リンクを送る", icon: "square.and.arrow.up")
                        .opacity(0.5)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .task(id: current?.id) { await load() }
    }

    private func load() async {
        guard let current else { return }
        link = nil
        failed = false
        loading = true
        let url = await actions.inviteLink(current.id)
        loading = false
        if let url { link = url } else { failed = true }
    }

    private func primaryLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(palette.isNight ? Palette.day.ink : Color.white)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(Capsule().fill(palette.ink))
    }
}

// MARK: - 大きいポラロイド(フィルムの1こま・光った日)

private struct LayerPrintSheet: View {
    let data: Data?
    let stamp: String
    let title: String
    let note: String
    let opacity: Double

    @Environment(\.palette) private var palette
    @State private var image: UIImage?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text(title)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 32)
                ZStack {
                    Color(hex: "3A2A22")
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill().opacity(opacity)
                    }
                }
                .aspectRatio(0.8, contentMode: .fit)
                .frame(maxWidth: 300)
                .clipped()
                .overlay(alignment: .bottomTrailing) {
                    Text(stamp)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(ChicColor.stamp)
                        .padding(10)
                }
                .chicPrint(side: 12, bottom: 52, rotation: -1.5)
                .accessibilityLabel("\(stamp)の写真")
                Text(note)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.sub)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 40)
        }
        .task {
            guard let data else { return }
            image = await LayerImageCache.photo(data, key: "print-\(stamp)-\(data.count)", maxPixel: 900)
        }
    }
}
