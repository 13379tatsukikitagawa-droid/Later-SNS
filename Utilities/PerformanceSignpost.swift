import Foundation
import os

/// 「アプリ全体が重い」調査用の計測ヘルパー。os_signpostでInstrumentsの
/// Points of Interestトラックにも記録しつつ、経過時間をos.Logger経由でも
/// 出力するため、Instrumentsを使わずXcodeのコンソール(またはConsole.app)だけでも
/// 数値を確認できるようにしてある。
///
/// 使い方:
///   let token = PerformanceSignpost.begin("Gallery.openPhoto")
///   ...何か重い処理...
///   PerformanceSignpost.end("Gallery.openPhoto", token, detail: "photoID=\(id)")
///
/// 対になるbegin/endを挟めない単発イベントには`event(_:detail:)`を使う。
enum PerformanceSignpost {
    private static let osLog = OSLog(subsystem: "jp.shotoku.later", category: "Performance")
    private static let logger = Logger(subsystem: "jp.shotoku.later", category: "Performance")

    struct Token {
        fileprivate let signpostID: OSSignpostID
        fileprivate let start: CFAbsoluteTime
    }

    @discardableResult
    static func begin(_ name: StaticString, detail: String = "") -> Token {
        let id = OSSignpostID(log: osLog)
        if detail.isEmpty {
            os_signpost(.begin, log: osLog, name: name, signpostID: id)
        } else {
            os_signpost(.begin, log: osLog, name: name, signpostID: id, "%{public}s", detail)
        }
        return Token(signpostID: id, start: CFAbsoluteTimeGetCurrent())
    }

    static func end(_ name: StaticString, _ token: Token, detail: String = "") {
        os_signpost(.end, log: osLog, name: name, signpostID: token.signpostID)
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - token.start) * 1000
        let nameString = "\(name)"
        if detail.isEmpty {
            logger.notice("[Perf] \(nameString, privacy: .public): \(elapsedMs, format: .fixed(precision: 1), privacy: .public)ms")
        } else {
            logger.notice("[Perf] \(nameString, privacy: .public): \(elapsedMs, format: .fixed(precision: 1), privacy: .public)ms (\(detail, privacy: .public))")
        }
    }

    /// begin/endを挟めない、瞬間的なマーカー用(例: 「起動プロセス開始」等)。
    static func event(_ name: StaticString, detail: String = "") {
        if detail.isEmpty {
            os_signpost(.event, log: osLog, name: name)
            logger.notice("[Perf] \(("\(name)"), privacy: .public)")
        } else {
            os_signpost(.event, log: osLog, name: name, "%{public}s", detail)
            logger.notice("[Perf] \(("\(name)"), privacy: .public): \(detail, privacy: .public)")
        }
    }
}
