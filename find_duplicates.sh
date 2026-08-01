#!/bin/bash

# Script to find duplicate Swift type declarations in your project
# Usage: bash find_duplicates.sh

echo "🔍 Searching for duplicate Swift declarations..."
echo ""

PROJECT_DIR="/Users/kitagawatatsuki/Desktop/Later 再度"
cd "$PROJECT_DIR"

# Function to search for duplicate declarations
find_duplicates() {
    local type=$1
    local name=$2
    
    echo "---"
    echo "Searching for: $type $name"
    grep -rn "$type $name" --include="*.swift" . | grep -v "//" | grep -v "Binary"
    echo ""
}

# Search for duplicate structs
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏗️  DUPLICATE STRUCTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
find_duplicates "struct" "CustomStampEditor"
find_duplicates "struct" "LiquidBackgroundView"
find_duplicates "struct" "CalendarArchiveView"
find_duplicates "struct" "PhotoUnlockCelebration"
find_duplicates "struct" "AnonymousVotingFeedView"
find_duplicates "struct" "PhotoCardView"
find_duplicates "struct" "DecorativeLaterLogo"
find_duplicates "struct" "CameraPreviewView"
find_duplicates "struct" "CircleManagementView"
find_duplicates "struct" "MyQRCodeView"
find_duplicates "struct" "QRScannerView"
find_duplicates "struct" "CameraView"

# Search for duplicate classes
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏛️  DUPLICATE CLASSES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
find_duplicates "class" "PhotoManager"
find_duplicates "class" "VotingManager"
find_duplicates "class" "FollowingManager"

# Search for duplicate enums
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 DUPLICATE ENUMS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
find_duplicates "enum" "HapticsManager"

# Search for duplicate color extensions
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎨 DUPLICATE COLOR PROPERTIES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "---"
echo "Searching for: brandGreen"
grep -rn "static.*brandGreen" --include="*.swift" . | grep -v "//"
echo ""

echo "---"
echo "Searching for: brandBlack"
grep -rn "static.*brandBlack" --include="*.swift" . | grep -v "//"
echo ""

echo "---"
echo "Searching for: cardBackground"
grep -rn "static.*cardBackground" --include="*.swift" . | grep -v "//"
echo ""

echo "---"
echo "Searching for: cardBorder"
grep -rn "static.*cardBorder" --include="*.swift" . | grep -v "//"
echo ""

echo "---"
echo "Searching for: neonGold"
grep -rn "static.*neonGold" --include="*.swift" . | grep -v "//"
echo ""

echo "---"
echo "Searching for: neonCyan"
grep -rn "static.*neonCyan" --include="*.swift" . | grep -v "//"
echo ""

# Find files with "copy", "2", "3", etc in names
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📄 FILES WITH DUPLICATE NAMES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Files containing 'copy' in name:"
find . -name "*copy*.swift" -type f
echo ""

echo "Files containing numbers (2, 3, 4, 5) in name:"
find . -name "*[2-5].swift" -type f
echo ""

echo "Files containing 'old' or 'backup' in name:"
find . -name "*old*.swift" -o -name "*backup*.swift" -type f
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Search complete!"
echo ""
echo "💡 To delete a file:"
echo "   rm \"path/to/file.swift\""
echo ""
echo "💡 To see detailed file info:"
echo "   ls -la \"path/to/file.swift\""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
