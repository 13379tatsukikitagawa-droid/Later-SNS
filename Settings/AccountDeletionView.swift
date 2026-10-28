import SwiftData
import SwiftUI

/// アカウント削除のシート(App Store審査ガイドライン5.1.1(v)対応)。
/// 「押し続けて、削除する」を約1.5秒押し続けると実行。離すと 0 に戻る(止まる)。
/// 触覚:押している間じわっと強く → 離すと止める → 完了で強く1回。
/// VoiceOver では、長押しの代わりに確認のアラート(2段階)で実行できる。
struct AccountDeletionView: View {
    /// 入っているグループの数(実際の数)
    let groupCount: Int
    /// 削除が終わった(設定をとじて、最初の画面へ)
    let onDeleted: () -> Void

    static let holdDuration: TimeInterval = 1.5
    private static let red = Color(hex: "FF6B5E")

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    @AppStorage("appleUserID") private var appleUserID: String = ""
    @AppStorage("appleFullName") private var appleFullName: String = ""
    @AppStorage("firebaseUID") private var firebaseUID: String = ""
    @AppStorage("firebaseEmail") private var firebaseEmail: String = ""
    @AppStorage("currentProfileID") private var currentProfileID: String = ""
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false
    @AppStorage("hasCompletedSurvey") private var hasCompletedSurvey: Bool = false
    @AppStorage("hasSeenAboutLaterIntro") private var hasSeenAboutLaterIntro: Bool = false
    @AppStorage(OnboardingStorage.completedKey) private var onboardingCompleted = false

    @State private var haptics = ExposureHaptics()
    @State private var pressStart: Date?
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var confirmStep = 0
    @State private var sheetHeight: CGFloat = 480

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("アカウントを、削除します")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Text("削除すると、もとにもどせません。")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "BCBBC0"))
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                bullet("あなたの写真・名前・タグが、すべて消えます。Mondo にならんだ写真も消えます")
                bullet("入っているグループ(\(groupCount)つ)から、抜けます")
                bullet("同じ Apple ID でも、引きつげません")
            }
            .padding(.top, 20)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Self.red)
                    .padding(.top, 14)
            }

            holdButton
                .padding(.top, 24)

            Button("やめる") { dismiss() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Capsule().fill(.white.opacity(0.08)).overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1)))
                .buttonStyle(.plain)
                .padding(.top, 10)
                .disabled(isDeleting)
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 20)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeight = $0 }
        .presentationDetents([.height(sheetHeight)])
        .presentationCornerRadius(34)
        .presentationBackground(.ultraThinMaterial)
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(isDeleting)
        .onAppear { haptics.prepare() }
        .onDisappear { haptics.cancelHold() }
        .alert("アカウントを削除しますか?", isPresented: Binding(get: { confirmStep == 1 }, set: { if !$0 && confirmStep == 1 { confirmStep = 0 } })) {
            Button("つぎへ", role: .destructive) { DispatchQueue.main.async { confirmStep = 2 } }
            Button("やめる", role: .cancel) { confirmStep = 0 }
        } message: {
            Text("削除すると、もとにもどせません。")
        }
        .alert("本当に、削除しますか?", isPresented: Binding(get: { confirmStep == 2 }, set: { if !$0 && confirmStep == 2 { confirmStep = 0 } })) {
            Button("削除する", role: .destructive) {
                confirmStep = 0
                Task { await performDeletion() }
            }
            Button("やめる", role: .cancel) { confirmStep = 0 }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().fill(.white.opacity(0.5)).frame(width: 4, height: 4).offset(y: -3)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    /// 押している間、左から赤が満ちる(一定の速さ)。離すと 0 に戻る
    private var holdButton: some View {
        TimelineView(.animation(paused: pressStart == nil)) { context in
            let progress = pressStart.map { min(1, context.date.timeIntervalSince($0) / Self.holdDuration) } ?? 0
            ZStack(alignment: .leading) {
                Capsule().fill(Self.red.opacity(0.12))
                GeometryReader { proxy in
                    Rectangle()
                        .fill(Self.red.opacity(0.45))
                        .frame(width: proxy.size.width * progress)
                }
                .clipShape(Capsule())
                Capsule().strokeBorder(Self.red, lineWidth: 1.5)
                Group {
                    if isDeleting {
                        ProgressView().tint(Self.red)
                    } else {
                        Text("押し続けて、削除する")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Self.red)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 56)
            .onChange(of: progress >= 1) { _, done in
                if done { complete() }
            }
        }
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard pressStart == nil, !isDeleting, !voiceOverEnabled else { return }
                    pressStart = Date()
                    haptics.beginHold(duration: Self.holdDuration)
                }
                .onEnded { _ in release() }
        )
        .accessibilityElement()
        .accessibilityLabel("アカウントを削除する")
        .accessibilityHint("確認のあとで削除します")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { confirmStep = 1 }
    }

    private func release() {
        guard !isDeleting else { return }
        pressStart = nil
        haptics.cancelHold()
    }

    private func complete() {
        guard !isDeleting else { return }
        haptics.cancelHold()
        haptics.fireCapture()
        Task { await performDeletion() }
    }

    private func performDeletion() async {
        isDeleting = true
        errorMessage = nil
        do {
            try await AccountDeletionService.deleteAccount(modelContext: modelContext)
            // サインアウトして、最初の画面へ
            appleUserID = ""
            appleFullName = ""
            firebaseUID = ""
            firebaseEmail = ""
            currentProfileID = ""
            hasCompletedSurvey = false
            hasSeenAboutLaterIntro = false
            onboardingCompleted = false
            UserDefaults.standard.removeObject(forKey: OnboardingStorage.stepKey)
            isSetupCompleted = false
            dismiss()
            onDeleted()
        } catch {
            isDeleting = false
            pressStart = nil
            errorMessage = "削除できませんでした。通信を確かめて、もう一度お試しください。"
            print("[AccountDeletion] failed: \(error)")
        }
    }
}
