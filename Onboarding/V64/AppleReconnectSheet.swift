import AuthenticationServices
import SwiftUI

/// v104 P47 A:前から Apple で 入って いる 人に、起動の とき 1回 だけ 出す「Apple で つなぎなおす」。
/// ログアウトは しない。あとで も 押せる(つぎの 起動で また 出る)。おわったら firebaseUID が 入る。
struct AppleReconnectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var coordinator: OBAppleCoordinator?
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: 14) {
            Capsule().fill(.white.opacity(0.2)).frame(width: 36, height: 4).padding(.top, 8)
            Text("Apple で つなぎなおす").font(LF.inter(800, 20)).foregroundStyle(.white).padding(.top, 8)
            Text("これまでの 友だちや 写真は そのままです。1回 だけ Apple で 確認すると、友だちの しくみが あたらしく なります。")
                .font(LF.inter(500, 13)).foregroundStyle(HV.gray).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Button(action: start) {
                HStack(spacing: 8) { Image(systemName: "apple.logo"); Text("Apple で つなぎなおす") }
                    .font(LF.inter(800, 16)).foregroundStyle(.black).frame(maxWidth: .infinity).frame(height: 52).background(.white, in: Capsule())
            }.buttonStyle(.plain).disabled(busy)
            if let message { Text(message).font(LF.inter(600, 12)).foregroundStyle(HV.red) }
            Button("あとで") { dismiss() }.font(LF.inter(700, 14)).foregroundStyle(HV.gray).frame(height: 44)
        }
        .padding(.horizontal, 24).padding(.bottom, 12).frame(maxWidth: .infinity)
        .background(Color(hex: "111113").ignoresSafeArea()).preferredColorScheme(.dark)
        .presentationDetents([.height(330)])
    }

    private func start() {
        guard !busy else { return }
        busy = true; message = nil
        let expected = UserDefaults.standard.string(forKey: "appleUserID") ?? ""
        let c = OBAppleCoordinator(hideEmail: true) { result, nonce in
            Task { @MainActor in
                defer { busy = false; coordinator = nil }
                switch result {
                case .success(let auth):
                    guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else { message = "Apple の 確認に 失敗しました"; return }
                    do { try await AppleFirebaseAuth.signIn(cred, rawNonce: nonce, expectedAppleUser: expected); Haptics.play(.success); dismiss() }
                    catch AppleFirebaseAuth.AuthFailure.userMismatch { Haptics.play(.warn); message = "ちがう Apple ID です。いつもの Apple ID で えらんで ください" }
                    catch { Haptics.play(.warn); message = "つなげませんでした。あとで もう一度 ためして ください"
                        print("[AppleFirebase] reconnect failed: \(FirebaseAuthService.debugLabel(for: error))") }
                case .failure(let error):
                    if (error as? ASAuthorizationError)?.code != .canceled { message = "つなげませんでした" }
                }
            }
        }
        coordinator = c
        c.start()
    }
}
