import SwiftUI
import Foundation

// MARK: - Supporting Views

struct CalendarArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("カレンダーアーカイブ")
                    .font(.title)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationTitle("アーカイブ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PhotoUnlockCelebration: View {
    let photoCount: Int
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.5))
                
                Text("\(photoCount)枚の写真が解禁されました！")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                
                Button {
                    isPresented = false
                } label: {
                    Text("確認")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.2, green: 0.8, blue: 0.5))
                        )
                }
            }
            .padding()
        }
    }
}

struct LiquidBackgroundView: View {
    @State private var phase1: Double = 0
    @State private var phase2: Double = 0
    @State private var phase3: Double = 0
    
    var body: some View {
        Canvas { context, size in
            let gradient = Gradient(colors: [
                Color(red: 0.1, green: 0.3, blue: 0.4).opacity(0.3),
                Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.2),
                Color(red: 0.1, green: 0.2, blue: 0.3).opacity(0.3)
            ])
            
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = max(size.width, size.height)
            
            context.fill(
                Path(ellipseIn: CGRect(origin: .zero, size: size)),
                with: .radialGradient(
                    gradient,
                    center: center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                phase1 = 360
            }
            withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
                phase2 = 360
            }
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                phase3 = 360
            }
        }
    }
}

struct AnonymousVotingFeedView: View {
    let targetDate: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("投票フィード")
                    .font(.title)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationTitle("投票")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}
