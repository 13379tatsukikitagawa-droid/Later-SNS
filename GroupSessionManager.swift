import Foundation
import Foundation
internal import Combine

// MARK: - Group Member Model
/// グループメンバーの情報を保持する構造体

struct GroupMember: Identifiable, Hashable {
    let id: UUID
    let name: String
    var isGoalAchieved: Bool
    
    init(id: UUID = UUID(), name: String, isGoalAchieved: Bool = false) {
        self.id = id
        self.name = name
        self.isGoalAchieved = isGoalAchieved
    }
}

// MARK: - Group Session Manager
/// グループセッションの管理と同期を行うマネージャー

final class GroupSessionManager: ObservableObject {
    @Published private(set) var members: [GroupMember]
    @Published private(set) var isCountdownActive: Bool = false
    @Published private(set) var countdownRemaining: TimeInterval = 0
    @Published private(set) var isUnlocked: Bool = false
    @Published private(set) var notifications: [String] = []
    
    let countdownTotal: TimeInterval = 5 * 60
    private var timerCancellable: AnyCancellable?
    
    init(members: [GroupMember]) {
        self.members = Array(members.prefix(5))
    }
    
    func updateMemberAchievement(id: UUID, achieved: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let index = self.members.firstIndex(where: { $0.id == id }) else { return }
            self.members[index].isGoalAchieved = achieved
            
            let remaining = self.members.filter { !$0.isGoalAchieved }.count
            let memberName = self.members[index].name
            if achieved {
                if remaining > 0 {
                    self.appendNotification("\(memberName)さんが撮影完了！残るはあと\(remaining)人...")
                } else {
                    self.appendNotification("全員現像準備完了！これより一斉解禁します")
                }
            } else {
                // No notification required if un-achieved
            }
            
            self.checkAndStartCountdownIfNeeded()
        }
    }
    
    private func appendNotification(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.notifications.append(message)
        }
    }
    
    private func checkAndStartCountdownIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let allAchieved = self.members.allSatisfy { $0.isGoalAchieved }
            if allAchieved && !self.isCountdownActive && !self.isUnlocked {
                self.startCountdown()
            }
        }
    }
    
    private func startCountdown() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isCountdownActive = true
            self.countdownRemaining = self.countdownTotal
            
            self.timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.handleTick()
                }
        }
    }
    
    private func stopCountdown() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timerCancellable?.cancel()
            self.timerCancellable = nil
            self.isCountdownActive = false
        }
    }
    
    private func handleTick() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.countdownRemaining -= 1
            if self.countdownRemaining <= 0 {
                self.stopCountdown()
                self.isUnlocked = true
                self.appendNotification("一斉解禁完了！おめでとうございます！")
            }
        }
    }
}
