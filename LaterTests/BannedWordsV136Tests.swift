import Testing
import Foundation

/// v136:画面に出る 文字に 使わない 言葉。アプリ ・ ウィジェット ・ Live Activity の ソース(文字列リテラルだけ。コメントは 見ない)と、
/// 文字列カタログ(キー ・ 訳)を 調べる。9:00 の 通知の 本文(`notification.daily.body`)も カタログに あるので ここで 見る。
struct BannedWordsV136Tests {
    static let words = ["あかり", "消灯", "仕上が", "乗りこ", "まだ、ひとり", "ここに届く", "ふってつながる"]
    private static let skipDirs: Set<String> = [".git", ".claude", ".wrangler", "node_modules", "worktrees", "Design", "Docs", "LaterTests", "LaterUITests", "server", "build", "DerivedData"]

    private static var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// 行の 後ろの `//` コメントを 取りのぞく(文字列の 中の `//` は のこす)
    static func codePart(_ line: String) -> String {
        var out = "", inStr = false
        var it = Array(line), i = 0
        while i < it.count {
            let c = it[i]
            if c == "\\" && inStr, i + 1 < it.count { out.append(c); out.append(it[i + 1]); i += 2; continue }
            if c == "\"" { inStr.toggle() }
            if !inStr, c == "/", i + 1 < it.count, it[i + 1] == "/" { break }
            out.append(c); i += 1
        }
        it = []
        return out
    }

    static func literals(in code: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: #""((?:[^"\\]|\\.)*)""#) else { return [] }
        let ns = code as NSString
        return re.matches(in: code, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range(at: 1)) }
    }

    @Test func sourcesHaveNoBannedWordsInStrings() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: Self.root.appendingPathComponent("Later 再度.xcodeproj").path) else { return }   // ソースが 手元に ない 環境では 見ない
        var hits: [String] = []
        let en = fm.enumerator(at: Self.root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])!
        for case let url as URL in en {
            if Self.skipDirs.contains(url.lastPathComponent) { en.skipDescendants(); continue }
            guard url.pathExtension == "swift", let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for (n, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("//") || t.hasPrefix("*") || t.hasPrefix("/*") { continue }
                for s in Self.literals(in: Self.codePart(String(line))) where Self.words.contains(where: s.contains) {
                    hits.append("\(url.lastPathComponent):\(n + 1): \(s.prefix(40))")
                }
            }
        }
        #expect(hits.isEmpty, "禁止語: \(hits.prefix(10))")
    }

    @Test func stringCatalogHasNoBannedWords() throws {
        let url = Self.root.appendingPathComponent("Localizable.xcstrings")
        guard let data = try? Data(contentsOf: url),
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = obj["strings"] as? [String: Any] else { return }
        var hits: [String] = []
        for (k, v) in strings {
            let blob = k + ((try? String(data: JSONSerialization.data(withJSONObject: v), encoding: .utf8)) ?? "")
            if Self.words.contains(where: blob.contains) { hits.append(k) }
        }
        #expect(hits.isEmpty, "カタログに 禁止語: \(hits.prefix(5))")
    }
}
