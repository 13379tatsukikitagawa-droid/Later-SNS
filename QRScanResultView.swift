import SwiftUI

/// QRスキャン結果のプレビューと確認ダイアログ
struct QRScanResultView: View {
    let scannedData: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var resultType: QRResultType?
    @State private var isLoading = true
    
    enum QRResultType {
        case user(id: String, name: String)
        case group(id: String, name: String)
        case invalid(message: String)
    }
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // メインコンテンツ
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if let type = resultType {
                    switch type {
                    case .user(let id, let name):
                        userResultView(id: id, name: name)
                    case .group(let id, let name):
                        groupResultView(id: id, name: name)
                    case .invalid(let message):
                        invalidResultView(message: message)
                    }
                }
            }
            .frame(width: 320)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.brandDarkGray)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.brandGreen.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 30)
        }
        .onAppear {
            parseQRData()
        }
    }
    
    // MARK: - View Components
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(.brandGreen)
                .scaleEffect(1.2)
            
            Text("読み取り中...")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(height: 200)
    }
    
    private func userResultView(id: String, name: String) -> some View {
        VStack(spacing: 24) {
            // ヘッダー
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.brandGreen.opacity(0.3),
                                    Color.brandGreen.opacity(0.1)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.brandGreen)
                }
                
                Text("ユーザーを発見")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            .padding(.top, 32)
            
            // ユーザー情報
            VStack(spacing: 8) {
                Text(name)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("@\(id.prefix(8))...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.3))
            )
            .padding(.horizontal, 24)
            
            // アクションボタン
            VStack(spacing: 12) {
                Button(action: {
                    HapticsManager.unlockSuccess()
                    onConfirm()
                }) {
                    Text("フォローする")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.brandGreen)
                        )
                }
                
                Button(action: onCancel) {
                    Text("キャンセル")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    private func groupResultView(id: String, name: String) -> some View {
        VStack(spacing: 24) {
            // ヘッダー
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.brandGreen.opacity(0.3),
                                    Color.brandGreen.opacity(0.1)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.brandGreen)
                }
                
                Text("グループ招待")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            .padding(.top, 32)
            
            // グループ情報
            VStack(spacing: 8) {
                Text(name)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("ID: \(id.prefix(8))...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.3))
            )
            .padding(.horizontal, 24)
            
            // 説明
            Text("このグループに参加しますか？")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            // アクションボタン
            VStack(spacing: 12) {
                Button(action: {
                    HapticsManager.unlockSuccess()
                    onConfirm()
                }) {
                    Text("参加する")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.brandGreen)
                        )
                }
                
                Button(action: onCancel) {
                    Text("キャンセル")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    private func invalidResultView(message: String) -> some View {
        VStack(spacing: 24) {
            // エラーアイコン
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.red.opacity(0.3),
                                Color.red.opacity(0.1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.red)
            }
            .padding(.top, 32)
            
            // メッセージ
            VStack(spacing: 8) {
                Text("無効なコード")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            // 閉じるボタン
            Button(action: onCancel) {
                Text("閉じる")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.gray.opacity(0.3))
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Helper Methods
    
    private func parseQRData() {
        // 短い遅延で読み取りアニメーション
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let userData = QRCodeGenerator.parseUserQRData(scannedData) {
                resultType = .user(id: userData.id, name: userData.name)
            } else if let groupData = QRCodeGenerator.parseGroupQRData(scannedData) {
                resultType = .group(id: groupData.id, name: groupData.name)
            } else {
                resultType = .invalid(message: "このQRコードは認識できません")
            }
            isLoading = false
        }
    }
}

// MARK: - Preview

#Preview("ユーザー結果") {
    ZStack {
        Color.black.ignoresSafeArea()
        QRScanResultView(
            scannedData: "laterapp://user?id=12345&name=TestUser",
            onConfirm: {},
            onCancel: {}
        )
    }
}

#Preview("グループ結果") {
    ZStack {
        Color.black.ignoresSafeArea()
        QRScanResultView(
            scannedData: "laterapp://group?id=group123&name=MyGroup",
            onConfirm: {},
            onCancel: {}
        )
    }
}
