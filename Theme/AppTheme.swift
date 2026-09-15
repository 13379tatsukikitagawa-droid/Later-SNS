import SwiftUI

// MARK: - ブランドカラーテーマ
// プロジェクト全体で使用する統一カラー定義
// カラー定義は AppColors.swift で行われています。
// このファイルではグラデーションなどのカラー組み合わせを定義します。

extension LinearGradient {
    /// ヘッダー用ブランドグラデーション
    /// ヘッダーやカードの背景に使用
    static var brandHeader: LinearGradient {
        LinearGradient(
            colors: [Color.brandBlack.opacity(0.9), Color.brandGreen.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
