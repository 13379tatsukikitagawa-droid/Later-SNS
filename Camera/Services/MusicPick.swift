// MusicPick.swift
// v22 L-4:今日の 1曲。サービスに よらない形で 持つ(見る側は リンクを 押すと 自分のアプリで ひらく)。
// - Apple Music:MusicKit で 検索(ライブラリは 読まない)
// - Spotify:リンクを はる だけ(ログイン連携は しない)。曲名・ジャケットは oEmbed(ログイン なし)
// CloudKit の LaterPhoto には musicTitle / musicArtist / musicArtworkURL / musicLink / musicService(すべて STRING・省略可)。
// 曲が ないときは 1つも 書かない(Production に 項目が まだ なくても、曲なしの 保存は 成功する)。

import Foundation
import MusicKit

/// 今日の 1曲
nonisolated struct MusicPick: Codable, Equatable, Sendable {
    enum Service: String, Codable, Sendable {
        case apple
        case spotify
    }

    var title: String
    var artist: String
    var artworkURL: String?
    var link: String?
    var service: Service

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

// MARK: - リンク(Apple Music / Spotify)

nonisolated enum MusicLink {
    /// はった 文字から、曲の リンクを 見つける
    static func find(in text: String) -> (url: URL, service: MusicPick.Service)? {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0 == "\n" })
        for word in words {
            guard let url = URL(string: String(word)), let host = url.host?.lowercased() else { continue }
            if host == "open.spotify.com" || host == "spotify.link" { return (url, .spotify) }
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

    /// Spotify の oEmbed(ログイン なし)。とれなければ nil(リンクだけ 保存して「♪ 曲を きいてみる」)
    static func spotifyInfo(for url: URL, session: URLSession = .shared) async -> (title: String, artworkURL: String?)? {
        var components = URLComponents(string: "https://open.spotify.com/oembed")
        components?.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        guard let endpoint = components?.url else { return nil }
        struct OEmbed: Decodable {
            let title: String?
            let thumbnail_url: String?
        }
        do {
            let (data, response) = try await session.data(from: endpoint)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let info = try JSONDecoder().decode(OEmbed.self, from: data)
            guard let title = info.title, !title.isEmpty else { return nil }
            return (title, info.thumbnail_url)
        } catch {
            return nil
        }
    }

    /// リンクから 1曲を つくる。曲名が とれなければ「曲を きいてみる」(リンクだけ)
    static func pick(from url: URL, service: MusicPick.Service) async -> MusicPick {
        switch service {
        case .spotify:
            if let info = await spotifyInfo(for: url) {
                return MusicPick(title: info.title, artist: "Spotify", artworkURL: info.artworkURL, link: url.absoluteString, service: .spotify)
            }
        case .apple:
            if let id = appleSongID(from: url), let song = await AppleMusicCatalog.song(id: id) {
                return song
            }
        }
        return MusicPick(title: "曲を きいてみる", artist: service == .spotify ? "Spotify" : "Apple Music", artworkURL: nil, link: url.absoluteString, service: service)
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

    /// Apple Music に 入っているか(試聴だけなら 入っていなくても 検索は できる)
    static func hasSubscription() async -> Bool {
        guard let subscription = try? await MusicSubscription.current else { return false }
        return subscription.canPlayCatalogContent
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
        let response = try await request.response()
        return response.songs.map { song in
            Found(id: song.id.rawValue, pick: pick(from: song), previewURL: song.previewAssets?.first?.url)
        }
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
            service: .apple
        )
    }
}
