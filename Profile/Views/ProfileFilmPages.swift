import SwiftUI
import UIKit

/// プロフィール(フィルム版)の「ひらいた日」。1日=1ページで、縦にめくる。
/// フィルムの中央と連動する(focusKey を、フィルムと同じ値で持つ)。
struct ProfileFilmPages: View {
    /// 古い順(ProfileShot.shots)。ページは新しい日が上。
    let shots: [WeekDayPoint]
    let startKey: String
    @Binding var focusKey: String?
    let imageFor: (WeekDayPoint) -> UIImage?
    let haptics: ProfileFilmHaptics
    let exposure: ExposureHaptics
    /// その日の写真を、共有先すべてから消す(親が、近い日へ移す)
    let onDelete: (WeekDayPoint) -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShareOpen = false
    @State private var isHolding = false
    @State private var ringProgress: Double = 0

    private static let accent = Color(hex: "FF8A1F")
    private static let groupGradient = [Color(hex: "FFB48A"), Color(hex: "9A6CF0")]
    private static let mondoGradient = [Color(hex: "6AA8FF"), Color(hex: "7BE0C8")]
    private static let deleteRed = Color(hex: "FF6B5E")

    /// 新しい日が上(フィルムの左から右と同じ向き)
    private var pages: [WeekDayPoint] {
        Array(shots.reversed())
    }

    private var current: WeekDayPoint? {
        pages.first { $0.id == focusKey }
    }

    var body: some View {
        ZStack {
            Color(hex: "0A0806").ignoresSafeArea()

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(pages) { point in
                        page(point)
                            .containerRelativeFrame(.vertical)
                            .id(point.id)
                            .scrollTransition(axis: .vertical) { content, phase in
                                let away = min(1, abs(phase.value))
                                return content
                                    .scaleEffect(1 - 0.1 * away)
                                    .opacity(1 - 0.9 * away)
                                    .offset(y: phase.value * -30)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $focusKey)
            .scrollIndicators(.hidden)
            .ignoresSafeArea()

            topBar

            if isShareOpen, let current, current.opened {
                shareSheet(current)
                    .transition(.opacity)
                    .zIndex(5)
            }
        }
        .onChange(of: focusKey) { old, _ in
            // ページが変わったら、1枚ごとに tick(ページ連動の変化のときは、フィルム側では鳴らさない)
            guard old != nil else { return }
            isShareOpen = false
            haptics.play(.tick)
        }
    }

    // MARK: - ページ

    private func page(_ point: WeekDayPoint) -> some View {
        ZStack(alignment: .bottomLeading) {
            Color(hex: "FBF8F1")

            if point.opened {
                photoLayer(point)
            } else {
                developingLayer(point)
            }

            shades
            tagText(point)
            stamp(point)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // 現像中の今日を押した:ぷるっと(何も起きない)
            if !point.opened { haptics.play(.nope) }
        }
    }

    /// 写真は紙のふちの内側(6pt)。角丸は46pt。
    @ViewBuilder
    private func photoLayer(_ point: WeekDayPoint) -> some View {
        if let image = imageFor(point) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .saturation(1.1)
                .contrast(1.05)
                .clipShape(RoundedRectangle(cornerRadius: 46, style: .continuous))
                .padding(6)
                .offset(y: -36)
        }
    }

    /// 今日(現像中):ミルク色の膜と、中央のリング(108pt)。進みの数字だけを出す。
    private func developingLayer(_ point: WeekDayPoint) -> some View {
        let progress = ProfileStarLayout.developProgress(shotAt: point.date, now: Date())
        return ZStack {
            Circle()
                .stroke(Self.accent.opacity(0.25), lineWidth: 2.6)
                .frame(width: 108, height: 108)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Self.accent, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                .frame(width: 108, height: 108)
                .rotationEffect(.degrees(-90))
            Text("\(ProfileStarLayout.developPercent(progress))%")
                .font(.system(size: 22, design: .monospaced))
                .foregroundStyle(Color(hex: "3A2A20"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日。現像中、\(ProfileStarLayout.developPercent(progress))パーセント")
    }

    private var shades: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color(hex: "080503").opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 190)
            Spacer(minLength: 0)
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "0A0705").opacity(0.94), location: 0),
                    .init(color: Color(hex: "0A0705").opacity(0.8), location: 0.22),
                    .init(color: Color(hex: "0A0705").opacity(0.32), location: 0.58),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 470)
        }
        .allowsHitTesting(false)
    }

    private func tagText(_ point: WeekDayPoint) -> some View {
        let text = point.tags.map { "#\($0)" }.joined(separator: "  ")
        return Text(text)
            .font(.system(size: 30, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 10, y: 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 26)
            .padding(.bottom, 196)
            .allowsHitTesting(false)
    }

    private func stamp(_ point: WeekDayPoint) -> some View {
        Text(ProfileShot.filmStamp(for: point.date))
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(Self.accent)
            .shadow(color: Self.accent.opacity(0.6), radius: 6)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 24)
            .padding(.bottom, 210)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: - 上のボタン

    private var topBar: some View {
        HStack {
            Button {
                haptics.play(.light)
                onClose()
            } label: {
                ProfileFilmGlass(systemName: "chevron.down")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("とじる")

            Spacer(minLength: 0)

            if let current, current.opened {
                Button {
                    haptics.play(.light)
                    withAnimation(.easeOut(duration: 0.3)) { isShareOpen = true }
                } label: {
                    ProfileFilmGlass(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("共有先を見る")
            }
        }
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)
    }

    // MARK: - 共有シート(文字は置かない。行とスイッチと、消すボタンだけ)

    private func shareSheet(_ point: WeekDayPoint) -> some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.62)
                .contentShape(Rectangle())
                .onTapGesture { closeShare() }

            VStack(spacing: 0) {
                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                VStack(spacing: 14) {
                    ForEach(Array(point.groups.enumerated()), id: \.offset) { _, group in
                        shareRow(gradient: Self.groupGradient, title: group.name, isOn: true)
                    }
                    shareRow(gradient: Self.mondoGradient, title: "Mondo", isOn: point.isOnMondo)
                }
                .padding(.top, 22)

                deleteButton(point)
                    .padding(.top, 22)
                    .padding(.bottom, 22)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
            .background(
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "1F1A16"), Color(hex: "110D0A")], startPoint: .top, endPoint: .bottom))
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .onDisappear {
            if isHolding { endHold() }
        }
    }

    /// 共有先の行。スイッチの見た目だけ(オン・オフを切りかえる操作は、まだ付けていない)。
    private func shareRow(gradient: [Color], title: String, isOn: Bool) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 46, height: 46)
            Text(title)
                .font(.system(size: 16.5, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 8)
            Capsule()
                .fill(isOn ? Self.accent : .white.opacity(0.14))
                .frame(width: 42, height: 24)
                .overlay(
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .offset(x: isOn ? 9 : -9)
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)に共有。\(isOn ? "オン" : "オフ")")
    }

    /// ゴミ箱の長押し。1.2秒で一周すると消える。途中で離すと、リングがもどるだけ。
    private func deleteButton(_ point: WeekDayPoint) -> some View {
        ZStack {
            Circle()
                .fill(Self.deleteRed.opacity(0.1))
            Circle()
                .stroke(Self.deleteRed.opacity(0.15), lineWidth: 3.5)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(Self.deleteRed, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "trash")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color(hex: "FF8A7A"))
        }
        .frame(width: 76, height: 76)
        .scaleEffect(isHolding ? 1.06 : 1)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in beginHold() }
                .onEnded { _ in endHold() }
        )
        .task(id: isHolding) {
            guard isHolding else { return }
            try? await Task.sleep(for: .seconds(ProfileFilmMath.holdDuration))
            guard !Task.isCancelled else { return }
            complete(point)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("この日の写真を消す。長押しで実行")
        .accessibilityAction { complete(point) }
    }

    private func beginHold() {
        guard !isHolding else { return }
        isHolding = true
        withAnimation(reduceMotion ? nil : .linear(duration: ProfileFilmMath.holdDuration)) {
            ringProgress = 1
        }
        exposure.beginHold(duration: ProfileFilmMath.holdDuration, intensity: 0.15...0.8)
    }

    private func endHold() {
        guard isHolding else { return }
        isHolding = false
        exposure.cancelHold()
        withAnimation(.easeOut(duration: ProfileFilmMath.releaseDuration)) {
            ringProgress = 0
        }
    }

    private func complete(_ point: WeekDayPoint) {
        isHolding = false
        exposure.cancelHold()
        ringProgress = 0
        haptics.play(.del)
        isShareOpen = false
        onDelete(point)
    }

    private func closeShare() {
        haptics.play(.light)
        withAnimation(.easeOut(duration: 0.3)) { isShareOpen = false }
    }
}

/// 上のガラスの丸ボタン(文字なし)
struct ProfileFilmGlass: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(Circle().fill(.ultraThinMaterial))
            .background(Circle().fill(.black.opacity(0.26)))
            .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}
