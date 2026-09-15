import SwiftUI
import PhotosUI
import SwiftData

#if DEBUG
// If there are multiple UserProfile types across modules, specify the correct one here.
// e.g. typealias AppUserProfile = MyAppModule.UserProfile
// For now, we keep the original name to avoid breaking references.
#endif

private enum ProfileCreationStep: Int, CaseIterable {
    case welcome, name, icon, goal, done

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .name: return "Your Name"
        case .icon: return "Choose Icon"
        case .goal: return "Daily Goal"
        case .done: return "Done"
        }
    }
}

struct ProfileCreationFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isProfileSetupCompleted") private var isProfileSetupCompleted: Bool = false
    @Bindable var profile: UserProfile
    var onFinish: (() -> Void)?

    @State private var step: ProfileCreationStep = .welcome
    @State private var pickedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                header
                content
                Spacer()
                controls
            }
            .padding()
            .navigationTitle(step.title)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: step) { oldValue, newValue in saveProfile() }
            .onChange(of: pickedItem) { oldValue, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        profile.profileImageData = data
                        saveProfile()
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Step \(step.rawValue + 1) of \(ProfileCreationStep.allCases.count)")
                .font(.caption.weight(.semibold))
                .foregroundColor(Color.accentColor.opacity(0.7))
            // Progress bar
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.35))
                        .frame(width: proxy.size.width * CGFloat(step.rawValue + 1) / CGFloat(ProfileCreationStep.allCases.count))
                }
            }
            .frame(height: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                    .padding(.bottom, 4)
                Text("Let's create your profile!")
                    .font(.title2).bold()
                Text("Follow the steps to set up your profile.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.08))
            )

        case .name:
            VStack(alignment: .leading, spacing: 12) {
                Text("Your display name")
                    .font(.headline)
                HStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                    TextField("Enter your name", text: $profile.name)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.08))
                )

                Text("この名前はプロフィールに表示されます。いつでも変更できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        case .icon:
            VStack(spacing: 16) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let data = profile.profileImageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "person.fill")
                                .resizable()
                                .scaledToFit()
                                .padding(24)
                                .foregroundStyle(.secondary)
                                .background(Color.secondary.opacity(0.12))
                        }
                    }
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 3))
                    .shadow(radius: 4, y: 2)

                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Image(systemName: "camera.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                            .shadow(radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 6, y: 6)
                }

                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("Change Photo", systemImage: "photo.on.rectangle.angled")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(12)
                }
                .buttonStyle(.borderless)

                Text("顔写真やアイコン画像を選択してください。丸くトリミングされます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        case .goal:
            VStack(spacing: 16) {
                Text("Set your daily goal")
                    .font(.headline)

                HStack {
                    Text("1")
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding<Double>(
                            get: { Double(profile.dailyGoal) },
                            set: { newValue in profile.dailyGoal = Int(newValue.rounded()) }
                        ),
                        in: 1...5,
                        step: 1
                    )
                    Text("5")
                        .foregroundStyle(.secondary)
                }

                Text("毎日の目標値を選択しましょう。後から変更できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        case .done:
            VStack(spacing: 16) {
                Text("All set!")
                    .font(.title2).bold()
                Text("You're ready to start using the app with your new profile.")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private var controls: some View {
        HStack {
            if step != .welcome {
                Button("Back") {
                    withAnimation {
                        step = ProfileCreationStep(rawValue: step.rawValue - 1) ?? .welcome
                    }
                }
                .buttonStyle(.bordered)
            } else {
                Spacer()
            }

            Spacer()

            if step != .done {
                Button("Next") {
                    withAnimation {
                        step = ProfileCreationStep(rawValue: step.rawValue + 1) ?? .done
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(step == .name && profile.name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty)
            } else {
                Button("Finish") {
                    saveProfile()
                    // プロフィール設定完了をマーク
                    if !profile.name.isEmpty {
                        isProfileSetupCompleted = true
                    }
                    onFinish?()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func saveProfile() {
        if let ctx = profile.modelContext {
            do {
                try ctx.save()
            } catch {
                #if DEBUG
                print("Failed to save profile: \(error)")
                #endif
            }
        }
    }
}

#Preview {
    ProfileCreationFlowView(profile: UserProfile(name: "", username: "user_000"))
}
