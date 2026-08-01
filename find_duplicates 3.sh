#!/bin/bash

# Quick Search Script for Duplicate Definitions
# This script helps you find duplicate definitions that need to be removed

echo "🔍 Searching for duplicate definitions..."
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  Searching for Color(hex:) initializer..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
grep -rn "init(hex:" --include="*.swift" . | grep -v "ColorExtensions.swift" | grep -v ".build"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  Searching for brandBlack definitions..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
grep -rn "static.*brandBlack" --include="*.swift" . | grep -v "ColorExtensions.swift" | grep -v ".build"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣  Searching for brandDarkGray definitions..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
grep -rn "static.*brandDarkGray" --include="*.swift" . | grep -v "ColorExtensions.swift" | grep -v ".build"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4️⃣  Searching for brandGreen definitions..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
grep -rn "static.*brandGreen" --include="*.swift" . | grep -v "ColorExtensions.swift" | grep -v ".build"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5️⃣  Searching for swipeFeedback() definitions..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
grep -rn "func swipeFeedback" --include="*.swift" . | grep -v "CommonExtensions.swift" | grep -v ".build"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6️⃣  Searching for Array safe subscript..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
grep -rn "subscript(safe" --include="*.swift" . | grep -v "CommonExtensions.swift" | grep -v ".build"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7️⃣  Searching for CalendarArchiveView duplicates..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
grep -rn "struct CalendarArchiveView" --include="*.swift" .
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Search complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Next steps:"
echo "1. Review each file listed above"
echo "2. Delete duplicate definitions (keep only in ColorExtensions.swift or CommonExtensions.swift)"
echo "3. Run: rm -rf ~/Library/Developer/Xcode/DerivedData"
echo "4. Clean Build in Xcode (Cmd+Shift+K)"
echo "5. Build (Cmd+B)"
