import CloudKit
import CoreImage.CIFilterBuiltins
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
    static func shareMessage(groupName: String, url: URL) -> String {
        "「\(groupName)」に招待されました。Later で、昨日をひらきあいましょう。 \(url.absoluteString)"
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

    /// 合言葉の形(hikari-2741)
    static func isPassphrase(_ code: String) -> Bool {
        code.range(of: #"^[a-z]+-\d{4}$"#, options: .regularExpression) != nil
    }

    private static let words = [
        "hikari", "sora", "kumo", "ame", "umi", "kaze", "hoshi", "tsuki", "mori", "yuki",
        "hana", "nagi", "asa", "yoru", "niji", "kawa", "michi", "tori", "aki", "natsu",
    ]

    /// グループの合言葉。まだ登録していなければ、公開 DB の invite_<合言葉> に登録する(重複したら選びなおす)
    static func passphrase(for group: LaterGroup, context: ModelContext) async throws -> String {
        if isPassphrase(group.inviteCode) { return group.inviteCode }
        guard let cloudKitManager = CloudKitManager.current else { throw InviteError.notReady }
        let sharing = GroupSharingService(container: cloudKitManager.container, modelContext: context, cloudKitManager: cloudKitManager)
        let shareURL = try await sharing.fetchOrCreateShareURL(for: group)
        let database = cloudKitManager.container.publicCloudDatabase
        for _ in 0..<6 {
            let code = "\(words.randomElement()!)-\(Int.random(in: 1000...9999))"
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

    /// 入力を照合できる形にそろえる:全角・半角(NFKC)/ 空白を取る / カタカナ → ひらがな → ローマ字
    /// (合言葉の単語はローマ字なので、「ひかり」「ヒカリ」も「hikari」になる)/ 小文字 /
    /// 単語と数字のあいだの「-」が抜けていれば補う(「hikari 2741」「hikari2741」)。
    static func normalizePassphrase(_ input: String) -> String {
        var text = input.precomposedStringWithCompatibilityMapping
        text = text.components(separatedBy: .whitespacesAndNewlines).joined()
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
            ShareSheet(activityItems: [shareText ?? ""]) { _ in shareText = nil }
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
                linkError = "いまは、リンクをつくれません。少しあとで、もう一度ためしてください。"
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
struct InviteQROverlay: View {
    let url: URL
    let auraIndex: Int
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var closeFocused: Bool
    @State private var shown = false

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Color.black.opacity(0.78).ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.white)
                    if let image = InviteQR.image(for: url) {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .padding(20)
                            .accessibilityLabel("このグループに入れる、QRコード")
                    }
                    let colors = GroupRingMath.auraPalettes[auraIndex % GroupRingMath.auraPalettes.count]
                    Circle()
                        .fill(LinearGradient(colors: [colors[0], colors[1]], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 34, height: 34)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                        .accessibilityHidden(true)
                }
                .frame(width: 230, height: 230)
                .scaleEffect(shown || reduceMotion ? 1 : 0.9)
                .opacity(shown || reduceMotion ? 1 : 0)

                Text("となりの人に、見せてください")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 26)
                Text("カメラで読みとると、このグループに入れます。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color(hex: "BCBBC0"))
                    .padding(.top, 8)

                Button(action: onClose) {
                    Text("とじる")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 160, height: 48)
                        .background(Capsule().fill(.white.opacity(0.12)))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityFocused($closeFocused)
                .padding(.top, 28)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.timingCurve(0.22, 0.8, 0.24, 1, duration: 0.5)) { shown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { closeFocused = true }
        }
    }
}
