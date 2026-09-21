import SwiftUI
import SwiftData
import AuthenticationServices
import CoreImage.CIFilterBuiltins

/// Sign in with Appleのみのシンプルなログインゲート。
/// 成功すると appleUserID を保存し、既存のUserProfileがあればそれを、
/// なければこの後のOnboardingView(プロフィール入力)で新規作成する。
/// 認証ロジックは変更せず、見た目(ダーク基調・暖色グロー・グレイン・
/// アパーチャーロゴ)だけを作り替えている。
struct AppleSignInView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("appleUserID") private var appleUserID: String = ""
    @AppStorage("appleFullName") private var appleFullName: String = ""
    @AppStorage("currentProfileID") private var currentProfileID: String = ""
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false

    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showingEmailSignIn = false

    private let backgroundBlack = Color(hex: "121212")
    private let warmGlow = Color(red: 0.141, green: 0.122, blue: 0.094)         // #241f18
    private let ringOrange = Color(red: 1.0, green: 0.62, blue: 0.32)
    private let ivoryShadow = Color(red: 0.96, green: 0.92, blue: 0.84)
    private let brandGreenAccent = Color.brandGreen
    private let logoCenter = UnitPoint(x: 0.5, y: 0.34)

    var body: some View {
        ZStack {
            backgroundBlack.ignoresSafeArea()

            RadialGradient(
                colors: [warmGlow.opacity(0.9), warmGlow.opacity(0.0)],
                center: logoCenter,
                startRadius: 0,
                endRadius: 340
            )
            .blur(radius: 24)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            if let grain = SignInGrainTexture.texture {
                Image(uiImage: grain)
                    .resizable(resizingMode: .tile)
                    .blendMode(.overlay)
                    .opacity(0.05)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            GeometryReader { geo in
                ZStack {
                    ZStack {
                        Circle()
                            .stroke(ringOrange.opacity(0.12), lineWidth: 0.5)
                            .frame(width: 220, height: 220)
                        Circle()
                            .stroke(ringOrange.opacity(0.08), lineWidth: 0.5)
                            .frame(width: 300, height: 300)
                    }
                    .position(x: geo.size.width * logoCenter.x, y: geo.size.height * logoCenter.y)

                    ForEach(Self.particles) { particle in
                        Circle()
                            .fill(ringOrange.opacity(particle.opacity))
                            .frame(width: particle.size, height: particle.size)
                            .blur(radius: 0.5)
                            .position(x: geo.size.width * particle.x, y: geo.size.height * particle.y)
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 40) {
                Spacer()

                ApertureLogoView(tint: ringOrange, wordmarkColor: brandGreenAccent, wordmarkWeight: .heavy)

                Spacer()

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName]
                } onCompletion: { result in
                    handle(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 52)
                .clipShape(Capsule())
                .shadow(color: ivoryShadow.opacity(0.25), radius: 18, y: 8)
                .padding(.horizontal, 40)

                Button {
                    showingEmailSignIn = true
                } label: {
                    Text("メールでサインインする")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .underline()
                }
                .padding(.top, -16)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()
            }
            .disabled(isLoading)
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .tint(.white)
            }
        }
        .sheet(isPresented: $showingEmailSignIn) {
            EmailSignInView()
        }
    }

    /// 8個の光の粒子。毎回ランダムだとチラつくため、一度だけ生成して固定する。
    private static let particles: [SignInParticle] = (0..<8).map { _ in
        SignInParticle(
            x: Double.random(in: 0.08...0.92),
            y: Double.random(in: 0.06...0.9),
            size: CGFloat.random(in: 2...3),
            opacity: Double.random(in: 0.15...0.4)
        )
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Apple認証に失敗しました"
                return
            }

            isLoading = true
            defer { isLoading = false }

            let userID = credential.user
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            appleUserID = userID
            if !fullName.isEmpty {
                appleFullName = fullName
            }

            // 同じApple IDの既存プロフィールがあれば再利用し、そのままメイン画面へ進む。
            // なければ、この後 OnboardingView でプロフィール(名前・ユーザーID・写真)を入力してもらう。
            let descriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate<UserProfile> { $0.appleUserID == userID }
            )
            if let existing = try? modelContext.fetch(descriptor).first {
                currentProfileID = existing.id.uuidString
                isSetupCompleted = true
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

private struct SignInParticle: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let size: CGFloat
    let opacity: Double
}

/// フィルムグレイン用のノイズテクスチャ。CameraCaptureView.swift/ChekiPhotoFrame.swiftと
/// 同じ方針(CIFilter.randomGenerator()で一度だけ生成してキャッシュ)を踏襲する。
private enum SignInGrainTexture {
    static let texture: UIImage? = generate()

    private static func generate() -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.randomGenerator()
        guard let noise = filter.outputImage else { return nil }
        let size = CGSize(width: 200, height: 200)
        let cropped = noise.cropped(to: CGRect(origin: .zero, size: size))
        guard let cgImage = context.createCGImage(cropped, from: cropped.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
