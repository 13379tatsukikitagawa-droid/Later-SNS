import SwiftUI
import SwiftData
import AuthenticationServices
import CoreImage.CIFilterBuiltins
import os

/// Sign in with Appleのみのシンプルなログインゲート。
/// 成功すると appleUserID を保存し、既存のUserProfileがあればそれを、
/// なければこの後のOnboardingView(プロフィール入力)で新規作成する。
/// 認証ロジックは変更せず、見た目(ダーク基調・暖色グロー・グレイン・
/// アパーチャーロゴ)だけを作り替えている。
struct AppleSignInView: View {
    @Environment(\.modelContext) private var modelContext


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
        isLoading = true
        defer { isLoading = false }
        errorMessage = Self.applySignIn(result, modelContext: modelContext)
    }
}

extension AppleSignInView {
    /// Sign in with Appleの結果を保存する(初回設定のOnboardingFlowViewからも同じ処理を使う)。
    /// 成功するとappleUserIDを保存し、同じApple IDの既存プロフィールが端末にあれば、
    /// それを再利用して設定済み(isSetupCompleted)にする。失敗時はエラー文言を返す。
    @MainActor
    static func applySignIn(_ result: Result<ASAuthorization, Error>, modelContext: ModelContext) -> String? {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return "Apple認証に失敗しました"
            }
            let defaults = UserDefaults.standard
            let userID = credential.user
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            defaults.set(userID, forKey: "appleUserID")
            if !fullName.isEmpty {
                defaults.set(fullName, forKey: "appleFullName")
            }

            let descriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate<UserProfile> { $0.appleUserID == userID }
            )
            if let existing = try? modelContext.fetch(descriptor).first {
                defaults.set(existing.id.uuidString, forKey: "currentProfileID")
                defaults.set(true, forKey: "isSetupCompleted")
            }
            return nil

        case .failure(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - 計測([SignInPerf])

/// サインインの各地点の時刻(ボタンを押した T0 からの秒数)。Release の実機で測る。
/// Console.app などで「SignInPerf」を検索すると、区間ごとの時間が読める。
enum SignInPerf {
    nonisolated(unsafe) private static var start: CFAbsoluteTime?
    nonisolated(unsafe) private static var last: CFAbsoluteTime?
    private static let logger = Logger(subsystem: "com.tatsukikitagawa.later", category: "SignInPerf")

    /// T0:ボタンを押した(計測を始める)
    static func begin() {
        let now = CFAbsoluteTimeGetCurrent()
        start = now
        last = now
        logger.notice("[SignInPerf] T0 ボタンを押した")
        print("[SignInPerf] T0 ボタンを押した")
    }

    /// 地点を記録(T0 からの秒数と、前の地点からの秒数)
    static func mark(_ label: String) {
        guard let start else { return }
        let now = CFAbsoluteTimeGetCurrent()
        let total = now - start
        let delta = now - (last ?? start)
        last = now
        let line = String(format: "[SignInPerf] %@  +%.3fs (T0から %.3fs)", label, delta, total)
        logger.notice("\(line, privacy: .public)")
        print(line)
    }

    /// 計測を終える(次の画面が出た)
    static func end(_ label: String) {
        mark(label)
        start = nil
        last = nil
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
