import SwiftUI
import UIKit

/// デバッグ用の上書き。DEBUG ビルドでだけ効く。
nonisolated enum ThemeOverride: String, Sendable {
    case automatic, day, night
}

/// 時刻から昼夜(0:00–8:59 は夜、9:00–23:59 は昼)を決める。毎秒のタイマーは使わない。
@MainActor @Observable
final class ThemeClock {
    static let overrideKey = "theme.debugOverride"

    private(set) var mode: ThemeMode
    private(set) var pendingMode: ThemeMode?

    /// true の間は切り替えを保留し、false に戻ったときに反映する。
    var isLocked: Bool = false {
        didSet {
            guard oldValue, !isLocked, let pending = pendingMode else { return }
            pendingMode = nil
            apply(pending)
        }
    }

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private let defaults: UserDefaults

    nonisolated static func isNight(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.component(.hour, from: date) < 9
    }

    init(now: Date = .now, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.mode = .day
        self.mode = resolvedMode(now: now, calendar: .current)
    }

    var debugOverride: ThemeOverride {
        ThemeOverride(rawValue: defaults.string(forKey: Self.overrideKey) ?? "") ?? .automatic
    }

    private func resolvedMode(now: Date, calendar: Calendar) -> ThemeMode {
        #if DEBUG
        switch debugOverride {
        case .day: return .day
        case .night: return .night
        case .automatic: break
        }
        #endif
        return Self.isNight(now, calendar: calendar) ? .night : .day
    }

    func refresh(now: Date = .now, calendar: Calendar = .current) {
        let next = resolvedMode(now: now, calendar: calendar)
        if isLocked {
            pendingMode = next == mode ? nil : next
            return
        }
        pendingMode = nil
        apply(next)
    }

    private func apply(_ next: ThemeMode) {
        guard next != mode else { return }
        withAnimation(.easeInOut(duration: next == .night ? 0.6 : 1.2)) {
            mode = next
        }
    }

    /// デバッグ用。release ビルドでは保存されるだけで無視される。
    func forceMode(_ override: ThemeOverride) {
        defaults.set(override.rawValue, forKey: Self.overrideKey)
        refresh()
    }

    // MARK: - スケジュール

    /// 次の 0:00 か 9:00 までの秒数
    nonisolated static func secondsUntilNextChange(from date: Date, calendar: Calendar = .current) -> TimeInterval {
        let hours = [0, 9]
        let dates = hours.compactMap {
            calendar.nextDate(after: date, matching: DateComponents(hour: $0, minute: 0, second: 0),
                              matchingPolicy: .nextTime)
        }
        guard let first = dates.min() else { return 3600 }
        return max(1, first.timeIntervalSince(date) + 0.5)
    }

    func start() {
        if observers.isEmpty {
            let center = NotificationCenter.default
            let names: [Notification.Name] = [UIApplication.significantTimeChangeNotification,
                                              .NSSystemTimeZoneDidChange]
            observers = names.map { name in
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.refresh()
                        self?.schedule()
                    }
                }
            }
        }
        refresh()
        schedule()
    }

    func stop() {
        task?.cancel()
        task = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }

    private func schedule() {
        task?.cancel()
        let seconds = Self.secondsUntilNextChange(from: .now)
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            self.refresh()
            self.schedule()
        }
    }
}
