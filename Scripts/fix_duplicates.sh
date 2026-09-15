#!/bin/bash

# Quick Fix Script for Remaining Errors
# このスクリプトを実行して残りのエラーを修正します

# プロジェクトディレクトリに移動
cd "/Users/kitagawatatsuki/Desktop/Later 再度"

echo "🔧 重複ファイルを削除中..."

# 重複したカラー定義ファイルを削除
if [ -f "BrandColors 3.swift" ]; then
    echo "  ❌ BrandColors 3.swift を削除"
    rm "BrandColors 3.swift"
fi

if [ -f "BrandColors 2.swift" ]; then
    echo "  ❌ BrandColors 2.swift を削除"
    rm "BrandColors 2.swift"
fi

# 重複したLiquidBackgroundViewファイルを削除
if [ -f "LiquidBackgroundView 2.swift" ]; then
    echo "  ❌ LiquidBackgroundView 2.swift を削除"
    rm "LiquidBackgroundView 2.swift"
fi

if [ -f "LiquidBackgroundView 3.swift" ]; then
    echo "  ❌ LiquidBackgroundView 3.swift を削除"
    rm "LiquidBackgroundView 3.swift"
fi

if [ -f "LiquidBackgroundView 4.swift" ]; then
    echo "  ❌ LiquidBackgroundView 4.swift を削除"
    rm "LiquidBackgroundView 4.swift"
fi

# CalendarArchiveViewの修正版にリネーム
if [ -f "CalendarArchiveView_Fixed.swift" ] && [ -f "CalendarArchiveView.swift" ]; then
    echo "  🔄 CalendarArchiveView を修正版に置き換え"
    rm "CalendarArchiveView.swift"
    mv "CalendarArchiveView_Fixed.swift" "CalendarArchiveView.swift"
fi

# 他の重複ファイルをチェック
echo ""
echo "📋 残りの重複ファイルをチェック中..."
duplicates=$(ls -1 | grep -E ' [0-9]+\.swift$')
if [ -n "$duplicates" ]; then
    echo "⚠️  以下のファイルも重複の可能性があります:"
    echo "$duplicates"
    echo ""
    echo "これらのファイルを手動で確認して削除してください"
else
    echo "✅ 他に重複ファイルは見つかりませんでした"
fi

echo ""
echo "✨ クリーンアップ完了!"
echo ""
echo "次のステップ:"
echo "1. Xcode でプロジェクトをクリーン (Cmd+Shift+K)"
echo "2. ビルドフォルダを削除 (Cmd+Shift+Option+K)"
echo "3. プロジェクトをリビルド (Cmd+B)"
echo ""
echo "まだエラーが残っている場合:"
echo "- MissingComponents.swift の 394 行目を確認"
echo "- 'Ambiguous use of init()' エラーには明示的な型を追加"
