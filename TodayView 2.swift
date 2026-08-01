import SwiftUI
import SwiftData

// DISABLED: This file contains duplicate type declarations
// The main implementation is in TodayView.swift
// To re-enable, rename the types below (e.g., TodayView_Alt)

/// 📸 Today View - カメラと今日の撮影状況
struct TodayView_Disabled: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var photos: [LaterPhoto]
    
    @AppStorage("photosTaken") private var photosTaken: Int = 0
    
    @State private var showingCamera = false
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    private var dailyGoal: Int {
        currentUser?.dailyGoal ?? 3
    }
    
    private var todayPhotos: [LaterPhoto] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return photos.filter { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: today)
        }
    }
    
    private var progress: Double {
        Double(photosTaken) / Double(dailyGoal)
    }
    
    var body: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                
                ScrollView {
                    VStack(spacing: 32) {
                        progressSection
                        cameraButton
                        todayPhotosSection
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Today")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text(Date().formatted(date: .long, time: .omitted))
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.top, 60)
        .padding(.bottom, 20)
    }
    
    private var progressSection: some View {
        VStack(spacing: 16) {
            // プログレスリング
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 15)
                    .frame(width: 180, height: 180)
                
                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(
                        LinearGradient(
                            colors: [.brandGreen, .brandGreen.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 15, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                
                VStack(spacing: 8) {
                    Text("\(photosTaken)")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("/ \(dailyGoal)")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // ステータステキスト
            if photosTaken >= dailyGoal {
                Text("🎉 今日の目標達成！")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.brandGreen)
            } else {
                Text("あと\(dailyGoal - photosTaken)枚")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.top, 20)
    }
    
    private var cameraButton: some View {
        Button {
            HapticsManager.tick()
            showingCamera = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 28))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("写真を撮影")
                        .font(.system(size: 20, weight: .bold))
                    
                    Text("思い出を記録しよう")
                        .font(.system(size: 14))
                        .opacity(0.8)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.brandGreen,
                                Color.brandGreen.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.brandGreen.opacity(0.5), radius: 20, y: 10)
            )
        }
        .sheet(isPresented: $showingCamera) {
            CameraPlaceholderView()
        }
    }
    
    private var todayPhotosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("今日の撮影")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            
            if todayPhotos.isEmpty {
                emptyPhotosView
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(todayPhotos, id: \.id) { photo in
                        PhotoThumbnail(photo: photo)
                    }
                }
            }
        }
    }
    
    private var emptyPhotosView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.3))
            
            Text("まだ撮影していません")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            
            Text("最初の1枚を撮影しましょう")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Photo Thumbnail

struct PhotoThumbnail: View {
    let photo: LaterPhoto
    
    var body: some View {
        GeometryReader { geometry in
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: geometry.size.width, height: geometry.size.width)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Camera Placeholder

struct CameraPlaceholderView_Disabled: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("📸")
                    .font(.system(size: 80))
                
                Text("カメラ機能")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("（実装予定）")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.7))
                
                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.brandGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: UserProfile.self, LaterPhoto.self,
        configurations: config
    )
    
    TodayView_Disabled()
        .modelContainer(container)
}
