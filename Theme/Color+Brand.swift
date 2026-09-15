import SwiftUI

// Note: Brand colors (brandGreen, brandBlack, brandDarkGray) are defined in AppColors.swift
// This file provides ShapeStyle extensions for convenient usage

extension ShapeStyle where Self == Color {
    /// ブランドカラー: グリーン (ShapeStyle として使用可能)
    static var brandGreen: Color {
        .brandGreen
    }
    
    /// ブランドカラー: ブラック (ShapeStyle として使用可能)
    static var brandBlack: Color {
        .brandBlack
    }
}
