import SwiftUI

enum AppTab: Hashable { case connections, camera, profile }

struct FloatingTabContainer: View {
    // Progress sources
    @AppStorage("photosTaken") private var photosTaken: Int = 0
    @AppStorage("dailyGoal") private var dailyGoal: Int = 3
    @AppStorage("isDailyGoalLocked") private var isDailyGoalLocked: Bool = false

    @State private var selected: AppTab = .connections
    @State private var showCameraSheet: Bool = false
    @State private var showShimmer: Bool = false

    private var progress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(photosTaken) / Double(dailyGoal))
    }

    var body: some View {
        ZStack {
            // Content switching
            Group {
                switch selected {
                case .connections:
                    NavigationStack { QRCodeDemoView() }
                case .camera:
                    NavigationStack { CameraPlaceholderView() }
                case .profile:
                    NavigationStack { ProfileView() }
                }
            }
            .ignoresSafeArea()

            // Floating Tab Bar
            VStack { Spacer(); floatingBar }
                .padding(.bottom, 16)
                .padding(.horizontal, 16)
        }
        .onChange(of: photosTaken) { old, new in
            handleProgressChange(old: old, new: new)
        }
        .onChange(of: dailyGoal) { _, _ in
            // reset shimmer when goal changes
            if !isGoalAchieved { showShimmer = false }
        }
        .sheet(isPresented: $showCameraSheet) {
            // Replace with real camera view when available
            CameraPlaceholderView()
        }
    }

    private var isGoalAchieved: Bool { photosTaken >= dailyGoal && dailyGoal > 0 }

    private var floatingBar: some View {
        HStack(spacing: 24) {
            // Left: Connections
            tabButton(system: "person.2.fill", title: "Connections", isSelected: selected == .connections) {
                selected = .connections
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            
            // Center: Camera Progress Button
            cameraButton
                .padding(.horizontal, 4)
            
            // Right: Profile
            tabButton(system: "person.crop.circle", title: "Profile", isSelected: selected == .profile) {
                selected = .profile
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
    }

    private func tabButton(system: String, title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: system)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
            }
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }

    private var cameraButton: some View {
        let locked = isGoalAchieved || isDailyGoalLocked
        return Button {
            if locked {
                // error haptic
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            } else {
                // success/light haptic and open camera
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                selected = .camera
                showCameraSheet = true
            }
        } label: {
            ZStack {
                Circle()
                    .fill(locked ? LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [.brandGreen, .brandGreen.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 70, height: 70)
                    .shadow(color: locked ? .clear : Color.brandGreen.opacity(0.5), radius: 12, x: 0, y: 6)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                Image(systemName: locked ? "lock.fill" : "camera.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, isActive: locked)
                // Progress ring
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(locked ? Color.white.opacity(0.4) : Color.brandGreen, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                    .opacity(0.9)
                    .overlay(alignment: .top) {
                        if showShimmer {
                            shimmerArc
                        }
                    }
            }
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityLabel(locked ? "Locked" : "Camera")
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: locked)
        .animation(.easeInOut(duration: 0.4), value: progress)
    }

    // Shimmer/shine when goal achieved
    private var shimmerArc: some View {
        Circle()
            .trim(from: 0.0, to: 0.05)
            .stroke(LinearGradient(colors: [.white, .yellow, .white], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .frame(width: 96, height: 96)
            .rotationEffect(.degrees(showShimmer ? 360 : 0))
            .opacity(0.9)
            .animation(.linear(duration: 1.0).repeatCount(2, autoreverses: false), value: showShimmer)
    }

    private func handleProgressChange(old: Int, new: Int) {
        if isGoalAchieved && old < new {
            // One-shot shine + success haptic then lock
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showShimmer = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showShimmer = false
            }
        }
    }
}

// Placeholder camera view (replace with real camera when available)
struct CameraPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "camera.fill").font(.system(size: 60)).foregroundStyle(.white.opacity(0.9))
                Text("Camera Placeholder").foregroundStyle(.white.opacity(0.7))
                Text("Launch your real camera here").font(.caption).foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

#Preview("Floating Tabs") {
    FloatingTabContainer()
}
