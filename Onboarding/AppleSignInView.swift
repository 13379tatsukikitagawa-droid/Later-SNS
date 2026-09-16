import SwiftUI
import SwiftData
import AuthenticationServices
import CoreImage.CIFilterBuiltins

/// Sign in with Appleのみのシンプルなログインゲート。
/// 成功すると appleUserID を保存し、既存のUserProfileがあればそれを、
/// なければこの後のOnboardingView(プロフィール入力)で新規作成する。
/// 認証ロジックは変更せず、見た目だけを作り替えている。
///
/// 2026/9: 「ログイン画面（入口）最終デザイン確定プロンプト」に基づき、アパーチャー
/// アイコン・タグライン文言・写ルンです型イラスト等はすべて不採用とし、「Later」の
/// ロゴタイプ単体を画面のヒーロー要素にした(A〜G案を経て確定)。ApertureLogoViewは
/// OnboardingView/LaterAboutIntroViewでも共用しているため、この画面専用の新しい
/// ワードマーク(laterWordmark)を別に定義し、ApertureLogoView自体は変更していない。
struct AppleSignInView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("appleUserID") private var appleUserID: String = ""
    @AppStorage("appleFullName") private var appleFullName: String = ""
    @AppStorage("currentProfileID") private var currentProfileID: String = ""
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false

    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showingEmailSignIn = false

    private let ivoryShadow = Color(red: 0.96, green: 0.92, blue: 0.84)
    private let wordmarkIvory = Color(hex: "F2ECE2")
    private let misregistrationRed = Color(hex: "FF5678")
    private let misregistrationBlue = Color(hex: "4ECDFF")
    private let lightLeakOrange = Color(red: 1.0, green: 0.62, blue: 0.29)
    private let filmEdgeText = Color(hex: "F2ECE2")
    private let emailLinkColor = Color(hex: "8A7C6A")
    private let emailLinkUnderline = Color(hex: "6B5A2C")

    var body: some View {
        ZStack {
            baseBackground

            decorativeLayers

            if let grain = SignInGrainTexture.texture {
                Image(uiImage: grain)
                    .resizable(resizingMode: .tile)
                    .blendMode(.overlay)
                    .opacity(0.05)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                Spacer()

                laterWordmark

                Spacer()

                VStack(spacing: 18) {
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
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(emailLinkColor)
                            .underline(true, color: emailLinkUnderline)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                .padding(.bottom, 42)
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

    // MARK: - 背景ベース(既存のまま: 暖色ダーク+上部の緑がかった薄いグロー+ドット柄)

    private var baseBackground: some View {
        ZStack {
            Color.corkboardBackground
            CorkboardDotTexture()
            RadialGradient(
                colors: [Color.brandGreen.opacity(0.12), Color.clear],
                center: .top,
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - 「Later」ロゴタイプ(この画面唯一のヒーロー要素)

    /// 版ズレ(ミスレジストレーション)効果: 本体の背後に赤・青にズラした同じテキストを
    /// 重ねる。グロー(テキストシャドウ)は本体にのみ適用する。
    private var laterWordmark: some View {
        ZStack {
            wordmarkText
                .foregroundStyle(misregistrationRed.opacity(0.38))
                .offset(x: -4, y: 3)

            wordmarkText
                .foregroundStyle(misregistrationBlue.opacity(0.32))
                .offset(x: 4, y: -2)

            wordmarkText
                .foregroundStyle(wordmarkIvory)
                .shadow(color: Color.brandGreen.opacity(0.3), radius: 32, y: 4)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
    }

    private var wordmarkText: some View {
        Text("Later")
            .font(.system(size: 104, weight: .heavy))
            .italic()
            .kerning(-2.08)
    }

    // MARK: - 背景装飾レイヤー(ライトリーク+レンズリング大小+フィルム縁の印字。
    // いずれもこの画面固有、他画面には展開しない)

    private var decorativeLayers: some View {
        ZStack {
            Color.clear
                .overlay(alignment: .leading) {
                    filmEdgeLabel("LATER FILM 400 · ISO 400 · LATER FILM 400 ·")
                        .padding(.leading, 9)
                }
                .overlay(alignment: .trailing) {
                    filmEdgeLabel("24A · 25A · 26A · 27A · 24A ·")
                        .padding(.trailing, 9)
                }

            // ライトリーク(光漏れ、右上)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [lightLeakOrange.opacity(0.14), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 170
                    )
                )
                .frame(width: 340, height: 340)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 100, y: -80)

            // レンズリングの透かし(大)
            Circle()
                .stroke(Color.brandGreen.opacity(0.07), lineWidth: 1)
                .frame(width: 480, height: 480)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 150, y: -40)

            // レンズリングの透かし(小)
            Circle()
                .stroke(Color(hex: "F2ECE2").opacity(0.05), lineWidth: 1)
                .frame(width: 360, height: 360)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 90, y: 24)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func filmEdgeLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, design: .monospaced))
            .kerning(2.4)
            .foregroundStyle(filmEdgeText.opacity(0.1))
            .fixedSize()
            .rotationEffect(.degrees(-90))
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
