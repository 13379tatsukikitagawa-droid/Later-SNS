import CloudKit
import os
import SwiftUI
import UIKit

/// v22 J-2:CloudKit の失敗を 黙らせない。
/// - 利用者には やさしい文(「リンクを つくれませんでした。もういちど」)
/// - 開発用には、長押しで 見られる 詳細(CKError のコード・どのレコードの どのフィールドか)。
///   TestFlight で起きても、ログを取らずに 原因が わかるよう、最後の1件を 端末に のこす。
enum CloudDiagnostics {
    private static let key = "cloud.diagnostics.last.v1"
    private static let logger = Logger(subsystem: "Later", category: "CloudDiagnostics")

    private static let trailKey = "cloud.diagnostics.trail.v1"

    /// 最後に のこした 詳細(長押しで 見る)。どこまで 進んだか(経過)も いっしょに
    static var last: String? {
        let detail = UserDefaults.standard.string(forKey: key)
        let trail = UserDefaults.standard.string(forKey: trailKey)
        switch (detail, trail) {
        case (nil, nil): return nil
        case (let d?, nil): return d
        case (nil, let t?): return "経過:\n\(t)"
        case (let d?, let t?): return "\(d)\n\n経過:\n\(t)"
        }
    }

    /// 経過を はじめから 書きなおす(グループを つくる ・ など)
    static func begin(_ title: String) {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.set("\(time()) \(title)", forKey: trailKey)
        logger.info("[trail] \(title, privacy: .public)")
    }

    /// 経過に 1行 たす(どこで 止まったか わかるように)
    static func step(_ text: String) {
        let trail = UserDefaults.standard.string(forKey: trailKey) ?? ""
        UserDefaults.standard.set(trail + "\n\(time()) \(text)", forKey: trailKey)
        logger.info("[trail] \(text, privacy: .public)")
    }

    private static func time() -> String {
        Date().formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
    }

    /// 詳細を のこす(ログにも 出す)
    static func record(_ title: String, _ body: String) {
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
        let text = "[\(stamp)] \(title)\n\(body)"
        UserDefaults.standard.set(text, forKey: key)
        logger.error("\(text, privacy: .public)")
    }

    /// CKError → 1行ずつ:コード・どのレコード・どのフィールド・サーバーの文
    static func report(_ error: Error, labels: [CKRecord.ID: String] = [:]) -> String {
        var lines = [describe(error)]
        if let ckError = error as? CKError, let partial = ckError.partialErrorsByItemID {
            for (itemID, subError) in partial {
                let id = itemID as? CKRecord.ID
                let label = id.flatMap { labels[$0] } ?? id?.recordName ?? "\(itemID)"
                lines.append("  \(label): \(describe(subError))")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// レコードごとの結果(modifyRecords の saveResults)から、失敗だけを 1行ずつ
    static func report(results: [CKRecord.ID: Result<CKRecord, Error>], labels: [CKRecord.ID: String]) -> String {
        results.compactMap { id, result -> String? in
            guard case .failure(let error) = result else { return nil }
            return "\(labels[id] ?? id.recordName): \(describe(error))"
        }
        .sorted()
        .joined(separator: "\n")
    }

    static func describe(_ error: Error) -> String {
        guard let ckError = error as? CKError else { return String(describing: error) }
        let text = serverText(ckError)
        var line = "CKError \(ckError.code.rawValue) \(text)"
        if let type = recordType(in: text) { line += " ・ type=\(type)" }
        if let field = fieldName(in: text) { line += " ・ field=\(field)" }
        return line
    }

    /// スキーマ(本番に フィールドや型が ない)が 原因の 失敗か
    static func isSchemaError(_ error: Error) -> Bool {
        func check(_ e: Error) -> Bool {
            guard let ckError = e as? CKError else { return false }
            let text = serverText(ckError).lowercased()
            return text.contains("production schema") || text.contains("cannot create new field") || text.contains("cannot create new type")
                || text.contains("unknown field") || text.contains("did not find record type")
        }
        if check(error) { return true }
        if let ckError = error as? CKError, let partial = ckError.partialErrorsByItemID {
            return partial.values.contains(where: check)
        }
        return false
    }

    /// 「field 'faceStyle'」「field "faceStyle"」の中の 名前
    static func fieldName(in text: String) -> String? {
        match(text, #"field ['"“]([^'"”]+)['"”]"#)
    }

    /// 「type 'LaterGroup'」「record type 'LaterGroup'」「record 'LaterGroup'」の中の 名前
    static func recordType(in text: String) -> String? {
        match(text, #"(?:record type|type|record) ['"“]([^'"”]+)['"”]"#)
    }

    private static func serverText(_ error: CKError) -> String {
        (error.userInfo["ServerErrorDescription"] as? String)
            ?? (error.userInfo[NSDebugDescriptionErrorKey] as? String)
            ?? error.localizedDescription
    }

    private static func match(_ text: String, _ pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              m.numberOfRanges > 1, let range = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
}

// MARK: - 長押しで 詳細を 見る(開発用)

private struct CloudDiagnosticsOnLongPress: ViewModifier {
    @State private var shows = false
    @State private var text = ""

    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 0.8) {
                text = CloudDiagnostics.last ?? "記録は ありません"
                Haptics.play(.tick)
                shows = true
            }
            .alert("くわしい内容(開発用)", isPresented: $shows) {
                Button("コピー") { UIPasteboard.general.string = text }
                Button("とじる", role: .cancel) {}
            } message: {
                Text(text)
            }
    }
}

extension View {
    /// 長押しで、最後の CloudKit の 失敗の 詳細を 出す
    func cloudDiagnosticsOnLongPress() -> some View { modifier(CloudDiagnosticsOnLongPress()) }
}
