import SwiftUI

struct CountdownBanner: View {
    // 記録: カウントダウンの開始日（その日最初のログイン判定用）
    @AppStorage("countdownStartDate") private var countdownStartDate: String = ""
    
    @State private var finished: Bool = false
    @State private var unlockManager = UnlockTimeManager.shared
    @State private var photoManager = PhotoManager.shared
    
    var onFinished: (() -> Void)?
    var showUnlockInfo: Bool = true // 解禁情報を表示するか
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let date = context.date
            let remaining = remainingSeconds(from: date)
            let _ = unlockManager.ensureTodayUnlockTime() // 解禁時刻を確保
            
            VStack(spacing: 8) {
                // 本日終了までのカウントダウン
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.white)
                    Text("本日終了まで")
                        .foregroundStyle(.white)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text(remainingString(from: remaining))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.brandGreen.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                // 解禁情報
                if showUnlockInfo {
                    unlockInfoView(date: date)
                }
            }
            .onAppear { 
                ensureStartForToday()
            }
            .onChange(of: CountdownBanner.todayKey(date: date)) {
                // 新しい日が始まったらリセット
                finished = false
                ensureStartForToday(force: true)
                _ = unlockManager.ensureTodayUnlockTime()
            }
            .task(id: remaining) {
                if !finished && remaining <= 0 {
                    finished = true
                    handleFinished()
                }
            }
        }
    }
    
    @ViewBuilder
    private func unlockInfoView(date: Date) -> some View {
        let photosTaken = photoManager.todayPhotoCount
        let dailyGoal = photoManager.dailyLimit
        let isFeedUnlocked = unlockManager.isFeedUnlocked(photosTaken: photosTaken, dailyGoal: dailyGoal)
        let _ = unlockManager.unlockedPostCount(photosTaken: photosTaken, dailyGoal: dailyGoal)
        
        HStack(spacing: 8) {
            if photosTaken < dailyGoal {
                // 目標未達成
                Image(systemName: "lock.fill")
                    .foregroundStyle(.white.opacity(0.7))
                Text("目標達成でフィード解禁")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.caption.weight(.medium))
                Spacer()
                Text("\(photosTaken)/\(dailyGoal)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else if isFeedUnlocked {
                // 解禁中
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("フィード解禁中")
                    .foregroundStyle(.white)
                    .font(.caption.weight(.medium))
                Spacer()
                if let secondsLeft = unlockManager.secondsUntilLock() {
                    Text("残り\(formatShortTime(secondsLeft))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            } else if let secondsUntil = unlockManager.secondsUntilUnlock(), secondsUntil > 0 {
                // 解禁待ち
                Image(systemName: "hourglass")
                    .foregroundStyle(.white.opacity(0.7))
                Text("フィード解禁まで")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.caption.weight(.medium))
                Spacer()
                Text(formatShortTime(secondsUntil))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                // 閲覧期限終了
                Image(systemName: "lock.fill")
                    .foregroundStyle(.white.opacity(0.7))
                Text("本日の閲覧期限終了")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.caption.weight(.medium))
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func formatShortTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return "\(h)時間\(m)分"
        } else {
            return "\(m)分"
        }
    }
    
    private func remainingSeconds(from date: Date) -> Int {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: date)
        let endOfToday = cal.date(byAdding: .day, value: 1, to: startOfToday) ?? date
        return max(0, Int(endOfToday.timeIntervalSince(date)))
    }
    
    private func remainingString(from seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    
    private func ensureStartForToday(force: Bool = false) {
        let todayKey = Self.todayKey()
        if force || countdownStartDate != todayKey {
            countdownStartDate = todayKey
        }
    }
    
    private func handleFinished() {
        // 目標達成状況の判定（PhotoManagerから取得）
        let achieved = photoManager.isGoalAchieved
        #if DEBUG
        print("[Countdown] Finished. Achieved: \(achieved) (photosTaken=\(photoManager.todayPhotoCount), goal=\(photoManager.dailyLimit))")
        #endif
        onFinished?()
    }
    
    static func todayKey(date: Date = Date()) -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar.current
        fmt.locale = Locale.current
        fmt.timeZone = TimeZone.current
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
}

#if DEBUG
struct CountdownBanner_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            VStack { CountdownBanner() }.padding()
        }
    }
}
#endif
