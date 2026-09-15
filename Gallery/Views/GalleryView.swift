import SwiftUI
import SwiftData
import Foundation
import UIKit

// MARK: - 📸 ギャラリー：完全リライト版（写真が主役のUI）
struct GalleryView: View {
    @Query(sort: \LaterPhoto.captureDate, order: .reverse) 
    private var allPhotos: [LaterPhoto]
    
    @Environment(\.modelContext) private var context
    
    @Query 
    private var profiles: [UserProfile]
    
    // 🎯 日付選択状態（スナップ式ダイヤルと連動）
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    
    // 🎯 写真ページング（同じ日に複数枚ある場合）
    @State private var currentPhotoIndex: Int = 0
    
    // 🎨 ネオングリーン (#00ff41)
    private let neonGreen = Color.neonGreen
    
    // 現在のユーザー
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    // 選択中の日付の写真（全件、オリジナル順序）
    private var selectedDayPhotos: [LaterPhoto] {
        guard let user = currentUser else { return [] }
        let calendar = Calendar.current
        
        return allPhotos.filter { photo in
            guard photo.owner?.id == user.id else { return false }
            return calendar.isDate(photo.captureDate, inSameDayAs: selectedDate)
        }
    }
    
    var body: some View {
        ZStack {
            // 1. 背景：完全な黒で統一
            Color.black
                .ignoresSafeArea()
            
            // 2. メインレイアウト
            VStack(spacing: 0) {
                // 3. 写真表示エリア（画面の大部分を占める）
                photoDisplayArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Spacer()
                    .frame(height: 20) // 写真エリアとダイヤルの間の距離を調整
                
                // 4. ボタン式日付選択（最下部に配置）
                VStack(spacing: 0) {
                    // 🔴 デバッグ用：変更確認マーカー
                    Text("ボタン式UI v2.0")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 4)
                    
                    DateButtonGridView(
                        dates: dateRange,
                        selectedDate: $selectedDate,
                        photoAvailability: photoAvailabilityMap,
                        neonGreen: neonGreen,
                        onDateChanged: {
                            currentPhotoIndex = 0
                            lightHaptic()
                        }
                    )
                    .frame(height: 140)
                    .background(
                        // 下部グラデーション背景
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0),
                                Color.black.opacity(0.8),
                                Color.black
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // 下部に追加のスペースを確保
                    Spacer()
                        .frame(height: 40)
                }
            }
        }
        .navigationBarHidden(true) // ナビゲーションバー完全非表示
        .toolbar(.hidden, for: .navigationBar) // iOS 16+
        .statusBarHidden(false) // ステータスバーは表示
        .onAppear {
            Task { await unlockPhotosIfNeeded() }
        }
    }
    
    // MARK: - Haptic Helper
    
    private func lightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    // MARK: - 写真表示エリア（オリジナル画角を完全に保持）
    
    @ViewBuilder
    private var photoDisplayArea: some View {
        let photos = selectedDayPhotos
        
        if photos.isEmpty {
            // 📭 写真がない場合のプレースホルダー
            emptyStateView
        } else {
            // 📸 写真がある場合
            let photo = photos[safe: currentPhotoIndex] ?? photos[0]
            
            GeometryReader { geometry in
                ZStack {
                    CachedPhotoImage(imageData: photo.imageData, cacheKey: photo.imageCacheKey) { uiImage in
                        // 🎨 視覚的成熟エンジン適用
                        let isOwnPhoto = photo.owner?.id == currentUser?.id
                        let maturation = calculateMaturationProgress(for: photo)

                        if photo.isUnlocked {
                            // ✅ 完全に解禁された写真
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        } else if isOwnPhoto {
                            // 🎞️ 自分の写真：現像中エフェクト
                            developingPhotoView(image: uiImage, maturation: maturation, geometry: geometry)
                        } else {
                            // 🔒 他人の写真：完全非表示
                            lockedPhotoView
                        }
                        
                        // キャプション（下部にオーバーレイ）
                        if photo.isUnlocked, let caption = photo.caption, !caption.isEmpty {
                            VStack {
                                Spacer()
                                captionOverlay(caption: caption)
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 140)
                            }
                        }
                        
                        // 複数枚ある場合はページングインジケーター
                        if photos.count > 1 {
                            VStack {
                                pagingIndicator(currentIndex: currentPhotoIndex, totalCount: photos.count)
                                    .padding(.top, 50)
                                Spacer()
                            }
                        }
                    } placeholder: {
                        // 🔒 データがない、またはまだデコード中の場合
                        lockedPhotoView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPhotoIndex)
                .gesture(
                    // 左右スワイプでページング（同じ日の写真が複数ある場合）
                    DragGesture(minimumDistance: 50)
                        .onEnded { value in
                            guard photos.count > 1 else { return }
                            
                            if value.translation.width < -50 {
                                // 左スワイプ：次の写真
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    currentPhotoIndex = min(currentPhotoIndex + 1, photos.count - 1)
                                }
                                mediumHaptic()
                            } else if value.translation.width > 50 {
                                // 右スワイプ：前の写真
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    currentPhotoIndex = max(currentPhotoIndex - 1, 0)
                                }
                                mediumHaptic()
                            }
                        }
                )
            }
        }
    }
    
    private func mediumHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // MARK: - 🎞️ Visual Maturation Engine
    
    /// 写真の成熟進捗を計算（0.0 = 撮影直後、1.0 = 完全解禁）
    private func calculateMaturationProgress(for photo: LaterPhoto) -> Double {
        let now = Date()
        let captureTime = photo.captureDate
        let unlockTime = photo.unlockDate
        
        // 既に解禁されている場合は1.0
        if now >= unlockTime {
            return 1.0
        }
        
        // まだ撮影前の場合は0.0（通常起こらない）
        if now < captureTime {
            return 0.0
        }
        
        // 進捗計算: (現在 - 撮影) / (解禁 - 撮影)
        let elapsed = now.timeIntervalSince(captureTime)
        let total = unlockTime.timeIntervalSince(captureTime)
        
        guard total > 0 else { return 0.0 }
        
        let progress = elapsed / total
        return min(max(progress, 0.0), 1.0) // 0.0〜1.0にクランプ
    }
    
    /// 現像中の写真ビュー（視覚的成熟エフェクト付き）
    @ViewBuilder
    private func developingPhotoView(image: UIImage, maturation: Double, geometry: GeometryProxy) -> some View {
        ZStack {
            // 📸 写真本体（エフェクト適用）
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                // 🎨 視覚効果の段階的適用
                .saturation(maturation) // 彩度: 0% → 100%
                .blur(radius: (1.0 - maturation) * 20) // ぼかし: 20px → 0px
                .opacity(0.6 + (maturation * 0.4)) // 不透明度: 0.6 → 1.0
                .brightness((1.0 - maturation) * -0.1) // 暗さ: 若干暗め → 通常
            
            // 🏷️ 「現像中」バッジ（右上）
            VStack {
                HStack {
                    Spacer()
                    DevelopingBadge(progress: maturation)
                        .padding(.trailing, 20)
                        .padding(.top, 50)
                }
                Spacer()
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // MARK: - UI コンポーネント
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 70))
                .foregroundStyle(.white.opacity(0.2))
            
            Text("この日の写真はありません")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
    
    private var lockedPhotoView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                neonGreen.opacity(0.1),
                                neonGreen.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(neonGreen.opacity(0.6))
            }
            
            Text("現像中...")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            
            Text("解禁をお楽しみに")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
    
    private func captionOverlay(caption: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "quote.opening")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(neonGreen.opacity(0.7))
            
            Text(caption)
                .font(.system(size: 16, design: .serif))
                .italic()
                .foregroundStyle(.white)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(neonGreen.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
    }
    
    private func pagingIndicator(currentIndex: Int, totalCount: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<totalCount, id: \.self) { index in
                let isSelected = index == currentIndex
                let fillColor = isSelected ? neonGreen : .white.opacity(0.3)
                let size: CGFloat = isSelected ? 8 : 6
                let shadowColor = isSelected ? neonGreen : .clear
                
                Circle()
                    .fill(fillColor)
                    .frame(width: size, height: size)
                    .shadow(color: shadowColor, radius: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial.opacity(0.3))
        )
    }
    
    // MARK: - データ処理
    
    /// 日付範囲（過去30日分）
    private var dateRange: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<30).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }
    
    /// 各日付に写真があるかどうかのマップ
    private var photoAvailabilityMap: [Date: Bool] {
        let calendar = Calendar.current
        var map: [Date: Bool] = [:]
        
        guard let user = currentUser else { return [:] }
        
        for date in dateRange {
            let hasPhotos = allPhotos.contains { (photo: LaterPhoto) in
                photo.owner?.id == user.id &&
                calendar.isDate(photo.captureDate, inSameDayAs: date)
            }
            map[date] = hasPhotos
        }
        
        return map
    }
    
    /// 写真のアンロック処理（非同期）
    private func unlockPhotosIfNeeded() async {
        let now = Date()
        
        await MainActor.run {
            for photo in allPhotos where photo.unlockDate <= now && !photo.isUnlocked {
                photo.isUnlocked = true
            }
            
            try? context.save()
        }
    }
}

// MARK: - 🎯 スナップ式ダイヤル（1日ずつカチッと止まる水平ホイール）

struct SnapDialView: View {
    let dates: [Date]
    @Binding var selectedDate: Date
    let photoAvailability: [Date: Bool]
    let neonGreen: Color
    var onDateChanged: () -> Void
    
    @State private var scrollPosition: Date?
    
    private let itemWidth: CGFloat = 70
    private let spacing: CGFloat = 12
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(dates, id: \.self) { date in
                        DateDialItem(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            hasPhotos: photoAvailability[date] ?? false,
                            neonGreen: neonGreen
                        )
                        .frame(width: itemWidth)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                selectedDate = date
                                scrollPosition = date
                            }
                            onDateChanged()
                        }
                    }
                }
                .padding(.horizontal, (screenWidth - itemWidth) / 2)
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrollPosition)
            .scrollTargetBehavior(.viewAligned) // 🎯 1アイテムずつスナップ（iOS 17+）
            .onChange(of: scrollPosition) { oldValue, newValue in
                // スクロールで止まった位置の日付を自動選択
                if let newDate = newValue, !Calendar.current.isDate(newDate, inSameDayAs: selectedDate) {
                    selectedDate = newDate
                    onDateChanged()
                }
            }
            .onAppear {
                // 初期位置にスクロール
                scrollPosition = selectedDate
            }
        }
    }
}

// MARK: - 🎯 ボタン式日付選択グリッド（タップ操作に特化）

struct DateButtonGridView: View {
    let dates: [Date]
    @Binding var selectedDate: Date
    let photoAvailability: [Date: Bool]
    let neonGreen: Color
    var onDateChanged: () -> Void
    
    @State private var scrollPosition: Date?
    
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(dates, id: \.self) { date in
                        DateButton(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            hasPhotos: photoAvailability[date] ?? false,
                            neonGreen: neonGreen
                        )
                        .id(date)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedDate = date
                            }
                            onDateChanged()
                            
                            // ハプティックフィードバック
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            
                            // 選択された日付にスクロール
                            withAnimation {
                                proxy.scrollTo(date, anchor: .center)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onAppear {
                // 初期位置にスクロール
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo(selectedDate, anchor: .center)
                }
            }
        }
    }
}

// MARK: - 日付ボタンコンポーネント

struct DateButton: View {
    let date: Date
    let isSelected: Bool
    let hasPhotos: Bool
    let neonGreen: Color
    
    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M"
        return formatter.string(from: date)
    }
    
    private var weekdayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // 月/日
            HStack(spacing: 2) {
                Text("\(monthString)")
                    .font(.system(size: isSelected ? 11 : 10, weight: .semibold, design: .rounded))
                Text("/")
                    .font(.system(size: isSelected ? 10 : 9, weight: .regular, design: .rounded))
                Text(dayString)
                    .font(.system(size: isSelected ? 16 : 14, weight: .black, design: .rounded))
            }
            .foregroundStyle(isSelected ? neonGreen : .white.opacity(0.7))
            
            // 曜日
            Text(weekdayString)
                .font(.system(size: isSelected ? 9 : 8, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? neonGreen.opacity(0.8) : .white.opacity(0.4))
            
            // 写真有無インジケーター
            Circle()
                .fill(hasPhotos ? neonGreen : .gray.opacity(0.2))
                .frame(width: 4, height: 4)
                .shadow(color: hasPhotos && isSelected ? neonGreen : .clear, radius: 4)
        }
        .frame(width: 52, height: 56)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isSelected
                        ? neonGreen.opacity(0.15)
                        : Color.white.opacity(0.05)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isSelected ? neonGreen : Color.white.opacity(0.1),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
        )
        .shadow(
            color: isSelected ? neonGreen.opacity(0.3) : .clear,
            radius: isSelected ? 8 : 0,
            x: 0,
            y: 0
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - 日付ダイヤルアイテム（強調表示とネオングリーンの発光）

struct DateDialItem: View {
    let date: Date
    let isSelected: Bool
    let hasPhotos: Bool
    let neonGreen: Color
    
    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var weekdayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // 日付（選択時は大きく＆ネオングリーン）
            Text(dayString)
                .font(.system(size: isSelected ? 36 : 22, weight: isSelected ? .black : .bold, design: .rounded))
                .foregroundStyle(isSelected ? neonGreen : .white.opacity(0.4))
                .shadow(color: isSelected ? neonGreen : .clear, radius: 16, x: 0, y: 0) // ✨ 発光エフェクト
            
            // 曜日
            Text(weekdayString)
                .font(.system(size: isSelected ? 11 : 9, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? neonGreen.opacity(0.8) : .white.opacity(0.3))
            
            // 写真有無インジケーター
            Circle()
                .fill(hasPhotos ? neonGreen : .gray.opacity(0.15))
                .frame(width: isSelected ? 7 : 5, height: isSelected ? 7 : 5)
                .shadow(color: (hasPhotos && isSelected) ? neonGreen : .clear, radius: 10)
        }
        .frame(width: 70, height: 80)
        .scaleEffect(isSelected ? 1.05 : 0.95)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - 🎯 画像キャッシュマネージャー（ImageCacheManager.swiftで定義済み）

// Note: ImageCacheManager is defined in ImageCacheManager.swift
// The following components are available but currently unused in this view.
// Uncomment if needed and ensure ImageCacheManager.swift is included in the build target.

/*
// MARK: - 🎯 最適化された写真カード（軽量版）

struct OptimizedPhotoCard: View {
    let photo: LaterPhoto
    let themeColor: Color
    let imageCache: ImageCacheManager
    var isGroupBestShot: Bool = false
    let onTap: () -> Void
    
    @Query private var profiles: [UserProfile]
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // 写真
                CachedPhotoImage(imageData: photo.imageData, cacheKey: photo.imageCacheKey) { uiImage in
                    let isOwnPhoto = photo.owner?.id == currentUser?.id
                    let maturation = calculateMaturationProgress(for: photo)

                    if photo.isUnlocked {
                        // ✅ 完全に解禁された写真
                        unlockedPhotoView(image: uiImage)
                    } else if isOwnPhoto {
                        // 🎞️ 自分の写真：現像中エフェクト
                        developingPhotoCard(image: uiImage, maturation: maturation)
                    } else {
                        // 🔒 他人の写真：完全非表示
                        lockedPhotoPlaceholder
                    }
                } placeholder: {
                    // 現像中（データなし、またはまだデコード中）
                    lockedPhotoPlaceholder
                }
                
                // キャプション（あれば）
                if photo.isUnlocked, let caption = photo.caption, !caption.isEmpty {
                    captionView(caption: caption)
                        .padding(.top, 12)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 解禁済み写真ビュー
    
    @ViewBuilder
    private func unlockedPhotoView(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(3/4, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: 450)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isGroupBestShot ?
                            LinearGradient(
                                colors: [Color.yellow, Color.orange, Color.yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [themeColor.opacity(0.3), themeColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: isGroupBestShot ? 3 : 1.5
                    )
            )
            .shadow(
                color: isGroupBestShot ? Color.yellow.opacity(0.3) : .black.opacity(0.3),
                radius: isGroupBestShot ? 20 : 12,
                x: 0,
                y: 8
            )
            .overlay(alignment: .topTrailing) {
                if isGroupBestShot {
                    MVPBadge(voteCount: photo.voteCount, themeColor: themeColor)
                        .padding(12)
                }
            }
    }
    
    // MARK: - 現像中写真ビュー
    
    @ViewBuilder
    private func developingPhotoCard(image: UIImage, maturation: Double) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(3/4, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 450)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                // 🎨 視覚効果
                .saturation(maturation)
                .blur(radius: (1.0 - maturation) * 20)
                .opacity(0.6 + (maturation * 0.4))
                .brightness((1.0 - maturation) * -0.1)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(themeColor.opacity(0.3), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 8)
            
            // 現像中バッジ
            VStack {
                HStack {
                    Spacer()
                    DevelopingBadge(progress: maturation)
                        .padding(12)
                }
                Spacer()
            }
        }
    }
    
    // MARK: - 成熟進捗計算
    
    private func calculateMaturationProgress(for photo: LaterPhoto) -> Double {
        let now = Date()
        let captureTime = photo.captureDate
        let unlockTime = photo.unlockDate
        
        if now >= unlockTime { return 1.0 }
        if now < captureTime { return 0.0 }
        
        let elapsed = now.timeIntervalSince(captureTime)
        let total = unlockTime.timeIntervalSince(captureTime)
        
        guard total > 0 else { return 0.0 }
        
        let progress = elapsed / total
        return min(max(progress, 0.0), 1.0)
    }
    
    // MARK: - ロック中プレースホルダー
    
    private var lockedPhotoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .frame(height: 450)
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(themeColor.opacity(0.5))
                    
                    Text("現像中...")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundStyle(.white.opacity(0.6))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(themeColor.opacity(0.2), lineWidth: 1)
            )
    }
    
    private func captionView(caption: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(themeColor.opacity(0.6))
            
            Text(caption)
                .font(.system(size: 14, design: .serif))
                .italic()
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(themeColor.opacity(0.15), lineWidth: 1)
                )
        )
    }
}
*/

// MARK: - 🎯 非同期画像ビュー（遅延読み込み + スケルトンUI）
// Commented out - requires ImageCacheManager to be properly linked
/*
struct AsyncImageView: View {
    let photoID: UUID
    let imageData: Data
    let imageCache: ImageCacheManager
    var previewMode: Bool = false

    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @State private var shimmerPhase: CGFloat = 0

    private var cacheKey: String { photoID.uuidString }
    private var previewKey: String { cacheKey + "_preview" }
    private let limeGreen = Color.brandGreen

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if isLoading {
                // 🎨 スケルトンUI（シマーエフェクト付き）
                skeletonView
            } else {
                // 読み込み失敗時
                Color.white.opacity(0.05)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.2))
                            Text("読み込み失敗")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: loadedImage)
        .onChange(of: previewMode) { _, newValue in
            Task { await loadImage(preview: newValue) }
        }
        .task { await loadImage(preview: previewMode) }
    }
    
    // MARK: - スケルトンビュー（シマーエフェクト）
    
    private var skeletonView: some View {
        ZStack {
            // ベース背景
            LinearGradient(
                colors: [
                    Color.white.opacity(0.03),
                    Color.white.opacity(0.06),
                    Color.white.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // シマーエフェクト
            LinearGradient(
                colors: [
                    Color.clear,
                    limeGreen.opacity(0.08),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: shimmerPhase)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    shimmerPhase = 400
                }
            }
            
            // 読み込み中アイコン
            VStack(spacing: 12) {
                ProgressView()
                    .tint(limeGreen)
                    .scaleEffect(1.2)
                
                Text("Loading...")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(limeGreen.opacity(0.7))
                    .textCase(.uppercase)
            }
        }
    }

    // MARK: - 画像読み込み（キャッシュ対応）
    
    private func loadImage(preview: Bool) async {
        await MainActor.run { isLoading = true }
        
        // プレビューモード：低解像度を素早く読み込み
        if preview {
            if let cachedPreview = imageCache.getImage(forKey: previewKey) {
                await MainActor.run { 
                    loadedImage = cachedPreview
                    isLoading = false 
                }
                return
            }
            
            let low = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard let image = UIImage(data: imageData) else { return nil }
                let target = CGSize(width: 400, height: 400) // より小さいサイズで高速化
                return await image.downsampled(to: target)
            }.value
            
            await MainActor.run {
                if let low { 
                    imageCache.setImage(low, forKey: previewKey)
                    loadedImage = low
                }
                isLoading = false
            }
            return
        }
        
        // 通常モード：フル解像度を読み込み
        if let cached = imageCache.getImage(forKey: cacheKey) {
            await MainActor.run { 
                loadedImage = cached
                isLoading = false 
            }
            return
        }
        
        // まずプレビューがあればそれを表示
        if let cachedPreview = imageCache.getImage(forKey: previewKey) {
            await MainActor.run { loadedImage = cachedPreview }
        }
        
        let full = await Task.detached(priority: .userInitiated) { 
            UIImage(data: imageData) 
        }.value
        
        await MainActor.run {
            if let full { 
                imageCache.setImage(full, forKey: cacheKey)
                loadedImage = full
            }
            isLoading = false
        }
    }
}
*/

// MARK: - 🎯 全画面写真ビュー

struct FullScreenPhotoView: View {
    let photo: LaterPhoto
    @Binding var isPresented: Bool
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if photo.isUnlocked {
                CachedPhotoImage(imageData: photo.imageData, cacheKey: photo.imageCacheKey) { uiImage in
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1.0), 4.0)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale < 1.0 {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            scale = 1.0
                                            offset = .zero
                                        }
                                    }
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset

                                    // スケールが1.0なら閉じる
                                    if scale == 1.0 && abs(offset.height) > 100 {
                                        isPresented = false
                                    }
                                }
                        )
                }
            }
            
            // 閉じるボタン
            VStack {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                            )
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

// MARK: - 旧コンポーネント削除（TactileDialNavigation等は別ファイルへ移動または削除）

// MARK: - Preview

struct TactileDialNavigation: View {
    let dates: [Date]
    @Binding var selectedIndex: Int
    let themeColor: Color
    let onDateChanged: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private let arcRadius: CGFloat = 700 // より巨大な円弧
    private let baseAngle: Double = 16.0 // 各アイテム間の基準角度
    
    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height + arcRadius - 200
            
            ZStack {
                // 背景の円弧ガイドライン（グロー効果付き）
                arcGuidelineWithGlow(centerX: centerX, centerY: centerY)
                
                // 日付アイテム
                ForEach(Array(dates.indices), id: \.self) { index in
                    let distanceFromCenter = CGFloat(index - selectedIndex)
                    let angle = angleForOffset(distanceFromCenter)
                    let position = positionOnArc(
                        centerX: centerX,
                        centerY: centerY,
                        radius: arcRadius,
                        angle: angle
                    )
                    
                    // 強化されたフィッシュアイエフェクト
                    let scale = enhancedScaleForDistance(distanceFromCenter)
                    let opacity = enhancedOpacityForDistance(distanceFromCenter)
                    let rotation = enhancedRotationForDistance(distanceFromCenter)
                    let blur = blurForDistance(distanceFromCenter)
                    let zIndex = zIndexForDistance(distanceFromCenter)
                    
                    LegacyDateDialItem(
                        date: dates[index],
                        isSelected: selectedIndex == index,
                        themeColor: themeColor
                    )
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .rotationEffect(.degrees(rotation))
                    .blur(radius: blur)
                    .position(position)
                    .zIndex(zIndex)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: selectedIndex)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedIndex = index
                        }
                        onDateChanged()
                    }
                }
                
                // 中央マーカー（選択位置のインジケーター）
                centerMarker
                    .position(x: centerX, y: centerY - arcRadius + 50)
            }
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation.width
                        
                        // リアルタイム切り替え（スムーズ）
                        let threshold: CGFloat = 60
                        if dragOffset > threshold && selectedIndex > 0 {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                selectedIndex -= 1
                            }
                            onDateChanged()
                            dragOffset = 0
                        } else if dragOffset < -threshold && selectedIndex < dates.count - 1 {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                selectedIndex += 1
                            }
                            onDateChanged()
                            dragOffset = 0
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        dragOffset = 0
                    }
            )
        }
    }
    
    // MARK: - ビジュアル要素
    
    @ViewBuilder
    private func arcGuidelineWithGlow(centerX: CGFloat, centerY: CGFloat) -> some View {
        // 外側のグロー
        Circle()
            .trim(from: 0.35, to: 0.65) // 円弧の表示範囲
            .stroke(
                LinearGradient(
                    colors: [
                        themeColor.opacity(0.0),
                        themeColor.opacity(0.15),
                        themeColor.opacity(0.15),
                        themeColor.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .frame(width: arcRadius * 2, height: arcRadius * 2)
            .position(x: centerX, y: centerY)
            .blur(radius: 8)
        
        // メインの円弧
        Circle()
            .trim(from: 0.35, to: 0.65)
            .stroke(
                LinearGradient(
                    colors: [
                        themeColor.opacity(0.0),
                        themeColor.opacity(0.25),
                        themeColor.opacity(0.25),
                        themeColor.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
            )
            .frame(width: arcRadius * 2, height: arcRadius * 2)
            .position(x: centerX, y: centerY)
    }
    
    private var centerMarker: some View {
        VStack(spacing: 6) {
            // 三角形のポインター
            Triangle()
                .fill(themeColor)
                .frame(width: 12, height: 8)
            
            // 発光する小さな円
            Circle()
                .fill(themeColor)
                .frame(width: 4, height: 4)
                .shadow(color: themeColor, radius: 8, x: 0, y: 0)
        }
    }
    
    // MARK: - Helpers
    
    private func angleForOffset(_ offset: CGFloat) -> Double {
        Double(offset) * baseAngle
    }
    
    private func positionOnArc(centerX: CGFloat, centerY: CGFloat, radius: CGFloat, angle: Double) -> CGPoint {
        let radians = angle * .pi / 180
        let x = centerX + radius * sin(radians)
        let y = centerY - radius * cos(radians)
        return CGPoint(x: x, y: y)
    }
    
    // MARK: - 強化されたフィッシュアイエフェクト
    
    private func enhancedScaleForDistance(_ distance: CGFloat) -> CGFloat {
        let absDist = abs(distance)
        
        switch absDist {
        case 0:
            return 1.3 // 中央：最大
        case 1:
            return 0.95
        case 2:
            return 0.7
        case 3:
            return 0.5
        default:
            return max(0.3, 0.5 - (absDist - 3) * 0.1) // 徐々に縮小
        }
    }
    
    private func enhancedOpacityForDistance(_ distance: CGFloat) -> Double {
        let absDist = abs(distance)
        
        switch absDist {
        case 0:
            return 1.0 // 中央：完全不透明
        case 1:
            return 0.85
        case 2:
            return 0.6
        case 3:
            return 0.35
        default:
            return max(0.1, 0.35 - (absDist - 3) * 0.1) // フェードアウト
        }
    }
    
    private func enhancedRotationForDistance(_ distance: CGFloat) -> Double {
        // 遠近法：奥へ沈むように傾ける
        let absDist = abs(distance)
        let baseRotation = Double(distance) * -6.0
        
        // 中央から離れるほど傾きを強調
        let depthFactor = min(absDist * 0.5, 2.0)
        
        return baseRotation * (1.0 + depthFactor)
    }
    
    private func blurForDistance(_ distance: CGFloat) -> CGFloat {
        let absDist = abs(distance)
        
        switch absDist {
        case 0, 1:
            return 0 // シャープ
        case 2:
            return 0.5
        case 3:
            return 1.5
        default:
            return min(3.0, 1.5 + (absDist - 3) * 0.5) // ぼかし強化
        }
    }
    
    private func zIndexForDistance(_ distance: CGFloat) -> Double {
        // 中央に近いほど手前に
        return 100.0 - abs(distance) * 10.0
    }
}

// MARK: - 三角形シェイプ（ポインター用）

fileprivate struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 日付ダイヤルアイテム（TactileDialNavigation用 - 削除済み）
// Note: DateDialItem is now defined below for BottomNavigationDial use

// Legacy DateDialItem for TactileDialNavigation (kept for compatibility)
fileprivate struct LegacyDateDialItem: View {
    let date: Date
    let isSelected: Bool
    let themeColor: Color
    
    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(monthString)/")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(isSelected ? themeColor : .white.opacity(0.4))
            
            Text(dayString)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? themeColor : .white)
            
            Circle()
                .fill(isSelected ? themeColor : Color.white.opacity(0.3))
                .frame(width: 4, height: 4)
        }
        .frame(width: 60, height: 60)
    }
}

// MARK: - Personal写真カード

struct PersonalPhotoCard: View {
    let photo: LaterPhoto
    let themeColor: Color
    
    var body: some View {
        VStack(spacing: 0) {
            // 写真
            if photo.isUnlocked {
                CachedPhotoImage(imageData: photo.imageData, cacheKey: photo.imageCacheKey) { uiImage in
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 320)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            themeColor.opacity(0.3),
                                            themeColor.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)

                    // キャプション
                    if let caption = photo.caption, !caption.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "quote.opening")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(themeColor.opacity(0.6))

                            Text(caption)
                                .font(.system(size: 15, design: .serif))
                                .italic()
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(2)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(themeColor.opacity(0.15), lineWidth: 1)
                                )
                        )
                        .padding(.top, 12)
                    }
                } placeholder: {
                    DevelopingPhotoPlaceholder(themeColor: themeColor)
                        .frame(height: 320)
                }
            } else {
                // 現像中
                DevelopingPhotoPlaceholder(themeColor: themeColor)
                    .frame(height: 320)
            }
        }
    }
}

// MARK: - Groupベストショットカード

struct GroupBestShotCard: View {
    let photo: LaterPhoto
    let themeColor: Color
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // 写真
                if photo.isUnlocked {
                    CachedPhotoImage(imageData: photo.imageData, cacheKey: photo.imageCacheKey) { uiImage in
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 450)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                // 栄光のフレーム
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.yellow.opacity(0.8),
                                                Color.orange.opacity(0.6),
                                                Color.yellow.opacity(0.8)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 3
                                    )
                            )
                            .shadow(color: Color.yellow.opacity(0.5), radius: 24, x: 0, y: 0)
                            .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 10)
                    }
                }
                
                // MVPバッジ（右上）
                VStack {
                    HStack {
                        Spacer()
                        MVPBadge(voteCount: photo.voteCount, themeColor: themeColor)
                            .padding(.trailing, 16)
                            .padding(.top, 16)
                    }
                    Spacer()
                }
            }
            
            // ベストショット情報
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.yellow)
                    
                    Text("Best Shot of the Day")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                    
                    Spacer()
                }
                
                if let caption = photo.caption, !caption.isEmpty {
                    HStack {
                        Text(caption)
                            .font(.system(size: 14, design: .serif))
                            .italic()
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(3)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.yellow.opacity(0.12),
                                Color.orange.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.yellow.opacity(0.25), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - MVPバッジ

struct MVPBadge: View {
    let voteCount: Int
    let themeColor: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.yellow)
            
            Text("\(voteCount)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            
            Text("votes")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.yellow.opacity(0.3),
                            Color.orange.opacity(0.3)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.yellow.opacity(0.5), lineWidth: 1.5)
                )
        )
        .shadow(color: Color.yellow.opacity(0.4), radius: 12, x: 0, y: 0)
    }
}

// MARK: - 投票中ビュー

struct VotingInProgressView: View {
    let themeColor: Color
    
    @State private var animating = false
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // 回転するリング
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                themeColor.opacity(0.6),
                                themeColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(animating ? 360 : 0))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: animating)
                
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(themeColor)
            }
            
            VStack(spacing: 8) {
                Text("Voting...")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                
                Text("投票フェーズ進行中")
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            // カウントダウン表示（オプション）
            // Note: Uncomment when VotingManager is integrated
            // if let session = VotingManager.shared.activeVotingSession {
            //     Text(timeRemainingString(session.timeRemaining))
            //         .font(.system(size: 16, weight: .semibold, design: .monospaced))
            //         .foregroundStyle(themeColor)
            //         .padding(.horizontal, 20)
            //         .padding(.vertical, 10)
            //         .background(
            //             Capsule()
            //                 .fill(themeColor.opacity(0.15))
            //                 .overlay(
            //                     Capsule()
            //                         .strokeBorder(themeColor.opacity(0.3), lineWidth: 1)
            //                 )
            //         )
            // }
        }
        .onAppear {
            animating = true
        }
    }
    
    private func timeRemainingString(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return String(format: "%02d:%02d 残り", hours, minutes)
    }
}

// MARK: - 現像中プレースホルダー

struct DevelopingPhotoPlaceholder: View {
    let themeColor: Color
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "photo.fill.on.rectangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(themeColor.opacity(0.5))
                    
                    Text("現像中...")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundStyle(.white.opacity(0.6))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(themeColor.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - 🎯 水平タップバー（シンプル・フラット・タップ優先）

struct HorizontalDateTapBar: View {
    let dates: [Date]
    @Binding var selectedDate: Date
    let photoAvailability: [Date: Bool]
    var onDateChanged: (Date) -> Void
    
    private let limeGreen = Color.limeGreen
    private let itemWidth: CGFloat = 70
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(dates, id: \.self) { date in
                            DateTapItem(
                                date: date,
                                isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                                hasPhotos: photoAvailability[date] ?? false,
                                limeGreen: limeGreen
                            )
                            .frame(width: itemWidth)
                            .id(date)
                            .onTapGesture {
                                withAnimation(.snappy(duration: 0.2)) {
                                    selectedDate = date
                                    onDateChanged(date)
                                }
                                
                                // ハプティクス
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                
                                // スクロールして中央に配置
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(date, anchor: .center)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, (geometry.size.width - itemWidth) / 2)
                }
                .onAppear {
                    // 初期表示時に選択中の日付へスクロール
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(selectedDate, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - 日付タップアイテム

struct DateTapItem: View {
    let date: Date
    let isSelected: Bool
    let hasPhotos: Bool
    let limeGreen: Color
    
    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var weekdayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // 日付
            Text(dayString)
                .font(.system(size: isSelected ? 24 : 18, weight: isSelected ? .black : .semibold, design: .rounded))
                .foregroundStyle(isSelected ? limeGreen : .white.opacity(0.6))
            
            // 曜日
            Text(weekdayString)
                .font(.system(size: isSelected ? 11 : 9, weight: .medium, design: .monospaced))
                .foregroundStyle(isSelected ? limeGreen.opacity(0.8) : .white.opacity(0.4))
            
            // 写真有無インジケーター
            Circle()
                .fill(hasPhotos ? limeGreen : Color.gray.opacity(0.2))
                .frame(width: isSelected ? 6 : 4, height: isSelected ? 6 : 4)
                .shadow(color: hasPhotos && isSelected ? limeGreen : .clear, radius: 6)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.05) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? limeGreen : Color.clear, lineWidth: 2)
                )
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Color Hex Extension
// Note: Color extensions moved to ColorExtensions.swift to avoid ambiguity

// MARK: - UIImage Downsampling Extension
// Note: Moved to CommonExtensions.swift to avoid ambiguity

// MARK: - Preview

#Preview("Gallery - Button Grid") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: UserProfile.self, LaterPhoto.self,
        configurations: config
    )
    
    GalleryView()
        .modelContainer(container)
}

#Preview("Date Button Grid - Standalone") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            DateButtonGridView(
                dates: {
                    let calendar = Calendar.current
                    let today = Date()
                    return (0..<30).map { calendar.date(byAdding: .day, value: -$0, to: today)! }
                }(),
                selectedDate: .constant(Date()),
                photoAvailability: [
                    Date(): true,
                    Calendar.current.date(byAdding: .day, value: -1, to: Date())!: true,
                    Calendar.current.date(byAdding: .day, value: -3, to: Date())!: false
                ],
                neonGreen: .green,
                onDateChanged: { }
            )
            .frame(height: 140)
            .background(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.8),
                        Color.black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

#Preview("Horizontal Date Tap Bar - Standalone") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            HorizontalDateTapBar(
                dates: {
                    let calendar = Calendar.current
                    let today = Date()
                    return (0..<30).map { calendar.date(byAdding: .day, value: -$0, to: today)! }
                }(),
                selectedDate: .constant(Date()),
                photoAvailability: [:],
                onDateChanged: { _ in }
            )
            .frame(height: 80)
            .background(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.5),
                        Color.black.opacity(0.85),
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

#Preview("Personal Photo Card") {
    ZStack {
        Color.black.ignoresSafeArea()
        PersonalPhotoCard(
            photo: {
                let photo = LaterPhoto(imageData: Data(), unlockDate: Date(), caption: "美しい夕焼け")
                photo.isUnlocked = true
                return photo
            }(),
            themeColor: Color.green
        )
        .padding()
    }
}

#Preview("Group Best Shot Card") {
    ZStack {
        Color.black.ignoresSafeArea()
        GroupBestShotCard(
            photo: {
                let photo = LaterPhoto(imageData: Data(), unlockDate: Date(), caption: "グループで選ばれた最高の1枚")
                photo.isUnlocked = true
                photo.voteCount = 12
                photo.isGroupBestShot = true
                return photo
            }(),
            themeColor: Color.green
        )
        .padding()
    }
}

#Preview("Voting In Progress") {
    ZStack {
        Color.black.ignoresSafeArea()
        VotingInProgressView(themeColor: Color.green)
    }
}

#Preview("Developing Badge") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 30) {
            DevelopingBadge(progress: 0.15)
            DevelopingBadge(progress: 0.47)
            DevelopingBadge(progress: 0.89)
            DevelopingBadge(progress: 0.99)
        }
    }
}

// MARK: - 🎞️ 現像中バッジ（点滅エフェクト付き）

struct DevelopingBadge: View {
    let progress: Double
    
    @State private var isBlinking = false
    
    private let neonGreen = Color.neonGreen
    
    var body: some View {
        HStack(spacing: 8) {
            // アイコン（フィルムロール）
            Image(systemName: "film.fill")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(neonGreen)
            
            // テキスト
            Text("DEVELOPING")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(neonGreen)
                .opacity(isBlinking ? 0.4 : 1.0)
            
            // 進捗パーセンテージ
            Text("\(Int(progress * 100))%")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(neonGreen.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(neonGreen.opacity(0.6), lineWidth: 1.5)
                )
                .shadow(color: neonGreen.opacity(0.3), radius: 8, x: 0, y: 0)
        )
        .onAppear {
            // ゆっくり点滅（2秒周期）
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
            ) {
                isBlinking = true
            }
        }
    }
}

// MARK: - Array Safe Subscript Extension
// Note: Moved to CommonExtensions.swift to avoid ambiguity



