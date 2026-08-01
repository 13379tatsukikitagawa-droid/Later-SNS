import SwiftUI

// DISABLED: This file contains duplicate type declarations
// The main implementation is in MinimalSplashView.swift
// To re-enable, rename the types below (e.g., MinimalSplashView_Alt)

/// ミニマルなスプラッシュ画面
struct MinimalSplashView_Disabled: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // アプリアイコン風の円
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.brandGreen,
                                Color.brandGreen.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 50, weight: .light))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color.brandGreen.opacity(0.5), radius: 30, y: 15)
                    .scaleEffect(scale)
                    .opacity(opacity)
                
                // アプリ名
                Text("Later")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(opacity)
                
                // サブタイトル
                Text("思い出は、あとで。")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

#Preview {
    MinimalSplashView_Disabled()
}
