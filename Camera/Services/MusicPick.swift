// MusicPick.swift
// v22 L-4:今日の 1曲。サービスに よらない形で 持つ(見る側は リンクを 押すと 自分のアプリで ひらく)。
// - Apple Music:MusicKit で 検索(ライブラリは 読まない)
// - Apple Music に 入っていない人は、music.apple.com の リンクを はる(Spotify は 使わない)
// CloudKit の LaterPhoto には musicTitle / musicArtist / musicArtworkURL / musicLink / musicService(すべて STRING・省略可)。
// 曲が ないときは 1つも 書かない(Production に 項目が まだ なくても、曲なしの 保存は 成功する)。

import Foundation
import MusicKit
import os

/// 今日の 1曲
nonisolated struct MusicPick: Codable, Equatable, Sendable {
    enum Service: String, Codable, Sendable {
        case apple
    }

    var title: String
    var artist: String
    var artworkURL: String?
    var link: String?
    var service: Service
    /// v89:カタログの 曲 ID と 30秒の 試聴(音の ファイルは 保存しない)
    var songID: String? = nil
    var previewURL: String? = nil

    /// 撮影画面の ピルに 出す 短い 名前
    var shortTitle: String {
        title.count > 14 ? String(title.prefix(13)) + "…" : title
    }
}

// MARK: - その日の 1曲(端末の中だけ・日ごと)

enum MusicDraft {
    private static var key: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return "later.musicDraft." + formatter.string(from: Date())
    }

    static func load() -> MusicPick? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(MusicPick.self, from: data)
    }

    static func save(_ pick: MusicPick?) {
        if let pick, let data = try? JSONEncoder().encode(pick) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

// MARK: - リンク(Apple Music)

nonisolated enum MusicLink {
    /// はった 文字から、曲の リンクを 見つける
    static func find(in text: String) -> (url: URL, service: MusicPick.Service)? {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0 == "\n" })
        for word in words {
            guard let url = URL(string: String(word)), let host = url.host?.lowercased() else { continue }
            if host == "music.apple.com" || host == "itunes.apple.com" { return (url, .apple) }
        }
        return nil
    }

    /// Apple Music の 曲の ID(…/album/名前/123?i=456 の 456、…/song/名前/456 の 456)
    static func appleSongID(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let i = components?.queryItems?.first(where: { $0.name == "i" })?.value, !i.isEmpty { return i }
        let parts = url.pathComponents
        if let index = parts.firstIndex(of: "song"), let last = parts.last, index < parts.count - 1, last.allSatisfy(\.isNumber) { return last }
        return nil
    }

    /// リンクから 1曲を つくる。曲名が とれなければ「曲を きいてみる」(リンクだけ)
    static func pick(from url: URL, service: MusicPick.Service) async -> MusicPick {
        if let id = appleSongID(from: url), let song = await AppleMusicCatalog.song(id: id) {
            return song
        }
        return MusicPick(title: "曲を きいてみる", artist: "Apple Music", artworkURL: nil, link: url.absoluteString, service: service)
    }
}

// MARK: - Apple Music(MusicKit)

enum AppleMusicCatalog {
    enum Access: Equatable {
        case ready
        /// まだ きいていない
        case notDetermined
        /// 許可されなかった(設定アプリで 変える)
        case denied
        /// 使えない(制限・地域など)
        case unavailable
    }

    static var access: Access {
        switch MusicAuthorization.currentStatus {
        case .authorized: .ready
        case .notDetermined: .notDetermined
        case .denied: .denied
        default: .unavailable
        }
    }

    static func requestAccess() async -> Access {
        switch await MusicAuthorization.request() {
        case .authorized: .ready
        case .notDetermined: .notDetermined
        case .denied: .denied
        default: .unavailable
        }
    }

    private static let logger = Logger(subsystem: "Later", category: "AppleMusic")

    /// Apple Music に 入っているか(試聴だけなら 入っていなくても 検索は できる)
    static func hasSubscription() async -> Bool {
        guard let subscription = try? await MusicSubscription.current else { return false }
        return subscription.canPlayCatalogContent
    }

    /// 開発用:いまの 許可と サブスクの 状態(画面の 小さな 文字・os_log)
    static func statusLine() async -> String {
        let auth: String = {
            switch MusicAuthorization.currentStatus {
            case .authorized: "authorized"
            case .notDetermined: "notDetermined"
            case .denied: "denied"
            case .restricted: "restricted"
            @unknown default: "unknown"
            }
        }()
        var line = "auth=\(auth)"
        do {
            let subscription = try await MusicSubscription.current
            line += " ・ sub: canPlay=\(subscription.canPlayCatalogContent) canBecome=\(subscription.canBecomeSubscriber) cloudLibrary=\(subscription.hasCloudLibraryEnabled)"
        } catch {
            line += " ・ sub: error \(describe(error))"
        }
        logger.info("\(line, privacy: .public)")
        return line
    }

    /// 本当の エラー(型・localizedDescription・underlyingError・MusicKit の 中身)を 1つの 文に
    static func describe(_ error: Error) -> String {
        var parts = ["\(type(of: error))"]
        if let token = error as? MusicTokenRequestError {
            switch token {
            case .developerTokenRequestFailed: parts.append("developerTokenRequestFailed(App ID の MusicKit が 有効でない・反映待ちの 可能性)")
            case .permissionDenied: parts.append("permissionDenied")
            case .privacyAcknowledgementRequired: parts.append("privacyAcknowledgementRequired(ミュージックアプリで 同意が 必要)")
            case .userNotSignedIn: parts.append("userNotSignedIn(Apple ID に サインインしていない)")
            case .userTokenRequestFailed: parts.append("userTokenRequestFailed")
            case .userTokenRevoked: parts.append("userTokenRevoked")
            case .unknown: parts.append("unknown")
            @unknown default: parts.append("\(token)")
            }
        }
        if let data = error as? MusicDataRequest.Error {
            parts.append("status=\(data.status) code=\(data.code) title=\(data.title) detail=\(data.detailText)")
        }
        let ns = error as NSError
        parts.append("\(ns.domain) \(ns.code): \(error.localizedDescription)")
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error {
            let u = underlying as NSError
            parts.append("underlying: \(type(of: underlying)) \(u.domain) \(u.code) \(underlying.localizedDescription)")
        }
        return parts.joined(separator: " | ")
    }

    struct Found: Identifiable, Equatable {
        let id: String
        let pick: MusicPick
        /// 30秒の 試聴(あれば)
        let previewURL: URL?
    }

    /// 曲を さがす(カタログだけ。その人の ライブラリは 読まない)
    static func search(_ term: String) async throws -> [Found] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var request = MusicCatalogSearchRequest(term: trimmed, types: [Song.self])
        request.limit = 20
        let response: MusicCatalogSearchResponse
        do {
            response = try await request.response()
        } catch {
            if !(error is CancellationError) {
                logger.error("search failed term=\(trimmed, privacy: .public) error=\(describe(error), privacy: .public)")
            }
            throw error
        }
        logger.info("search ok term=\(trimmed, privacy: .public) songs=\(response.songs.count)")
        return response.songs.map { song in
            Found(id: song.id.rawValue, pick: pick(from: song), previewURL: song.previewAssets?.first?.url)
        }
    }

    /// 30秒の 試聴 URL(Apple Music に 入って いなくても 流せる)
    static func previewURL(songID: String) async -> URL? {
        guard access == .ready else { return nil }
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(songID))
        return try? await request.response().items.first?.previewAssets?.first?.url
    }

    static func song(id: String) async -> MusicPick? {
        guard access == .ready else { return nil }
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(id))
        guard let song = try? await request.response().items.first else { return nil }
        return pick(from: song)
    }

    private static func pick(from song: Song) -> MusicPick {
        MusicPick(
            title: song.title,
            artist: song.artistName,
            artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString,
            link: song.url?.absoluteString,
            service: .apple,
            songID: song.id.rawValue,
            previewURL: song.previewAssets?.first?.url?.absoluteString
        )
    }

    private static func found(_ song: Song) -> Found { Found(id: song.id.rawValue, pick: pick(from: song), previewURL: song.previewAssets?.first?.url) }

    // MARK: v89:おすすめ ・ 最近 ・ ライブラリ

    /// あなたへの おすすめ(アルバムの 1曲目を 曲として 出す)
    static func recommendations() async -> [Found] {
        guard access == .ready else { return [] }
        do {
            let response = try await MusicPersonalRecommendationsRequest().response()
            var albums: [Album] = []
            for r in response.recommendations { for item in r.items { if case .album(let a) = item { albums.append(a) } } }
            var out: [Found] = []
            await withTaskGroup(of: Song?.self) { group in
                for a in albums.prefix(10) {
                    group.addTask {
                        guard let full = try? await a.with([.tracks]), let t = full.tracks?.first else { return nil }
                        if case .song(let s) = t { return s }
                        return nil
                    }
                }
                for await s in group { if let s { out.append(found(s)) } }
            }
            return out
        } catch { logger.error("recommendations failed \(describe(error), privacy: .public)"); return [] }
    }

    /// いま 人気(世界の 日間 トップ)
    static func charts() async -> [Found] {
        guard access == .ready else { return [] }
        do {
            let request = MusicCatalogChartsRequest(kinds: [.dailyGlobalTop], types: [Song.self])
            let response = try await request.response()
            return (response.songCharts.first?.items ?? []).prefix(25).map(found)
        } catch { logger.error("charts failed \(describe(error), privacy: .public)"); return [] }
    }

    static func recent() async -> [Found] {
        guard access == .ready else { return [] }
        do {
            var request = MusicRecentlyPlayedRequest<Song>()
            request.limit = 25
            return try await request.response().items.map(found)
        } catch { logger.error("recent failed \(describe(error), privacy: .public)"); return [] }
    }

    static func library(term: String = "") async -> [Found] {
        guard access == .ready else { return [] }
        do {
            var request = MusicLibraryRequest<Song>()
            request.limit = 30
            request.sort(by: \.libraryAddedDate, ascending: false)
            if !term.isEmpty { request.filter(text: term) }
            return try await request.response().items.map(found)
        } catch { logger.error("library failed \(describe(error), privacy: .public)"); return [] }
    }
}
