// HomeHeroScroll_example.swift  ― v89 の 見本(そのまま 使わなくて よい。形を まねる)
// ねらい:Home の 上の かたまり(黄緑の # ・ レンズ ・ 横スライド)の どこを なぞっても、Home 全体が たてに スクロールする。
// ルール:
//  1. たての ScrollView が いちばん 外。上の かたまりは その「中身」の 1つ(上に 重ねない ・ overlay / ZStack で 外に 出さない)。
//  2. # の 帯は ただの 絵:.allowsHitTesting(false)。ジェスチャーを 付けない。
//  3. 押せる のは レンズの 丸 だけ:Button + ButtonStyle(押している 間は configuration.isPressed)。
//  4. 横スライドは ScrollView(.horizontal) + .scrollTargetBehavior(.paging)。自前の DragGesture を 使わない。
//  5. DragGesture(minimumDistance: 0) / .highPriorityGesture / .simultaneousGesture(DragGesture()) を この かたまりに 付けない。
import SwiftUI

struct HomeScreen: View {
    @State private var page: Int? = 0
    var body: some View {
        ScrollView(.vertical) {                         // ← 1. いちばん 外
            VStack(spacing: 0) {
                HomeHeader()                             // ロゴ ・ 帯 ・ アイコン
                HomeHero(page: $page)                    // ← 上の かたまり(高さ 600)
                    .frame(height: 600)
                HomeLowerSections()                      // Today ・ Yesterday … (下の かたまり)
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.black)
    }
}

struct HomeHero: View {
    @Binding var page: Int?
    var body: some View {
        ScrollView(.horizontal) {                        // ← 4. 横は ScrollView に まかせる(たて/よこ を iOS が 見分ける)
            LazyHStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in
                    HeroPage(index: i)
                        .containerRelativeFrame(.horizontal)
                        .id(i)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $page)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

struct HeroPage: View {
    let index: Int
    var body: some View {
        ZStack {
            HashBars()                                    // 黄緑の #
                .allowsHitTesting(false)                  // ← 2. 絵 だけ
            if index == 0 {
                Button { /* 撮影へ */ } label: { LensView() }
                    .buttonStyle(LensPressStyle())        // ← 3. 押す 物は Button
                    .contentShape(Circle())               // 当たりは 丸 だけ
                    .frame(width: 230, height: 230)
                    .offset(y: -40)
            }
        }
    }
}

struct LensPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }
}

// レンズの つや(光の 向き)を 指で 動かして いた 場合 → 指を やめて、かたむき で 動かす
// final class TiltModel: ObservableObject { … CMMotionManager(deviceMotionUpdateInterval = 1/30) … }

// --- UI テスト(LattagUITests)---
// func testScrollFromHash() {
//   let app = XCUIApplication(); app.launchArguments += ["-debugState", "home0"]; app.launch()
//   for (x, y) in [(0.10, 0.32), (0.90, 0.32), (0.50, 0.45)] {
//     let s = app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
//     s.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.05)))
//     XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 2), "(\(x),\(y)) から スクロール できない")
//     app.swipeDown(); app.swipeDown()
//   }
// }
