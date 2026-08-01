#!/bin/bash

# プロジェクト内の重複ファイルを検索するスクリプト
# 使い方: ./find_duplicate_files.sh

echo "🔍 重複ファイルを検索中..."
echo ""

# 数字が付いたSwiftファイルを検索
echo "📄 数字付きファイル (例: FileName 2.swift):"
find . -type f -name "* [0-9].swift" -o -name "* [0-9][0-9].swift" | while read file; do
    echo "  ⚠️  $file"
done

echo ""

# "copy" が付いたファイルを検索
echo "📄 'copy' が付いたファイル:"
find . -type f -name "*copy*.swift" | while read file; do
    echo "  ⚠️  $file"
done

echo ""

# "old" が付いたファイルを検索
echo "📄 'old' が付いたファイル:"
find . -type f -name "*old*.swift" | while read file; do
    echo "  ⚠️  $file"
done

echo ""
echo "✅ 検索完了"
echo ""
echo "これらのファイルをXcodeで削除してください："
echo "  1. プロジェクトナビゲーターでファイルを右クリック"
echo "  2. 'Delete' を選択"
echo "  3. 'Move to Trash' を選択"
