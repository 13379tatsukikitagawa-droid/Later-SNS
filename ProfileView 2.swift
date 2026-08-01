import SwiftUI
import UIKit
import Observation

@Observable
public class DesignUserProfile {
  public var name: String
  public var username: String
  public var profileImageData: Data?
  public var coverImageData: Data?
  public var friendsCount: Int?
  public var followersCount: Int?
  public var followingCount: Int?
  
  public init(
    name: String,
    username: String,
    profileImageData: Data? = nil,
    coverImageData: Data? = nil,
    friendsCount: Int? = nil,
    followersCount: Int? = nil,
    followingCount: Int? = nil
  ) {
    self.name = name
    self.username = username
    self.profileImageData = profileImageData
    self.coverImageData = coverImageData
    self.friendsCount = friendsCount
    self.followersCount = followersCount
    self.followingCount = followingCount
  }
}

public struct DesignProfileView: View {
  @Bindable public var profile: DesignUserProfile
  
  private let placeholderStats = (friends: 14, followers: 3, following: 0)
  
  public init(profile: DesignUserProfile) {
    self._profile = Bindable(profile)
  }
  
  public var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        header
        nameAndUsername
        stats
        shareButton
        pinsSection
      }
      .padding(.horizontal)
      .padding(.bottom)
    }
    .ignoresSafeArea(edges: .top)
  }
  
  private var header: some View {
    ZStack(alignment: .topTrailing) {
      coverImage
        .frame(height: 200)
        .clipped()
      
      HStack(spacing: 12) {
        Button(action: {}) {
          Image(systemName: "gearshape")
            .font(.title3)
            .foregroundColor(.white)
            .padding(10)
            .background(.ultraThinMaterial, in: Circle())
        }
        Button(action: {}) {
          Image(systemName: "ellipsis")
            .font(.title3)
            .foregroundColor(.white)
            .padding(10)
            .background(.ultraThinMaterial, in: Circle())
        }
      }
      .padding(12)
      
      avatar
        .offset(x: 16, y: 130)
    }
    .padding(.bottom, 60)
  }
  
  private var coverImage: some View {
    Group {
      if let coverData = profile.coverImageData,
         let uiImage = UIImage(data: coverData) {
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFill()
      } else {
        LinearGradient(
          colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      }
    }
  }
  
  private var avatar: some View {
    Group {
      if let profileData = profile.profileImageData,
         let uiImage = UIImage(data: profileData) {
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFill()
      } else {
        Image(systemName: "person.fill")
          .resizable()
          .scaledToFit()
          .foregroundColor(.white.opacity(0.8))
          .background(Circle().fill(.gray.opacity(0.4)))
      }
    }
    .frame(width: 120, height: 120)
    .clipShape(Circle())
    .overlay(
      Circle()
        .strokeBorder(.white, lineWidth: 5)
    )
    .shadow(radius: 5)
  }
  
  private var nameAndUsername: some View {
    VStack(spacing: 2) {
      Text(profile.name)
        .font(.title)
        .fontWeight(.bold)
        .frame(maxWidth: .infinity, alignment: .leading)
      
      Text("@\(profile.username)")
        .font(.subheadline)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
  
  private var stats: some View {
    let friends = profile.friendsCount ?? placeholderStats.friends
    let followers = profile.followersCount ?? placeholderStats.followers
    let following = profile.followingCount ?? placeholderStats.following
    
      return HStack(spacing: 40) {
      statItem(count: friends, title: "Friends")
      statItem(count: followers, title: "Followers")
      statItem(count: following, title: "Following")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 4)
  }
  
  @ViewBuilder
  private func statItem(count: Int, title: String) -> some View {
    VStack(spacing: 2) {
      Text("\(count)")
        .font(.headline)
        .fontWeight(.semibold)
      Text(title)
        .font(.footnote)
        .foregroundColor(.secondary)
    }
  }
  
  private var shareButton: some View {
    Button {
      // Share action placeholder
    } label: {
      Text("Share Profile")
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
    .padding(.top, 8)
  }
  
  private var pinsSection: some View {
    VStack(spacing: 12) {
      HStack {
        Text("Pins")
          .font(.title2)
          .fontWeight(.bold)
        Spacer()
      }
      
      HStack(spacing: 12) {
        plusPinCard
        emptyPinsPlaceholderGrid
      }
    }
  }
  
  private var plusPinCard: some View {
    Button(action: {}) {
      VStack {
        Image(systemName: "plus")
          .font(.largeTitle)
          .foregroundColor(.blue)
          .padding(.bottom, 4)
        Text("Add Pin")
          .font(.footnote)
          .foregroundColor(.blue)
      }
      .frame(width: 100, height: 100)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(Color.blue, lineWidth: 2)
          .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.1)))
      )
    }
    .buttonStyle(.plain)
  }
  
  private var emptyPinsPlaceholderGrid: some View {
    let columns = [
      GridItem(.flexible(), spacing: 12),
      GridItem(.flexible(), spacing: 12),
      GridItem(.flexible(), spacing: 12)
    ]
    
    return LazyVGrid(columns: columns, spacing: 12) {
      ForEach(0..<3) { _ in
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.gray.opacity(0.15))
          .frame(height: 100)
          .overlay(
            Image(systemName: "pin.slash")
              .font(.largeTitle)
              .foregroundColor(.gray.opacity(0.4))
          )
      }
    }
  }
}

#Preview {
  NavigationStack {
    DesignProfileView(profile: DesignUserProfile(
      name: "Sophia Carter",
      username: "sophia_carter",
      friendsCount: 27,
      followersCount: 42,
      followingCount: 10
    ))
  }
}
