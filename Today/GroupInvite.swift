import CloudKit
import CoreImage.CIFilterBuiltins
import Photos
import Security
import SwiftData
import SwiftUI
import UIKit

// MARK: - 設定

/// グループの招待(リンク・合言葉・QR)。
///
/// - リンク:later://join?shareUrl=<CKShare の URL>(GroupJoinLink)。CKShare をそのまま使う
/// - 合言葉:「hikari-2741」の形。CloudKit 公開 DB の invite_<合言葉> に、CKShare の URL を置く(重複したら選びなおす)
/// - QR:中身はリンクと同じ URL
enum InviteConfig {
    /// 共有シートに渡す文面(あおる言葉は入れない)
    /// 日本語の 文面は 変えない。アプリを 英語で 使っている 人が 送る ときだけ 英語版
    static func shareMessage(groupName: String, url: URL, english: Bool = AppLanguage.isEnglish) -> String {
        if english {
            return "You're invited to \"\(groupName)\". Open yesterday together on Lattag.\n\(url.absoluteString)"
        }
        return "「\(groupName)」に招待されました。Lattag で、昨日をひらきあいましょう。\n\(url.absoluteString)"
    }

    /// CKShare の URL → 招待リンク(アプリを直接ひらく later://join)
    static func joinLink(shareURL: URL) -> URL {
        GroupJoinLink.buildURL(shareURL: shareURL) ?? shareURL
    }

    /// 招待リンク(later://join・CKShare の URL)から、CKShare の URL を取り出す。ちがう URL なら nil
    static func shareURL(from url: URL) -> URL? {
        if let shareURL = GroupJoinLink.extractShareURL(from: url) { return shareURL }
        return GroupJoinLink.isCKShareURL(url) ? url : nil
    }
}

extension Notification.Name {
    /// 指定のグループ(object: UUID)の画面をひらく
    static let openGroupRequested = Notification.Name("openGroupRequested")
}

// MARK: - v46:合言葉の 英語の ことば

/// やさしい 英語の ことば(4〜6文字)。食べ物・空・色・もの・生きもの・自然 など、意味が はっきりして
/// 悪い意味に ならない ものだけ。合言葉「#peach408」の 「peach」の ぶぶんに 使う
enum GroupPassphraseWords {
    static let list = [
        // 食べ物
        "peach", "mango", "apple", "grape", "melon", "lemon", "berry", "cherry", "olive", "guava",
        "mochi", "udon", "curry", "bento", "cocoa", "honey", "syrup", "bagel", "pasta", "pizza",
        "bread", "toast", "candy", "cookie", "donut", "waffle", "yogurt", "sushi", "ramen", "soba",
        // 空・天気
        "cloud", "storm", "sunny", "windy", "rainy", "snowy", "misty", "frost", "shine", "spark",
        "light", "dawn", "dusk", "noon", "tide", "ocean", "river", "lake", "pond", "creek",
        "shore", "beach", "coral", "pearl", "stone", "sand", "dune", "cliff", "cave", "hill",
        "peak", "ridge", "grove", "forest", "woods", "field", "trail", "comet", "planet", "galaxy",
        "nebula", "aurora", "meteor", "cosmos",
        // 色
        "mint", "teal", "navy", "gold", "cream", "beige", "khaki", "rose", "lilac", "azure",
        "slate", "amber", "ivory", "bronze",
        // 生きもの
        "otter", "panda", "koala", "tiger", "zebra", "camel", "llama", "bunny", "puppy", "kitty",
        "robin", "swan", "crane", "heron", "finch", "falcon", "eagle", "beaver", "rabbit", "turtle",
        "whale", "shark", "salmon", "trout", "perch", "gecko", "mouse", "squid", "crab", "shrimp",
        // もの
        "candle", "pillow", "basket", "ribbon", "button", "pocket", "ticket", "ladder", "mirror", "window",
        "garden", "meadow", "bridge", "cabin", "tent", "kite", "swing", "bench", "chair", "table",
        "plate", "spoon", "bowl", "vase", "frame", "clock", "lamp", "paper", "pencil", "crayon",
        // 自然・植物
        "dream", "magic", "charm", "gleam", "bloom", "petal", "leaf", "branch", "stem", "seed",
        "valley", "canyon", "desert", "island", "sunset", "autumn", "winter", "spring", "summer", "maple",
        "pine", "cedar", "birch", "willow", "lotus", "daisy", "tulip", "violet", "orchid", "cotton",
        "velvet", "denim", "linen", "wool", "satin", "clover", "acorn", "pebble", "ripple", "breeze",
    ]
}

// MARK: - リンク・合言葉

@MainActor
enum GroupInviteService {
    enum InviteError: Error {
        case notReady
        case notFound
    }

    /// グループの招待リンク(CKShare の URL を later://join で包んだもの)
    static func link(for group: LaterGroup, context: ModelContext) async throws -> URL {
        guard let cloudKitManager = CloudKitManager.current else { throw InviteError.notReady }
        let sharing = GroupSharingService(container: cloudKitManager.container, modelContext: context, cloudKitManager: cloudKitManager)
        let shareURL = try await sharing.fetchOrCreateShareURL(for: group)
        return InviteConfig.joinLink(shareURL: shareURL)
    }

    /// 合言葉の形。新しい形(v46:peach408・ハイフンなし・数字2〜3桁)と、
    /// 古い形(hikari-2741・ハイフン+4桁)の どちらも 受けつける
    static func isPassphrase(_ code: String) -> Bool {
        code.range(of: #"^[a-z]+-\d{4}$"#, options: .regularExpression) != nil
            || code.range(of: #"^[a-z]+\d{2,3}$"#, options: .regularExpression) != nil
    }

    /// v46:やさしい 英語の ことば(4〜6文字・食べ物・空・色・もの など)。合言葉「#peach408」に 使う
    private static let words = GroupPassphraseWords.list

    /// v46:数字は 2〜3桁・2〜9だけ(0・1は o・l・i と まぎらわしいので 使わない)
    private static func randomDigits() -> String {
        let length = Int.random(in: 2...3)
        return (0..<length).map { _ in String(Int.random(in: 2...9)) }.joined()
    }

    /// グループの合言葉。まだ登録していなければ、公開 DB の invite_<合言葉> に登録する(重複したら選びなおす)
    static func passphrase(for group: LaterGroup, context: ModelContext) async throws -> String {
        if isPassphrase(group.inviteCode) { return group.inviteCode }
        guard let cloudKitManager = CloudKitManager.current else { throw InviteError.notReady }
        let sharing = GroupSharingService(container: cloudKitManager.container, modelContext: context, cloudKitManager: cloudKitManager)
        let shareURL = try await sharing.fetchOrCreateShareURL(for: group)
        let database = cloudKitManager.container.publicCloudDatabase
        for _ in 0..<6 {
            let code = "\(words.randomElement()!)\(randomDigits())"
            let record = CKRecord(recordType: AppRecordType.groupInvite, recordID: CKRecord.ID(recordName: "invite_\(code)"))
            record["shareURL"] = shareURL.absoluteString
            record["groupID"] = group.id.uuidString
            do {
                // 同じ合言葉のレコードがすでにあれば失敗する保存で、重複を防ぐ
                let (results, _) = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged)
                if case .failure(let error) = results[record.recordID] {
                    if let ckError = error as? CKError, ckError.code == .serverRecordChanged { continue }
                    throw error
                }
            } catch let error as CKError where error.code == .serverRecordChanged {
                continue
            }
            group.inviteCode = code
            try? context.save()
            cloudKitManager.markForUpload(group: group)
            return code
        }
        throw InviteError.notFound
    }

    /// 入力を照合できる形にそろえる:全角・半角(NFKC)/ 空白と「#」「＃」を取る / カタカナ → ひらがな → ローマ字
    /// (古い合言葉の単語はローマ字なので、「ひかり」「ヒカリ」も「hikari」になる)/ 小文字 /
    /// 単語と数字のあいだの「-」が抜けていれば補う(古い形だけ。「hikari 2741」「hikari2741」)。
    /// v46:新しい形(peach408)は「#」つき(「#peach408」)で表示するので、前後の「#」「＃」も取りのぞく
    static func normalizePassphrase(_ input: String) -> String {
        var text = input.precomposedStringWithCompatibilityMapping
        text = text.components(separatedBy: .whitespacesAndNewlines).joined()
        text = text.replacingOccurrences(of: "#", with: "").replacingOccurrences(of: "＃", with: "")
        text = text.applyingTransform(.hiraganaToKatakana, reverse: true) ?? text
        text = text.applyingTransform(.latinToHiragana, reverse: true) ?? text
        text = text.replacingOccurrences(of: "ー", with: "-").replacingOccurrences(of: "‐", with: "-").lowercased()
        if let range = text.range(of: #"^[a-z]+\d{4}$"#, options: .regularExpression), range == text.startIndex..<text.endIndex,
           let digits = text.firstIndex(where: \.isNumber) {
            text.insert("-", at: digits)
        }
        return text
    }

    /// 合言葉 → CKShare の URL。`timeout` 秒で返らなければ通信の失敗として扱う
    static func resolve(passphrase input: String, timeout: Double) async throws -> URL {
        try await withThrowingTaskGroup(of: URL.self) { group in
            group.addTask { try await resolve(passphrase: input) }
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw InviteError.notReady
            }
            defer { group.cancelAll() }
            guard let url = try await group.next() else { throw InviteError.notReady }
            return url
        }
    }

    /// 合言葉 → CKShare の URL
    static func resolve(passphrase input: String) async throws -> URL {
        guard let cloudKitManager = CloudKitManager.current else { throw InviteError.notReady }
        let code = normalizePassphrase(input)
        guard isPassphrase(code) else { throw InviteError.notFound }
        do {
            let record = try await cloudKitManager.container.publicCloudDatabase.record(for: CKRecord.ID(recordName: "invite_\(code)"))
            guard let string = record["shareURL"] as? String, let url = URL(string: string) else { throw InviteError.notFound }
            return url
        } catch let error as CKError where error.code == .unknownItem {
            throw InviteError.notFound
        }
    }

    /// 招待を受ける画面に出すもの(CKShare とグループのレコードから。投稿の中身は読まない)
    struct Invitation {
        let shareURL: URL
        let groupName: String
        let memberLimit: Int
        let colorIndex: Int
        let iconData: Data?
    }
}

// MARK: - QR

enum InviteQR {
    /// 明るい面に濃い点・誤り訂正 H(中央の丸のぶんを逃がす)。拡大はぼかさない。
    static func image(for url: URL, size: CGFloat = 460) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "H"
        guard let output = filter.outputImage else { return nil }
        let scale = (size / output.extent.width).rounded(.down)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: max(1, scale), y: max(1, scale)))
        guard let cgImage = CIContext(options: [.useSoftwareRenderer: false]).createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - 招待カード(グループのシート)

/// なかまを招待:主ボタン(招待リンクをおくる・オレンジ)+ 副ボタン2つ(合言葉のコピー / QRコード)。
/// 白い「グループの昨日を見る」より主役にはしない。満員のときは、全体がグレーで押せない。
struct InviteCard: View {
    let group: LaterGroup
    let summary: GroupSummary
    let haptics: ExposureHaptics
    let onShowQR: (URL) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var passphrase: String?
    @State private var passphraseUnavailable = false
    @State private var copied = false
    @State private var isPreparingLink = false
    @State private var shareText: String?
    @State private var shimmerStart = Date()
    @State private var linkError: String?

    private var isFull: Bool { summary.isFull }
    private static let warm = Color(hex: "FFB078")
    private static let pink = Color(hex: "FF8FA0")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(isFull ? AnyShapeStyle(.white.opacity(0.08)) : AnyShapeStyle(Self.warm.opacity(0.2)))
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isFull ? Color(hex: "8E8E93") : Self.warm)
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text("なかまを招待")
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(.white)
                    Text(isFull ? "いっぱいです。だれかが抜けると、また入れます。" : "リンクか合言葉で、すぐ入れます")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "C9B8AE"))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

            primaryButton
                .padding(.top, 14)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { passphraseButton; qrButton }
                VStack(spacing: 10) { passphraseButton; qrButton }
            }
            .padding(.top, 10)

            if !isFull {
                Text(linkError ?? "リンクをひらいた人が、そのまま入れます。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color(hex: "A89A92"))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .cloudDiagnosticsOnLongPress()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(isFull
                      ? AnyShapeStyle(Color.white.opacity(0.04))
                      : AnyShapeStyle(LinearGradient(stops: [
                          .init(color: Self.warm.opacity(0.16), location: 0),
                          .init(color: Self.pink.opacity(0.08), location: 0.55),
                          .init(color: .white.opacity(0.04), location: 1),
                      ], startPoint: .topLeading, endPoint: .bottomTrailing)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(isFull ? Color.white.opacity(0.07) : Self.warm.opacity(0.22), lineWidth: 1)
        )
        .task(id: group.id) { await loadPassphrase() }
        .sheet(isPresented: Binding(get: { shareText != nil }, set: { if !$0 { shareText = nil } })) {
            ShareSheet(activityItems: [LattagShareItem.trip(text: shareText ?? "", groupName: group.name)]) { _ in shareText = nil }
        }
    }

    // MARK: 主ボタン:招待リンクをおくる

    private var primaryButton: some View {
        Button(action: sendLink) {
            HStack(spacing: 8) {
                if isPreparingLink {
                    ProgressView().tint(Color(hex: "1A0D08"))
                } else {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 15, weight: .semibold))
                }
                Text("招待リンクをおくる").font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(Color(hex: "1A0D08"))
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                Capsule().fill(LinearGradient(colors: [Self.warm, Self.pink], startPoint: .leading, endPoint: .trailing))
            )
            .overlay {
                // 5秒ごとに、白い光の帯が1回すっと走る(最初は1.6秒後)
                if !isFull, !reduceMotion {
                    ButtonShimmer(start: shimmerStart)
                        .clipShape(Capsule())
                }
            }
            .shadow(color: Self.pink.opacity(isFull ? 0 : 0.28), radius: 14, y: 6)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(isFull || isPreparingLink)
        .opacity(isFull ? 0.4 : 1)
    }

    // MARK: 副ボタン:合言葉 / QRコード

    private var passphraseButton: some View {
        Button(action: copyPassphrase) {
            HStack(spacing: 7) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.system(size: 13, weight: .semibold))
                if copied {
                    Text("コピーしました").font(.system(size: 13, weight: .semibold))
                } else {
                    Text("合言葉").font(.system(size: 12.5))
                    Text(passphrase ?? (isFull ? "—" : passphraseUnavailable ? "準備中" : "…"))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(copied ? Color(hex: "B8F5D2") : .white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 10)
            .background(Capsule().fill(copied ? Color(hex: "B8F5D2").opacity(0.12) : .white.opacity(0.1)))
            .overlay(Capsule().strokeBorder(copied ? Color(hex: "B8F5D2").opacity(0.4) : .white.opacity(0.1), lineWidth: 1))
            .animation(.easeOut(duration: 0.2), value: copied)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(isFull || passphrase == nil)
        .opacity(isFull ? 0.4 : 1)
        .accessibilityLabel(copied ? "コピーしました" : "合言葉、\(passphrase ?? "準備中")。タップでコピー")
    }

    private var qrButton: some View {
        Button(action: showQR) {
            HStack(spacing: 7) {
                Image(systemName: "qrcode").font(.system(size: 14, weight: .semibold))
                Text("QRコード").font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Capsule().fill(.white.opacity(0.1)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
        .disabled(isFull || isPreparingLink)
        .opacity(isFull ? 0.4 : 1)
    }

    // MARK: 動き

    private func loadPassphrase() async {
        guard !isFull else { return }
        do {
            passphrase = try await GroupInviteService.passphrase(for: group, context: modelContext)
            passphraseUnavailable = false
        } catch {
            passphraseUnavailable = true
        }
    }

    private func sendLink() {
        withLink { url in shareText = InviteConfig.shareMessage(groupName: group.name, url: url) }
    }

    private func showQR() {
        withLink(onShowQR)
    }

    private func withLink(_ action: @escaping (URL) -> Void) {
        guard !isFull, !isPreparingLink else { return }
        isPreparingLink = true
        linkError = nil
        Task {
            defer { isPreparingLink = false }
            do {
                action(try await GroupInviteService.link(for: group, context: modelContext))
            } catch {
                CloudDiagnostics.record("招待リンクを つくる", CloudDiagnostics.report(error) + "\n(\(String(describing: error)))")
                Haptics.play(.warn)
                linkError = "リンクを つくれませんでした。もういちど"
            }
        }
    }

    /// 合言葉だけをコピー。ごく軽く1回。1.8秒で元にもどる
    private func copyPassphrase() {
        guard let passphrase, !isFull else { return }
        UIPasteboard.general.string = passphrase
        haptics.playTransient(intensity: 0.25, sharpness: 0.4)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { copied = false }
    }
}

/// 主ボタンの光の帯(5秒ごと・最初は1.6秒後)
private struct ButtonShimmer: View {
    let start: Date

    var body: some View {
        TimelineView(.animation) { context in
            GeometryReader { proxy in
                let elapsed = context.date.timeIntervalSince(start) - 1.6
                let phase = elapsed < 0 ? -1 : elapsed.truncatingRemainder(dividingBy: 5)
                if phase >= 0, phase < 0.9 {
                    let u = HomeMotion.ease(phase / 0.9)
                    let w = proxy.size.width * 0.35
                    LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: w)
                        .rotationEffect(.degrees(12))
                        .offset(x: -w + (proxy.size.width + w) * u)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - QR のオーバーレイ

/// 画面いっぱい(暗く 78% + ぼかし)に、白い角丸のカードで QR。中央にグループの色の丸。
/// v58 §4:Trip パス(チケット)。裏側は 今までと 同じ CKShare の 招待リンク/合言葉。見た目だけ チケット風に 包みなおす。
struct InviteQROverlay: View {
    let group: LaterGroup
    let url: URL
    let auraIndex: Int
    var memberCount: Int = 1
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @AccessibilityFocusState private var closeFocused: Bool
    @State private var shown = false
    @State private var passphrase: String?
    @State private var shareText: String?
    @State private var copied = false
    @State private var savedToast = false

    var body: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.92)).ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture(perform: onClose)

            VStack(spacing: 18) {
                Text(verbatim: "YOUR TRIP IS READY")
                    .font(Darkroom.mono(10.5)).tracking(0.2 * 10.5)
                    .foregroundStyle(.white.opacity(0.7))

                passCard

                HStack(spacing: 10) {
                    passButton(title: "Share", icon: "square.and.arrow.up") {
                        Haptics.play(.click)
                        shareText = InviteConfig.shareMessage(groupName: group.name, url: url)
                    }
                    passButton(title: "Save", icon: "arrow.down.to.line") {
                        Haptics.play(.click)
                        savePassImage()
                    }
                    passButton(title: copied ? "Copied" : "Copy key", icon: copied ? "checkmark" : "doc.on.doc") {
                        Haptics.play(.click)
                        UIPasteboard.general.string = passphrase.map { "#\($0)" } ?? url.absoluteString
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
                    }
                }

                Button(action: onClose) {
                    Text(verbatim: "Start the trip")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 200, height: 48)
                        .background(Capsule().fill(.white.opacity(0.12)))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityFocused($closeFocused)
            }
            .padding(.horizontal, 24)
            .scaleEffect(shown || reduceMotion ? 1 : 0.94)
            .rotationEffect(.degrees(shown || reduceMotion ? 0 : 8))
            .offset(y: shown || reduceMotion ? 0 : 60)
            .opacity(shown || reduceMotion ? 1 : 0)
        }
        .overlay(alignment: .top) {
            if savedToast {
                Text(verbatim: "保存しました").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(.black.opacity(0.8)))
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: Binding(get: { shareText != nil }, set: { if !$0 { shareText = nil } })) {
            ShareSheet(activityItems: [LattagShareItem.trip(text: shareText ?? "", groupName: group.name)]) { _ in shareText = nil }
        }
        .task(id: group.id) {
            passphrase = try? await GroupInviteService.passphrase(for: group, context: modelContext)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .timingCurve(0.3, 1.1, 0.4, 1, duration: 0.76)) { shown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { closeFocused = true }
        }
    }

    /// v58 §4:上半分(表紙・行き先・メンバー)・ミシン目・下半分(紙色・QR・KEY)
    private var passCard: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: "LATER · TRIP PASS")
                    .font(Darkroom.mono(8.5)).tracking(0.18 * 8.5).foregroundStyle(.white.opacity(0.6))
                Text(verbatim: group.name)
                    .font(Typo.title(40)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5)
                Text(verbatim: "\(memberCount) aboard · 23 / day")
                    .font(Darkroom.mono(9.5)).foregroundStyle(LaterColor.liveGreen)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Color(hex: "1B1B1B"), Color(hex: "0B0B0C")], startPoint: .top, endPoint: .bottom))

            perforation

            VStack(spacing: 14) {
                if let image = InviteQR.image(for: url) {
                    Image(uiImage: image)
                        .interpolation(.none).resizable().scaledToFit()
                        .frame(width: 160, height: 160)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white))
                        .accessibilityLabel("このグループに入れる、QRコード")
                }
                VStack(spacing: 4) {
                    Text(verbatim: "KEY").font(Darkroom.mono(8.5)).tracking(0.2 * 8.5).foregroundStyle(Color(hex: "6C6C73"))
                    if let passphrase {
                        Text(verbatim: "#\(passphrase)").font(Typo.ui(900, 17)).foregroundStyle(Color(hex: "111111"))
                    } else {
                        ProgressView().tint(Color(hex: "111111"))
                    }
                }
                Text(verbatim: "SCAN TO JOIN · あした 9:00 に 現像")
                    .font(Darkroom.mono(8)).tracking(0.1 * 8).foregroundStyle(Color(hex: "8A8A84"))
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(Color(hex: "EFE7DA"))
            .overlay(alignment: .trailing) {
                HStack(spacing: 3) {
                    Capsule().fill(.white).frame(width: 3)
                    Capsule().fill(LaterColor.red).frame(width: 3)
                    Capsule().fill(LaterColor.gold).frame(width: 3)
                }
                .padding(.trailing, 10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 30, y: 16)
        .overlay(alignment: .topTrailing) {
            let colors = GroupRingMath.auraPalettes[auraIndex % GroupRingMath.auraPalettes.count]
            Circle()
                .fill(LinearGradient(colors: [colors[0], colors[1]], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .padding(14)
                .accessibilityHidden(true)
        }
    }

    /// ミシン目(点線 + 左右の 半円の 切りかき)
    private var perforation: some View {
        ZStack {
            Rectangle().fill(Color(hex: "0B0B0C"))
            HStack {
                Circle().fill(.black.opacity(0.92)).frame(width: 20, height: 20).offset(x: -10)
                Spacer()
                Circle().fill(.black.opacity(0.92)).frame(width: 20, height: 20).offset(x: 10)
            }
            Rectangle().fill(.clear)
                .overlay(
                    HStack(spacing: 5) {
                        ForEach(0..<24, id: \.self) { _ in Circle().fill(Color(hex: "3A3A3E")).frame(width: 2, height: 2) }
                    }
                )
        }
        .frame(height: 20)
        .mask(Rectangle())
    }

    private func passButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                Text(verbatim: title).font(.system(size: 10.5, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.1)))
        }
        .buttonStyle(PressScaleStyle())
    }

    @MainActor
    private func savePassImage() {
        let renderer = ImageRenderer(content: passCard.frame(width: 320))
        renderer.scale = UIScreen.main.scale
        guard let image = renderer.uiImage else { return }
        Task {
            if PHPhotoLibrary.authorizationStatus(for: .addOnly) == .notDetermined {
                _ = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            }
            guard PHPhotoLibrary.authorizationStatus(for: .addOnly) == .authorized else { return }
            try? await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAsset(from: image)
            }
            withAnimation { savedToast = true }
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation { savedToast = false }
        }
    }
}
