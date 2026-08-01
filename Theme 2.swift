import SwiftUI

// MARK: - ブランドカラーテーマ
/// アプリ全体で使用する統一されたカラーテーマ定義

struct BrandColors {
    /// ブランドグリーン（メインカラー）
    /// 用途: アクセント、ボタン、重要な要素
    static let green = Color(red: 0.2, green: 0.8, blue: 0.6)
    
    /// ブランドブラック（背景色）
    /// 用途: ダークモード背景、メイン背景
    static let black = Color(red: 0.05, green: 0.05, blue: 0.08)
    
    /// ブランドグレー（セカンダリ背景）
    /// 用途: カード背景、セクション区切り
    static let darkGray = Color(red: 0.15, green: 0.15, blue: 0.18)
}

// MARK: - グラデーション
struct BrandGradients {
    /// ヘッダー用グラデーション
    static let header = LinearGradient(
        colors: [
            BrandColors.black.opacity(0.9),
            BrandColors.green.opacity(0.6)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// カード用グラデーション
    static let card = LinearGradient(
        colors: [
            BrandColors.darkGray.opacity(0.8),
            BrandColors.green.opacity(0.2)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// NOTE:
// グローバルな Color/LinearGradient への拡張は AppTheme.swift に集約しました。
// このファイルは補助的な色/グラデーション定義のみを保持します。

