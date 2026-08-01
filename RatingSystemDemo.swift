import SwiftUI
import SwiftUI
import Foundation

// MARK: - Missing Type Definitions (Placeholders)
// TODO: Move these to a shared file or ensure proper imports

// Note: PhotoRating is now imported from PhotoRating.swift
// Note: RatingStats is now imported from PhotoRating.swift


struct RatingStatsCardDemo: View {
    let stats: RatingStats
    let photoURL: String?
    
    var body: some View {
        VStack(spacing: 16) {
            Text("統計")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.white)
            
            HStack(spacing: 20) {
                statItem(label: "エモ度", value: stats.averageEmo, color: .neonPink)
                statItem(label: "構図", value: stats.averageComposition, color: .neonBlue)
                statItem(label: "バイブス", value: stats.averageVibes, color: .neonPurple)
            }
            
            HStack {
                Text("総合平均")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
                Spacer()
                Text(String(format: "%.1f", stats.overallAverage))
                    .font(.title2.weight(.black))
                    .foregroundStyle(Color.neonCyan)
            }
            
            if !stats.customStamps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("人気スタンプ")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.7))
                    
                    // Count stamp occurrences
                    let stampCounts = Dictionary(grouping: stats.customStamps, by: { $0 })
                        .mapValues { $0.count }
                        .sorted { $0.value > $1.value }
                        .prefix(5)
                    
                    HStack(spacing: 12) {
                        ForEach(Array(stampCounts), id: \.key) { stamp, count in
                            HStack(spacing: 4) {
                                Text(stamp)
                                    .font(.title3)
                                Text("\(count)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color.neonGold)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 2)
                )
        )
    }
    
    private func statItem(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1f", value))
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.6))
        }
    }
}

// MARK: - Color Extensions
// Note: Color extensions moved to ColorExtensions.swift to avoid duplicates

/// 評価システムのデモ画面 - 全機能を確認できる
struct RatingSystemDemo: View {
    @State private var showRatingView = false
    @State private var showStampEditor = false
    @State private var sampleRatings: [PhotoRating] = []
    
    private let samplePhotoId = "demo_photo_001"
    private let currentUserId = "current_user"
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // ヘッダー
                        headerSection
                        
                        // サンプル写真カード
                        samplePhotoCard
                        
                        // 統計カード
                        if !sampleRatings.isEmpty {
                            let stats = RatingStats.calculate(from: sampleRatings)
                            RatingStatsCardDemo(stats: stats, photoURL: nil)
                                .padding(.horizontal)
                        } else {
                            noRatingsView
                        }
                        
                        // アクションボタン
                        actionButtons
                        
                        // 評価リスト
                        if !sampleRatings.isEmpty {
                            ratingsListSection
                        }
                    }
                    .padding(.vertical)
                }
            }
            .sheet(isPresented: $showRatingView) {
                PhotoRatingView(
                    photoId: samplePhotoId,
                    raterId: "demo_rater_\(Int.random(in: 1000...9999))",
                    existingRating: Optional<PhotoRating>.none
                ) { rating in
                    addRating(rating)
                }
            }
            .sheet(isPresented: $showStampEditor) {
                CustomStampEditor()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("RATING SYSTEM")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(
                    SwiftUI.LinearGradient(
                        colors: [.neonCyan, .neonPurple, .neonPink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: SwiftUI.Color.neonCyan.opacity(0.5), radius: 15, x: 0, y: 0)
            
            Text("トレカ風評価システムデモ")
                .font(.subheadline)
                .foregroundStyle(SwiftUI.Color.white.opacity(0.7))
            
            // スタンプ編集ボタン
            Button {
                showStampEditor = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "seal.fill")
                        .font(SwiftUI.Font.caption.weight(.bold))
                    Text("マイスタンプを編集")
                        .font(SwiftUI.Font.caption.weight(.semibold))
                }
                .foregroundStyle(Color.neonGold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.neonGold.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(Color.neonGold.opacity(0.5), lineWidth: 1)
                        )
                )
            }
        }
        .padding()
    }
    
    // MARK: - Sample Photo Card
    
    private var samplePhotoCard: some View {
        VStack(spacing: 12) {
            Text("サンプル写真")
                .font(.headline.weight(.bold))
                .foregroundStyle(SwiftUI.Color.white)
            
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    SwiftUI.LinearGradient(
                        colors: [SwiftUI.Color.neonPink.opacity(0.3), SwiftUI.Color.neonPurple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "photo.fill")
                            .font(SwiftUI.Font.system(size: 60))
                            .foregroundStyle(SwiftUI.Color.white.opacity(0.5))
                        
                        Text("この写真を評価")
                            .font(SwiftUI.Font.headline.weight(.bold))
                            .foregroundStyle(SwiftUI.Color.white)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            SwiftUI.LinearGradient(
                                colors: [SwiftUI.Color.neonPink, SwiftUI.Color.neonPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
        }
        .padding(.horizontal)
    }
    
    // MARK: - No Ratings View
    
    private var noRatingsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.slash")
                .font(SwiftUI.Font.system(size: 50))
                .foregroundStyle(SwiftUI.Color.white.opacity(0.3))
            
            Text("まだ評価がありません")
                .font(.headline.weight(.bold))
                .foregroundStyle(SwiftUI.Color.white.opacity(0.7))
            
            Text("下のボタンから評価を追加してみましょう")
                .font(.caption)
                .foregroundStyle(SwiftUI.Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(SwiftUI.Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(SwiftUI.Color.white.opacity(0.1), lineWidth: 2)
                )
        )
        .padding(.horizontal)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 評価を追加
            Button {
                showRatingView = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(SwiftUI.Font.title3.weight(.bold))
                    
                    Text("評価を追加")
                        .font(SwiftUI.Font.system(size: 18, weight: .black, design: .rounded))
                }
                .foregroundStyle(SwiftUI.Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    SwiftUI.LinearGradient(
                        colors: [SwiftUI.Color.neonCyan, SwiftUI.Color.neonPurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: SwiftUI.Color.neonCyan.opacity(0.5), radius: 15, x: 0, y: 8)
            }
            
            // リセット
            if !sampleRatings.isEmpty {
                Button {
                    withAnimation {
                        sampleRatings.removeAll()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(SwiftUI.Font.callout.weight(.bold))
                        
                        Text("リセット")
                            .font(SwiftUI.Font.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(SwiftUI.Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(SwiftUI.Color.white.opacity(0.1))
                    )
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Ratings List Section
    
    private var ratingsListSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("評価一覧")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SwiftUI.Color.white)
                
                Spacer()
                
                Text("\(sampleRatings.count)件")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SwiftUI.Color.white.opacity(0.6))
            }
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(sampleRatings.reversed()) { rating in
                    ratingItemView(rating)
                }
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Rating Item View
    
    private func ratingItemView(_ rating: PhotoRating) -> some View {
        HStack(spacing: 16) {
            // アイコン
            Circle()
                .fill(
                    SwiftUI.LinearGradient(
                        colors: [SwiftUI.Color.neonBlue.opacity(0.5), SwiftUI.Color.neonPurple.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(SwiftUI.Font.title3)
                        .foregroundStyle(SwiftUI.Color.white)
                )
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    scoreChip(icon: "sparkles", score: rating.emoScore, color: .neonPink)
                    scoreChip(icon: "camera.viewfinder", score: rating.compositionScore, color: .neonBlue)
                    scoreChip(icon: "waveform", score: rating.vibesScore, color: .neonPurple)
                }
                
                if let stamp = rating.customStamp {
                    HStack(spacing: 4) {
                        Text(stamp)
                            .font(SwiftUI.Font.caption)
                        Text("スタンプ付き")
                            .font(SwiftUI.Font.caption2)
                            .foregroundStyle(Color.neonGold)
                    }
                }
            }
            
            Spacer()
            
            // 平均スコア
            VStack(spacing: 2) {
                Text(String(format: "%.1f", rating.averageScore))
                    .font(SwiftUI.Font.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.neonCyan)
                    .monospacedDigit()
                
                Text("AVG")
                    .font(SwiftUI.Font.caption2.weight(.bold))
                    .foregroundStyle(SwiftUI.Color.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SwiftUI.Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(SwiftUI.Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
    
    private func scoreChip(icon: String, score: Int, color: SwiftUI.Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(SwiftUI.Font.caption2)
            Text("\(score)")
                .font(SwiftUI.Font.caption.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
    
    // MARK: - Actions
    
    private func addRating(_ rating: PhotoRating) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            sampleRatings.append(rating)
        }
    }
}

#Preview {
    RatingSystemDemo()
}

