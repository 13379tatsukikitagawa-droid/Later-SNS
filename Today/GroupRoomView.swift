import MapKit
import SwiftUI
import UIKit

// グループの部屋(Home v5 第10章)。グループの丸アイコン+名前、メンバー、位置のモード、地図、昨日の写真のタイル。
// 位置は約500mの格子に丸めた値だけ。文字・お店のマークは出さない(MapKit の標準スタイルで、できる範囲で消す)。

struct GroupRoomMember: Identifiable, Equatable {
    let id: UUID
    let imageData: Data?
    /// 今日撮った人(縁が橙に光る)
    let hasShotToday: Bool
}

struct GroupRoomModel: Equatable {
    let section: GroupSectionModel
    let members: [GroupRoomMember]
    let pins: [SharedPlacePin]
}

struct GroupRoomView: View {
    let model: GroupRoomModel
    let haptics: ExposureHaptics
    let onClose: () -> Void
    let onSelectMode: (GroupLocationMode) -> Void
    let onOpenTile: (_ point: CGPoint, _ tileID: String) -> Void
    let onMore: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var camera: MapCameraPosition = .automatic

    private var section: GroupSectionModel { model.section }

    private var palette: [Color] {
        GroupRingMath.auraPalettes[GroupPalette.isValid(section.auraIndex) ? section.auraIndex : 0]
    }

    var body: some View {
        ZStack(alignment: .top) {
            V5Backdrop()
            ScrollView(.vertical) {
                VStack(spacing: 22) {
                    identity
                    memberRow
                    modePicker
                    mapCard
                    tilesGrid
                }
                .padding(.horizontal, 20)
                .padding(.top, 76)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)

            topBar
        }
        .environment(\.colorScheme, .dark)
        .onAppear { recenter() }
    }

    // MARK: 上のバー

    private var topBar: some View {
        HStack {
            circleButton("chevron.left", label: "もどる", action: onClose)
            Spacer()
            circleButton("ellipsis", label: "グループの設定", action: onMore)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .consumesTap()
    }

    private func circleButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: 1. アイコン+名前

    private var identity: some View {
        VStack(spacing: 12) {
            Group {
                if let data = section.iconData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        LinearGradient(colors: [palette[0], palette[2]], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Text(String(section.name.trimmingCharacters(in: .whitespaces).prefix(1)))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 70, height: 70)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
            .shadow(color: palette[0].opacity(0.6), radius: 18)

            Text(section.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: 2. メンバー

    private var memberRow: some View {
        HStack(spacing: 10) {
            ForEach(model.members) { member in
                Group {
                    if let data = member.imageData, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        PersonaIcon(seed: member.id)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(member.hasShotToday ? V5.amber : .white.opacity(0.18), lineWidth: member.hasShotToday ? 2.5 : 1))
                .shadow(color: member.hasShotToday ? V5.amber.opacity(0.7) : .clear, radius: 8)
                .accessibilityLabel(member.hasShotToday ? "今日撮ったメンバー" : "メンバー")
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 3. モードの選択(ガラスのセグメント)

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(GroupLocationMode.available, id: \.self) { mode in
                let selected = section.locationMode == mode
                Button {
                    guard !selected else { return }
                    haptics.playPattern(HomeHapticPattern.light)
                    onSelectMode(mode)
                } label: {
                    Text(mode.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? Color.black : .white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Capsule().fill(selected ? V5.amber : .clear))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .animation(.spring(duration: 0.4, bounce: 0.25), value: section.locationMode)
        .consumesTap()
    }

    // MARK: 4. 地図(350 × 300・角丸34)

    private var mapCard: some View {
        ZStack {
            Map(position: $camera, interactionModes: [.pan, .zoom]) {
                if let center = centerCoordinate {
                    // 中心に自分、まわりに破線の距離の輪
                    Annotation("", coordinate: center) {
                        Circle()
                            .fill(.white)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(V5.amber, lineWidth: 3))
                            .shadow(color: V5.amber, radius: 6)
                    }
                    ForEach([500.0, 1000.0], id: \.self) { radius in
                        MapCircle(center: center, radius: radius)
                            .foregroundStyle(.clear)
                            .stroke(.white.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                    }
                }
                if section.locationMode != .off {
                    ForEach(model.pins) { pin in
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)) {
                            PlacePinView(pin: pin)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
            .mapControlVisibility(.hidden)
            .environment(\.colorScheme, .dark)
            .overlay { Color(hex: "FF9E5E").opacity(0.07).blendMode(.overlay).allowsHitTesting(false) }
            .blur(radius: section.locationMode == .off ? 14 : 0)
            .saturation(section.locationMode == .off ? 0.5 : 1)

            if section.locationMode == .off {
                // オフ:地図はぼかして暗くなり、ピン無しのアイコンが中央に出る
                Color.black.opacity(0.45)
                VStack(spacing: 8) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("位置は、共有していません")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color(hex: "BCBBC0"))
                }
            } else if model.pins.isEmpty {
                Text("昨日と今日、位置つきの写真はまだありません")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "BCBBC0"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.black.opacity(0.55)))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 14)
            }
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .consumesTap()
        .accessibilityLabel("地図。撮った場所は、約500mの範囲でだけ表示されます")
    }

    /// 地図の中心:自分のおおまかな位置(なければ、ピンの中心)
    private var centerCoordinate: CLLocationCoordinate2D? {
        if let mine = model.pins.first(where: { $0.isMine }) {
            return CLLocationCoordinate2D(latitude: mine.latitude, longitude: mine.longitude)
        }
        if let latest = ApproxLocationCache.latest {
            return CLLocationCoordinate2D(latitude: latest.latitude, longitude: latest.longitude)
        }
        guard !model.pins.isEmpty else { return nil }
        let lat = model.pins.map(\.latitude).reduce(0, +) / Double(model.pins.count)
        let lon = model.pins.map(\.longitude).reduce(0, +) / Double(model.pins.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func recenter() {
        guard let center = centerCoordinate else { return }
        camera = .region(MKCoordinateRegion(center: center, latitudinalMeters: 3200, longitudinalMeters: 3200))
    }

    // MARK: 5. 昨日の写真(2列)

    private var tilesGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("昨日の写真")
                .font(V5.mono(9.5))
                .tracking(0.16 * 9.5)
                .foregroundStyle(Color(hex: "8E8E93"))
            if section.tiles.isEmpty {
                Text("昨日は、まだ届いていません")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(section.tiles) { tile in
                        let unlocked = section.unlockedIDs.contains(tile.id)
                        V5GroupTileView(
                            tile: tile,
                            isUnlocked: unlocked,
                            level: unlocked ? .l3 : .l0,
                            scale: 1,
                            burst: nil,
                            shake: 0,
                            isActive: true,
                            onTap: { point in onOpenTile(point, tile.id) }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 地図のピン

/// 「撮った場所」:その人の写真のモザイク(解禁前)/ 小さな写真(解禁後)の小さなカード型ピン+撮った時刻
private struct PlacePinView: View {
    let pin: SharedPlacePin

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                MosaicView(tiny: pin.tiny, key: pin.id, level: pin.isUnlocked ? .l2 : .l0)
            }
            .frame(width: 38, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(pin.isMine ? V5.amber : .white.opacity(0.7), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.5), radius: 4)
            Text(shortTime)
                .font(V5.mono(9.5, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(.black.opacity(0.6)))
        }
        .accessibilityLabel("撮った場所。\(shortTime)")
    }

    private var shortTime: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f.string(from: pin.capturedAt)
    }
}
