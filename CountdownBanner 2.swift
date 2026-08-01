import SwiftUI

/// カウントダウンバナー（24時間タイマー）
struct CountdownBannerV2: View {
    @AppStorage("countdownStartDate") private var countdownStartDateString: String = ""
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?
    
    var onTimeout: () -> Void
    
    private var hours: Int {
        Int(timeRemaining) / 3600
    }
    
    private var minutes: Int {
        (Int(timeRemaining) % 3600) / 60
    }
    
    private var seconds: Int {
        Int(timeRemaining) % 60
    }
    
    private var progress: Double {
        let total: TimeInterval = 24 * 3600
        return max(0, min(1, 1 - (timeRemaining / total)))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "timer")
                    .font(.headline)
                    .foregroundStyle(Color.brandGreen)
                
                Text("解禁まで")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                Text(String(format: "%02d:%02d:%02d", hours, minutes, seconds))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            
            ProgressView(value: progress)
                .tint(Color.brandGreen)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startCountdown() {
        // 保存されている開始時刻を取得
        let formatter = ISO8601DateFormatter()
        
        if countdownStartDateString.isEmpty {
            // 初回起動: 現在時刻を開始時刻として保存
            let now = Date()
            countdownStartDateString = formatter.string(from: now)
        }
        
        guard let startDate = formatter.date(from: countdownStartDateString) else {
            return
        }
        
        // 終了時刻（24時間後）
        let endDate = startDate.addingTimeInterval(24 * 3600)
        
        // 残り時間を計算
        updateTimeRemaining(endDate: endDate)
        
        // タイマーを開始
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateTimeRemaining(endDate: endDate)
        }
    }
    
    private func updateTimeRemaining(endDate: Date) {
        let now = Date()
        timeRemaining = max(0, endDate.timeIntervalSince(now))
        
        if timeRemaining <= 0 {
            timer?.invalidate()
            onTimeout()
        }
    }
    
    static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

#Preview {
    ZStack {
        Color.brandBlack.ignoresSafeArea()
        CountdownBannerV2 {
            print("Countdown finished!")
        }
        .padding()
    }
}
