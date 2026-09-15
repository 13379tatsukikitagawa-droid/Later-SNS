import SwiftUI
import SwiftData

/// 個人プロフィール共有用QRコード。実UUID(UserProfile.id)をエンコードし、
/// 中央に「later」ロゴプレートを重ねる。QRコード自体は誤り訂正Level H・
/// 黒ドット/白背景の標準配色のまま(読み取り精度優先)にし、ダークな雰囲気は
/// 周囲の背景・白いカードの構成だけで表現する。
struct MyQRCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    private var qrData: String {
        guard let user = currentUser else {
            return QRCodeGenerator.createUserQRData(userID: "guest", userName: "ゲスト")
        }
        return QRCodeGenerator.createUserQRData(userID: user.id.uuidString, userName: user.name)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("あなたのQRコード")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 260, height: 260)

                        qrCodeImage
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                    }
                    .shadow(color: Color.brandGreen.opacity(0.3), radius: 16, x: 0, y: 8)

                    VStack(spacing: 4) {
                        Text("@\(currentUser?.username.isEmpty == false ? currentUser!.username : "guest")")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(currentUser?.name.isEmpty == false ? currentUser!.name : "ゲスト")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("マイQRコード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var qrCodeImage: Image {
        guard let logo = Self.logoPlateImage,
              let uiImage = QRCodeGenerator.generateQRCodeWithLogoPlate(
                  from: qrData,
                  size: 512,
                  logoImage: logo,
                  foregroundColor: .black,
                  backgroundColor: .white
              ) else {
            return Image(systemName: "qrcode")
        }
        return Image(uiImage: uiImage)
    }

    /// 「later」ワードマークは毎回再レンダリングする必要がないため、一度だけ生成してキャッシュする。
    /// ProfileViewのシェア機能でも同じQR生成ロジックを再利用するため、internalにしている。
    static let logoPlateImage: UIImage? = {
        let logoView = Text("later")
            .font(.system(size: 64, weight: .black, design: .serif))
            .foregroundStyle(Color.brandGreen)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
        let renderer = ImageRenderer(content: logoView)
        renderer.scale = 3
        return renderer.uiImage
    }()
}

#Preview {
    MyQRCodeView()
}
