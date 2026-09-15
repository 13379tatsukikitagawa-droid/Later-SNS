import SwiftUI
internal import Combine

// ⚠️ このファイルは古いバージョンのグループ解禁機能です
// 新しいグローバル解禁システム（GlobalSecretRevealManager）を使用してください
// 一時的に無効化されています

#if false

struct GroupMember: Identifiable, Equatable {
    let id: UUID
    let name: String
    var isGoalAchieved: Bool = false
}

class GroupSessionManager: ObservableObject {
    @Published var members: [GroupMember]
    @Published var isCountdownActive: Bool = false
    @Published var isUnlocked: Bool = false
    @Published var remainingSeconds: Int = 0
    @Published var recentMessages: [String] = []
    
    private var countdownDuration: Int = 15
    private var timerCancellable: AnyCancellable?
    
    init(members: [GroupMember]) {
        self.members = members
    }
    
    func startCountdown() {
        guard !isCountdownActive else { return }
        isCountdownActive = true
        isUnlocked = false
        remainingSeconds = countdownDuration
        recentMessages.append("Countdown started")
        runTimer()
    }
    
    private func runTimer() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.remainingSeconds > 0 {
                    self.remainingSeconds -= 1
                }
                if self.remainingSeconds == 0 {
                    self.unlock()
                }
            }
    }
    
    func unlock() {
        isUnlocked = true
        isCountdownActive = false
        timerCancellable?.cancel()
        recentMessages.append("Unlocked!")
    }
    
    func stopCountdown() {
        isCountdownActive = false
        isUnlocked = false
        timerCancellable?.cancel()
        recentMessages.append("Countdown stopped")
    }
    
    func randomCompleteOneMember() {
        guard members.contains(where: { !$0.isGoalAchieved }) else { return }
        var newMembers = members
        let incompleteIndices = newMembers.indices.filter { !newMembers[$0].isGoalAchieved }
        if let randomIndex = incompleteIndices.randomElement() {
            newMembers[randomIndex].isGoalAchieved = true
            members = newMembers
            recentMessages.append("\(newMembers[randomIndex].name) completed their goal.")
            checkAllCompleted()
        }
    }
    
    func resetState() {
        members = members.map { member in
            var m = member
            m.isGoalAchieved = false
            return m
        }
        isUnlocked = false
        isCountdownActive = false
        remainingSeconds = 0
        timerCancellable?.cancel()
        recentMessages.append("State reset")
    }
    
    func fastForward(seconds: Int) {
        guard isCountdownActive && remainingSeconds > 0 else { return }
        remainingSeconds = max(0, remainingSeconds - seconds)
        recentMessages.append("Fast-forwarded \(seconds) seconds")
        if remainingSeconds == 0 {
            unlock()
        }
    }
    
    private func checkAllCompleted() {
        if members.allSatisfy({ $0.isGoalAchieved }) {
            startCountdown()
        }
    }
}

struct GroupUnlockView: View {
    @StateObject var manager: GroupSessionManager
    
    init(members: [GroupMember]) {
        _manager = StateObject(wrappedValue: GroupSessionManager(members: members))
    }
    
    var body: some View {
        ZStack {
            if manager.isCountdownActive {
                LinearGradient(gradient: Gradient(colors: [Color.yellow, Color.init(red: 1, green: 0.9, blue: 0)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                    .brightness(0.15)
                    .animation(.easeInOut(duration: 1), value: manager.isCountdownActive)
            } else {
                Color(white: 0.1)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1), value: manager.isCountdownActive)
            }
            
            VStack(spacing: 30) {
                VStack(spacing: 8) {
                    if !manager.isUnlocked && manager.isCountdownActive {
                        Text("全員が撮り終えました！一斉解禁まで残り...")
                            .font(.title2)
                            .foregroundColor(.white)
                            .bold()
                        Text(timeString(from: manager.remainingSeconds))
                            .font(.system(size: 60, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .shadow(radius: 5)
                    } else if manager.isUnlocked {
                        Text("一斉解禁！")
                            .font(.system(size: 48, weight: .heavy, design: .default))
                            .foregroundColor(.green)
                            .shadow(color: .green.opacity(0.9), radius: 10, x: 0, y: 0)
                            .scaleEffect(1.2)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.spring(), value: manager.isUnlocked)
                    } else {
                        Text("全員の撮影完了を待っています...")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                            .italic()
                    }
                }
                .padding(.top, 40)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Members")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                    ForEach(manager.members) { member in
                        HStack {
                            Text(member.name)
                                .foregroundColor(.white)
                            Spacer()
                            if member.isGoalAchieved {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .transition(.scale)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .frame(maxWidth: 300)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notifications")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                    ForEach(manager.recentMessages.suffix(3), id: \.self) { msg in
                        Text(msg)
                            .foregroundColor(.white.opacity(0.7))
                            .font(.callout)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .animation(.easeInOut, value: manager.recentMessages)
                    }
                }
                .frame(maxWidth: 300)
                .padding()
                .background(Color.white.opacity(0.12))
                .cornerRadius(12)
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button {
                        withAnimation {
                            manager.randomCompleteOneMember()
                        }
                    } label: {
                        Text("Complete One")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(12)
                    }
                    Button {
                        withAnimation {
                            manager.resetState()
                        }
                    } label: {
                        Text("Reset")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(12)
                    }
                    Button {
                        withAnimation {
                            manager.fastForward(seconds: 5)
                        }
                    } label: {
                        Text("Fast-Forward 5s")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.purple.opacity(0.8))
                            .cornerRadius(12)
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal)
        }
    }
    
    private func timeString(from seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct GroupUnlockView_Previews: PreviewProvider {
    static var previews: some View {
        GroupUnlockView(members: [
            GroupMember(id: UUID(), name: "Alice"),
            GroupMember(id: UUID(), name: "Bob"),
            GroupMember(id: UUID(), name: "Charlie"),
            GroupMember(id: UUID(), name: "Diana"),
            GroupMember(id: UUID(), name: "Eve"),
        ])
        .preferredColorScheme(.dark)
    }
}
#endif // false - 古いグループ解禁システムを無効化

