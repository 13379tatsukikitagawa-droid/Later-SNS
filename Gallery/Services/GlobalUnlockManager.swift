import Foundation
public import Combine

public enum SelfPhotoPolicy: String, Codable {
    case viewOthersOnly
    case blockUntilSelfDone
}

public final class GlobalUnlockManager: ObservableObject {
    @Published public private(set) var nextUnlockAt: Date
    @Published public private(set) var isGloballyUnlocked: Bool = false
    @Published public private(set) var notifications: [String] = []
    @Published public var selfGoalAchieved: Bool = false // external binding (user's own capture state)
    @Published public var policy: SelfPhotoPolicy = .viewOthersOnly

    private var timerCancellable: AnyCancellable?
    private let minSpan: TimeInterval = 0.5 * 24 * 60 * 60
    private let maxSpan: TimeInterval = 2.0 * 24 * 60 * 60

    public init(lastUnlockEndedAt: Date? = nil, seed: UInt64? = nil) {
        let base = lastUnlockEndedAt ?? Date()
        self.nextUnlockAt = GlobalUnlockManager.computeNextUnlock(from: base, seed: seed)
        self.checkImmediateUnlock()
        self.startGlobalTimer()
    }

    deinit {
        timerCancellable?.cancel()
    }

    // MARK: - Public API
    @MainActor public func reschedule(from base: Date = Date(), seed: UInt64? = nil) {
        isGloballyUnlocked = false
        nextUnlockAt = GlobalUnlockManager.computeNextUnlock(from: base, seed: seed)
        startGlobalTimer()
    }

    // Whether current user can view feed depending on policy and state
    public var canViewFeed: Bool {
        if isGloballyUnlocked == false { return false }
        switch policy {
        case .viewOthersOnly: return true
        case .blockUntilSelfDone: return selfGoalAchieved
        }
    }

    // MARK: - Core Logic
    private func startGlobalTimer() {
        timerCancellable?.cancel()
        let pub = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        timerCancellable = pub.sink { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        if Date() >= nextUnlockAt && !isGloballyUnlocked {
            isGloballyUnlocked = true
            appendNotification("現像が完了しました！今すぐチェック！")
            // After unlock, stop periodic checks until rescheduled
            timerCancellable?.cancel()
        }
    }

    private func checkImmediateUnlock() {
        if Date() >= nextUnlockAt {
            isGloballyUnlocked = true
        }
    }

    private func appendNotification(_ message: String) {
        notifications.append(message)
        if notifications.count > 20 {
            notifications.removeFirst(notifications.count - 20)
        }
    }

    // MARK: - Scheduling Helpers
    static func computeNextUnlock(from base: Date, seed: UInt64? = nil) -> Date {
        // Random span between 12h and 48h
        let minSpan: TimeInterval = 0.5 * 24 * 60 * 60
        let maxSpan: TimeInterval = 2.0 * 24 * 60 * 60
        var span: TimeInterval
        if let seed = seed {
            var seeded = SeededGenerator(seed: seed)
            span = Double.random(in: minSpan...maxSpan, using: &seeded)
        } else {
            var generator = SystemRandomNumberGenerator()
            span = Double.random(in: minSpan...maxSpan, using: &generator)
        }
        var candidate = base.addingTimeInterval(span)
        candidate = avoidNightHours(candidate)
        return candidate
    }

    static func avoidNightHours(_ date: Date) -> Date {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let hour = comps.hour else { return date }
        // Night hours 22:00 - 09:00
        if hour >= 22 || hour < 9 {
            // next day at 9:00 to 21:59 random
            var start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: date)!
            if hour >= 22 {
                start = cal.date(byAdding: .day, value: 1, to: start)!
            }
            let end = cal.date(bySettingHour: 21, minute: 59, second: 0, of: start)!
            let delta = end.timeIntervalSince(start)
            let rand = TimeInterval.random(in: 0...delta)
            return start.addingTimeInterval(rand)
        }
        return date
    }
}

// MARK: - Seeded RNG
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64) { self.state = seed }
    public mutating func next() -> UInt64 {
        // xorshift64*
        var x = state
        x ^= x >> 12
        x ^= x << 25
        x ^= x >> 27
        state = x
        return x &* 2685821657736338717
    }
}
