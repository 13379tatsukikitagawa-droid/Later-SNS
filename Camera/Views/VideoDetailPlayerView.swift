//
//  VideoDetailPlayerView.swift
//  Later 再度
//
//  Galleryでの一覧はサムネイルのみ(LaterVideo.thumbnailData)で表示し、動画本体は
//  一切ダウンロード・デコードしない。この画面はタップされた時にだけ開き、
//  CloudKitManager.fetchVideoAsset(for:)で動画本体を都度フェッチして再生する。
//  端末には動画バイト列を残さない設計のため、再生後(画面を閉じた時点)で
//  取得した一時ファイルを削除する。
//

import SwiftUI
import AVKit

struct VideoDetailPlayerView: View {
    let video: LaterVideo

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var localFileURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                        .onAppear { player.play() }
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("もう一度試す") {
                            loadVideo()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(spacing: 12) {
                        if let thumbnail = UIImage(data: video.thumbnailData) {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .opacity(0.5)
                        }
                        ProgressView()
                            .tint(.white)
                        Text("動画を読み込み中…")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .onAppear {
            loadVideo()
        }
        .onDisappear {
            player?.pause()
            if let localFileURL {
                try? FileManager.default.removeItem(at: localFileURL)
            }
        }
    }

    private func loadVideo() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                guard let manager = CloudKitManager.current else {
                    throw NSError(domain: "LaterVideo", code: 3, userInfo: [NSLocalizedDescriptionKey: "同期の準備ができていません"])
                }
                let url = try await manager.fetchVideoAsset(for: video)
                await MainActor.run {
                    localFileURL = url
                    player = AVPlayer(url: url)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "動画の読み込みに失敗しました: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}
