// This file has been removed to prevent duplicate declarations.
// ProfileView is defined in ProfileView.swift

/*
import SwiftUI
import SwiftData
import PhotosUI

/// プロフィール・設定画面（スタブ）
struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("userBio") private var userBio: String = ""
    @AppStorageData("profileImageData") private var profileImageData: Data?
    
    private var currentUser: UserProfile? {
        profiles.first
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // プロフィール画像
                        if let imageData = profileImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white.opacity(0.3))
                                )
                        }
                        
                        VStack(spacing: 8) {
                            Text(userName.isEmpty ? "ユーザー名未設定" : userName)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                            
                            if !userID.isEmpty {
                                Text("@\(userID)")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            
                            if !userBio.isEmpty {
                                Text(userBio)
                                    .font(.body)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [UserProfile.self, LaterGroup.self, LaterPhoto.self], inMemory: true)
}
*/
