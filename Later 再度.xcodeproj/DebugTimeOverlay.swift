import SwiftUI

/// 🐛 デバッグ用の時間操作オーバーレイ
/// 
/// 開発中にフェーズを自由に切り替えるためのUI。
/// 本番環境では非表示にすることを推奨。
struct DebugTimeOverlay: View {
    @ObservedObject var engine: TimeWindowEngine
    
    @State private var isExpanded = false
    @State private var selectedPhase: TimeWindowPhase = .shooting
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 12) {
                    // 展開時のコントロールパネル
                    if isExpanded {
                        controlPanel
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    
                    // トグルボタン
                    toggleButton
                }
                .padding(.trailing, 16)
                .padding(.bottom, 100) // タブバーと重ならないように調整
            }
        }
        .allowsHitTesting(true)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
    }
    
    // MARK: - Subviews
    
    /// コントロールパネル
    private var controlPanel: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // デバッグモード切り替え
            debugModeToggle
            
            if engine.isDebugModeEnabled {
                // フェーズ選択
                phaseSelector
                
                // クイックジャンプボタン
                quickJumpButtons
                
                // 現在のステータス表示
                statusDisplay
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.black.opacity(0.85))
                .shadow(color: .green.opacity(0.3), radius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#00ff41"), lineWidth: 1)
        )
        .frame(maxWidth: 300)
    }
    
    /// デバッグモード切り替えトグル
    private var debugModeToggle: some View {
        HStack {
            Image(systemName: engine.isDebugModeEnabled ? "ladybug.fill" : "ladybug")
                .foregroundStyle(engine.isDebugModeEnabled ? Color(hex: "#00ff41") : .white)
            
            Text("デバッグモード")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white)
            
            Spacer()
            
            Toggle("", isOn: $engine.isDebugModeEnabled)
                .labelsHidden()
                .tint(Color(hex: "#00ff41"))
        }
    }
    
    /// フェーズ選択ピッカー
    private var phaseSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("フェーズを選択")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            
            ForEach(TimeWindowPhase.allCases) { phase in
                Button {
                    selectedPhase = phase
                    engine.forcePhase(phase)
                    lightHaptic()
                } label: {
                    HStack {
                        Image(systemName: phase.icon)
                            .frame(width: 20)
                        
                        Text(phase.rawValue)
                            .font(.system(.caption, design: .monospaced))
                        
                        Spacer()
                        
                        if engine.currentPhase == phase {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(hex: phase.color))
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(engine.currentPhase == phase ? Color(hex: phase.color).opacity(0.2) : Color.white.opacity(0.05))
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    /// クイックジャンプボタン
    private var quickJumpButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("クイックジャンプ")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            
            HStack(spacing: 8) {
                // 0:00にジャンプ
                quickJumpButton(hour: 0, label: "0:00")
                
                // 8:00にジャンプ
                quickJumpButton(hour: 8, label: "8:00")
                
                // 9:00にジャンプ
                quickJumpButton(hour: 9, label: "9:00")
                
                // 23:59にジャンプ
                quickJumpButton(hour: 23, minute: 59, label: "23:59")
            }
        }
    }
    
    /// クイックジャンプボタン（個別）
    private func quickJumpButton(hour: Int, minute: Int = 0, label: String) -> some View {
        Button {
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.year, .month, .day], from: now)
            
            guard let today = calendar.date(from: components),
                  let targetDate = calendar.date(byAdding: .hour, value: hour, to: today),
                  let finalDate = calendar.date(byAdding: .minute, value: minute, to: targetDate) else {
                return
            }
            
            engine.jumpToDate(finalDate)
            mediumHaptic()
        } label: {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
    
    /// ステータス表示
    private var statusDisplay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
                .background(Color.white.opacity(0.3))
            
            HStack {
                Text("現在のフェーズ:")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                Text(engine.currentPhase.rawValue)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color(hex: engine.currentPhase.color))
            }
            
            HStack {
                Text("次のフェーズまで:")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                Text(engine.currentPhase.formattedTimeUntilNextPhase(from: engine.effectiveCurrentDate))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white)
            }
            
            if engine.isDebugModeEnabled, let mockDate = engine.mockCurrentDate {
                HStack {
                    Text("モック時刻:")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text(mockDate.formatted(date: .omitted, time: .shortened))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00ff41"))
                }
            }
        }
    }
    
    /// トグルボタン（展開/折りたたみ）
    private var toggleButton: some View {
        Button {
            withAnimation {
                isExpanded.toggle()
            }
            lightHaptic()
        } label: {
            Image(systemName: isExpanded ? "xmark.circle.fill" : "clock.fill")
                .font(.system(size: 24))
                .foregroundStyle(
                    isExpanded ? .white : Color(hex: "#00ff41")
                )
                .padding(12)
                .background(
                    Circle()
                        .fill(isExpanded ? Color(hex: "#00ff41") : .black.opacity(0.85))
                        .shadow(color: Color(hex: "#00ff41").opacity(0.3), radius: 8)
                )
                .overlay(
                    Circle()
                        .stroke(Color(hex: "#00ff41"), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Haptics
    
    private func lightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func mediumHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Preview

#Preview("デバッグオーバーレイ") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Text("メイン画面")
                .foregroundStyle(.white)
        }
        
        DebugTimeOverlay(engine: TimeWindowEngine.shared)
    }
}
