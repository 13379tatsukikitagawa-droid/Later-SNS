import Foundation
import ImageIO
import LinkPresentation
import SwiftUI
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import Later_再度

/// v13 の6つの直し:写真の現像(9:00)/ 追加シートの色 / グループのカード・ともだちのコントラスト /
/// 招待の共有 / フィルム / 触覚の間引き / サムネイルの向き
@MainActor
struct V13FixTests {
    private let calendar = Calendar.current

    private func date(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        // 特別な日(0:00〜9:00 も 撮れる日など)に かからない、ふつうの日を 基準にする
        let base = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20))!
        let day = calendar.date(byAdding: .day, value: dayOffset, to: base)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    // MARK: 1. 今日撮った写真は、あしたの朝 9:00 まで見えない

    @Test func 撮った写真は_つぎの9時から見える() {
        let taken = date(0, 14)
        #expect(!PhotoDevelop.isDeveloped(takenAt: taken, now: date(0, 23, 59)))
        #expect(!PhotoDevelop.isDeveloped(takenAt: taken, now: date(1, 8, 59)))
        #expect(PhotoDevelop.isDeveloped(takenAt: taken, now: date(1, 9, 0)))
    }

    @Test func 前日23時59分に撮った写真は_日をまたいでも9時まで見えない() {
        let taken = date(-1, 23, 59)
        #expect(!PhotoDevelop.isDeveloped(takenAt: taken, now: date(0, 0, 30)))
        #expect(!PhotoDevelop.isDeveloped(takenAt: taken, now: date(0, 8, 59)))
        #expect(PhotoDevelop.isDeveloped(takenAt: taken, now: date(0, 9, 0)))
    }

    @Test func 当日9時ちょうどに撮った写真は_つぎの日の9時まで見えない() {
        let taken = date(0, 9, 0)
        #expect(PhotoDevelop.developDate(takenAt: taken) == date(1, 9, 0))
        #expect(!PhotoDevelop.isDeveloped(takenAt: taken, now: date(0, 9, 1)))
        #expect(PhotoDevelop.isDeveloped(takenAt: taken, now: date(1, 9, 0)))
    }

    @Test func プロフィールの判定も同じ関数() {
        for taken in [date(0, 9, 0), date(0, 14), date(-1, 23, 59)] {
            for now in [date(0, 8, 59), date(0, 9, 0), date(1, 8, 59), date(1, 9, 0)] {
                // 【B】プロフィールも OwnReveal(前日の 写真は 今日 撮った枚数だけ ひらく)
                #expect(ProfileShot.isOpened(capturedAt: taken, now: now, ownCaptureDates: [taken]) == OwnReveal.isOpen(takenAt: taken, now: now, ownCaptureDates: [taken]))
            }
        }
    }

    @Test func 撮った直後のプロフィールに_写真を出さない() {
        let taken = date(0, 14)
        let source = ProfileShot.Source(dayKey: ExposureDayStore.dayKey(for: taken), captureDate: taken, colorHex: "FF8800", locationName: nil, tags: [], groups: [ProfileShareGroup(name: "ゼミ", otherMemberCount: 3)], isOnMondo: false)
        let point = ProfileShot.visibleShots(from: [source], now: date(0, 14, 1)).first
        #expect(point?.opened == false)
        #expect(point?.showsPhoto == false)
        #expect(point?.color == nil)
    }

    @Test func 七日のフィルム_今日と_9時前の昨日は現像中() {
        let film = HomeLayerRules.filmToday(state: .night, shotsToday: 1)
        #expect(film == .developing)
        #expect(HomeLayerRules.filmToday(state: .rest, shotsToday: 0) == .rest)
        #expect(HomeLayerRules.filmToday(state: .dawn, shotsToday: 0) == .empty)
        #expect(HomeLayerRules.filmLabel(ago: 0) == "きょう")
        #expect(HomeLayerRules.filmLabel(ago: 1) == "きのう")
        #expect(HomeLayerRules.filmLabel(ago: 2) == "おととい")
        #expect(HomeLayerRules.filmLabel(ago: 4) == "4日前")
        #expect(HomeLayerRules.filmOpacity(ago: 0) == 1)
        #expect(abs(HomeLayerRules.filmOpacity(ago: 6) - 0.5) < 0.0001)
    }

    // MARK: 2. ハッシュタグ(ProfileShelfTests にも)

    @Test func ハッシュタグは上限をボタンで知らせ_文字は切らない() {
        let long = String(repeating: "あ", count: ProfileShelfEditRules.tagMaxLength + 3)
        #expect(ProfileShelfEditRules.cleanTag(long) == long)
        #expect(ProfileShelfEditRules.addButton(input: long, tags: []).title == "3文字へらす")
        #expect(ProfileShelfEditRules.add("＃夕焼け", to: []) == .added(["夕焼け"]))
    }

    // MARK: 3. コントラスト(4.5 以上)

    private func luminance(_ color: Color) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> Double { let c = Double(c); return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    private func contrast(_ a: Color, _ b: Color) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    @Test func 追加シートの文字は_昼も夜も読める() {
        for night in [false, true] {
            let c = GroupAddColors(isNight: night)
            #expect(contrast(c.title, c.sheet) >= 4.5)
            #expect(contrast(c.primaryText, c.primaryBg) >= 4.5)
            #expect(contrast(c.primaryNote, c.primaryBg) >= 4.5)
            #expect(contrast(c.secondaryText, c.secondaryBg) >= 4.5)
            #expect(contrast(c.note, c.secondaryBg) >= 4.5)
            #expect(contrast(c.note, c.sheet) >= 4.5)
            #expect(contrast(c.secondaryIcon, c.secondaryIconBg) >= 4.5)
            // 2つのボタンは、面の色で見分けられる
            #expect(contrast(c.primaryBg, c.secondaryBg) >= 4.5)
        }
    }

    @Test func 追加シートの色は表のとおり() {
        let day = GroupAddColors(isNight: false), night = GroupAddColors(isNight: true)
        #expect(UIColor(day.sheet) == UIColor(PaletteHex(rgb: 0xFFFFFF).color))
        #expect(UIColor(night.sheet) == UIColor(PaletteHex(rgb: 0x1C1C1F).color))
        #expect(UIColor(day.primaryBg) == UIColor(PaletteHex(rgb: 0x111114).color))
        #expect(UIColor(night.secondaryLine) == UIColor(PaletteHex(rgb: 0x5A5A62).color))
        #expect(Palette.day.groupAdd == day)
        #expect(Palette.night.groupAdd == night)
    }

    @Test func あと何個は_10ひくいまの数() {
        #expect(GroupAddSheet.remainingText(groupCount: 0) == "あと10個、入れます")
        #expect(GroupAddSheet.remainingText(groupCount: 3) == "あと7個、入れます")
        #expect(GroupAddSheet.remainingText(groupCount: 10).hasPrefix("10個まで"))
    }

    @Test func グループのカードの文字は_8色とも昼夜で読める() {
        for palette in [Palette.day, Palette.night] {
            for aura in GroupRingMath.auraPalettes {
                let surface = GroupCardColors.surface(base: palette.bg, tint: aura[1])
                #expect(contrast(palette.ink, surface) >= 4.5)
                #expect(contrast(GroupCardColors.count(night: palette.isNight), surface) >= 4.5)
            }
        }
    }

    @Test func ともだちの撮ったの文字は_昼も夜も読める() {
        #expect(contrast(LayerFriendColors.shotText(night: false), Palette.day.bg) >= 4.5)
        #expect(contrast(LayerFriendColors.shotText(night: true), Palette.night.bg) >= 4.5)
        #expect(contrast(LayerFriendColors.shotText(night: true), .black) >= 4.5)
        #expect(contrast(GroupAddColors(isNight: false).note, Palette.day.bg) >= 4.5)
        #expect(contrast(GroupAddColors(isNight: true).note, Palette.night.bg) >= 4.5)
    }

    @Test func フィルムのコマの文字が読める() {
        #expect(contrast(DevelopingFrame.ink, DevelopingFrame.milk) >= 4.5)
        #expect(contrast(Color(hex: "9A3A0A"), DevelopingFrame.milk) >= 4.5)
        #expect(contrast(Color(hex: "FF8A3D"), Color(hex: "141417")) >= 4.5)
        #expect(contrast(Color(hex: "B4B4BC"), Color(hex: "1E1E23")) >= 4.5)
    }

    // MARK: ともだちの状態

    private func friend(hasShot: Bool, knockOff: Bool = false, isMe: Bool = false) -> HomeFriend {
        HomeFriend(id: "ck-a", name: "あお", avatarData: nil, seed: UUID(), hasShot: hasShot, city: nil, mosaicTiny: nil, mosaicKey: "k", tag: nil, knockOff: knockOff, isMe: isMe, groupIDs: [])
    }

    @Test func ともだちの一言() {
        #expect(HomeLayerRules.friendStatus(state: .dawn, friend: friend(hasShot: true), knockedToday: false) == .shot)
        #expect(HomeLayerRules.friendStatus(state: .dawn, friend: friend(hasShot: false), knockedToday: false) == .canKnock)
        #expect(HomeLayerRules.friendStatus(state: .dawn, friend: friend(hasShot: false), knockedToday: true) == .knocked)
        #expect(HomeLayerRules.friendStatus(state: .dawn, friend: friend(hasShot: false, knockOff: true), knockedToday: false) == .notYet)
        #expect(HomeLayerRules.friendStatus(state: .dawn, friend: friend(hasShot: false, isMe: true), knockedToday: false) == .notYet)
        #expect(HomeLayerRules.friendStatus(state: .night, friend: friend(hasShot: false), knockedToday: false) == .resting)
    }

    // MARK: 4. 招待の共有

    @Test func 共有する本文の形() {
        let url = URL(string: "later://join?shareUrl=x")!
        #expect(GroupInviteItemSource.text(groupName: "帰り道の4人", passphrase: "hikari-2741", url: url)
                == "「帰り道の4人」に招待されました。\n合言葉:hikari-2741\nlater://join?shareUrl=x")
        #expect(GroupInviteItemSource.text(groupName: "ゼミ", passphrase: nil, url: url)
                == "「ゼミ」に招待されました。\nlater://join?shareUrl=x")
        #expect(GroupInviteItemSource.title(groupName: "ゼミ") == "「ゼミ」に招待されました。")
    }

    @Test func 共有シートの左上は_Laterのアイコン() {
        let image = UIImage(named: "LaterShareIcon")
        #expect(image != nil)
        #expect(image.map { $0.size.width * $0.scale } == 1024)
        let source = GroupInviteItemSource(groupName: "ゼミ", passphrase: "hikari-2741", url: URL(string: "later://join?shareUrl=x")!)
        let metadata = source.activityViewControllerLinkMetadata(UIActivityViewController(activityItems: [], applicationActivities: nil))
        #expect(metadata?.title == "「ゼミ」に招待されました。")
        #expect(metadata?.iconProvider != nil)
        #expect(metadata?.originalURL?.absoluteString == "later://join?shareUrl=x")
    }

    // MARK: 7. 触覚の間引き

    @Test func 横スクロールのカチは_最短の間をあけ_はやいフリックは3コマに1回() {
        var now = Date(timeIntervalSince1970: 0)
        var played = 0
        let tick = ScrollTickHaptics(minInterval: 0.07, clock: { now }, play: { played += 1 })
        tick.step("a")          // 画面に出ただけ:鳴らさない
        #expect(played == 0)
        now += 0.3; tick.step("b")
        #expect(played == 1)
        now += 0.3; tick.step("b")   // 同じコマ:鳴らさない
        #expect(played == 1)
        // はやいフリック(0.03秒ごと)で9コマ:3コマに1回
        for i in 0..<9 { now += 0.03; tick.step("f\(i)") }
        #expect(played == 4)
    }

    @Test func 層に入るカチは_140ms() {
        var now = Date(timeIntervalSince1970: 0)
        var played = 0
        let tick = ScrollTickHaptics(minInterval: 0.14, clock: { now }, play: { played += 1 })
        tick.step(0)
        now += 0.5; tick.step(1)
        now += 0.13; tick.step(2)   // はやい:3つに1つ & 140ms 未満は鳴らさない
        #expect(played == 1)
        now += 0.5; tick.step(3)
        #expect(played == 2)
    }

    // MARK: 6. サムネイルの向き

    @Test func サムネイルは写真の向き_EXIF_を焼きこむ() throws {
        // 横長(200×100)のピクセルに「右に90度」(6)の向きをつけた JPEG = 見た目はたて長
        let pixels = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 100), format: {
            let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f
        }()).image { ctx in
            UIColor.orange.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        }
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(pixels.cgImage), [kCGImagePropertyOrientation: 6] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))

        let thumb = try #require(PhotoColor.thumbnailData(fromData: data as Data))
        let image = try #require(UIImage(data: thumb))
        #expect(image.imageOrientation == .up)
        #expect(image.size.height > image.size.width)
    }
}
