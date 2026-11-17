import SwiftUI
import UIKit

/// v47:ともだちのQR(later://friend?u=<recordName>)を読む。グループ参加のQRScanViewとは別の、
/// ともだち専用の軽いスキャナ(QRScanCamera/QRCameraPreview/ScanBrackets を共用)。
/// グループ参加の処理には ふれない。
struct FriendQRScanView: View {
    let myName: String
    let friendCount: Int
    let onToast: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var camera = QRScanCamera()
    @State private var found: (recordName: String, name: String)?
    @State private var connecting = false

    var body: some View {
        ZStack {
            if camera.access == .denied || camera.access == .unavailable {
                deniedView
            } else {
                QRCameraPreview(camera: camera)
                ScanBrackets(cornerRadius: 16)
                    .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 240, height: 240)
                    .opacity(found == nil ? 1 : 0)
                VStack {
                    HStack {
                        closeButton
                        Spacer()
                    }
                    Spacer()
                    Text("ともだちの QRコードを、窓に あわせて。")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.bottom, 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.code) { _, code in checkCode(code) }
        .sheet(item: Binding(
            get: { found.map { ConfirmItem(recordName: $0.recordName, name: $0.name) } },
            set: { if $0 == nil { found = nil; camera.isPaused = false } }
        )) { item in
            FriendConnectConfirm(name: item.name, isConnecting: connecting, onCancel: {
                found = nil
                camera.isPaused = false
            }, onConnect: {
                connect(recordName: item.recordName, name: item.name)
            })
        }
    }

    private struct ConfirmItem: Identifiable { let recordName: String; let name: String; var id: String { recordName } }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(.white.opacity(0.12)).background(.ultraThinMaterial, in: Circle()))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("閉じる")
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            HStack { closeButton; Spacer() }.padding(.horizontal, 20).padding(.top, 50)
            Spacer()
            Image(systemName: "video.slash").font(.system(size: 30)).foregroundStyle(.white.opacity(0.85))
            Text("カメラが、つかえません。").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
            Spacer()
        }
    }

    private func checkCode(_ code: String?) {
        guard found == nil, let code, let url = URL(string: code), let recordName = FriendRules.recordName(from: url) else { return }
        camera.isPaused = true
        Haptics.play(.pop)
        found = (recordName, "")
        Task {
            let profile = await UserDirectoryService.fetchProfile(cloudKitUserRecordName: recordName)
            found = (recordName, profile?.name.isEmpty == false ? profile!.name : "ともだち")
        }
    }

    private func connect(recordName: String, name: String) {
        connecting = true
        Task {
            let result = await FriendCloud.connect(to: recordName, myName: myName, myCount: friendCount, theirCount: 0)
            connecting = false
            switch result {
            case .success:
                Haptics.play(.success)
                BumpFriendStore.remember(id: recordName, name: name)
                found = nil
                dismiss()
                onToast("\(name) と つながった")
            case .failure(let error):
                Haptics.play(.warn)
                onToast(error.message)
            }
        }
    }
}

/// 「つながる?」の確認(ShakeConnectSheet と同じ考え方の、静かな版)
private struct FriendConnectConfirm: View {
    let name: String
    let isConnecting: Bool
    let onCancel: () -> Void
    let onConnect: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(.white.opacity(0.2)).frame(width: 36, height: 4).padding(.top, 10)
            Spacer(minLength: 8)
            Text(name).font(.system(size: 28, weight: .heavy)).foregroundStyle(.white)
            Text("と、つながりますか?").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                Button("やめる") { onCancel() }
                    .font(.system(size: 16, weight: .heavy)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54).background(Capsule().fill(.white.opacity(0.14)))
                Button {
                    onConnect()
                } label: {
                    if isConnecting {
                        ProgressView().tint(.black).frame(maxWidth: .infinity, minHeight: 54)
                    } else {
                        Text("つながる").font(.system(size: 16, weight: .heavy)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 54)
                    }
                }
                .background(Capsule().fill(.white))
                .disabled(isConnecting)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(260)])
        .presentationBackground(.black)
        .environment(\.colorScheme, .dark)
    }
}
