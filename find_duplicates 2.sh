#!/bin/bash

# Ambiguous Symbol Cleanup Script
# This script helps identify duplicate symbol definitions in your Swift project

echo "🔍 Searching for duplicate symbol definitions..."
echo ""

# Color hex initializer
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  Color.init(hex:) definitions found in:"
grep -r "init(hex: String)" --include="*.swift" . | grep -v "ColorExtensions.swift" | cut -d: -f1 | sort -u
echo ""

# Brand colors
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  brandBlack definitions found in:"
grep -r "brandBlack" --include="*.swift" . | grep -E "(static let|static var)" | grep -v "ColorExtensions.swift" | cut -d: -f1 | sort -u
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣  brandDarkGray definitions found in:"
grep -r "brandDarkGray" --include="*.swift" . | grep -E "(static let|static var)" | grep -v "ColorExtensions.swift" | cut -d: -f1 | sort -u
echo ""

# Haptic feedback
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4️⃣  swipeFeedback() definitions found in:"
grep -r "func swipeFeedback" --include="*.swift" . | grep -v "CommonExtensions.swift" | cut -d: -f1 | sort -u
echo ""

# Safe subscript
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5️⃣  Array safe subscript definitions found in:"
grep -r "subscript(safe index:" --include="*.swift" . | grep -v "CommonExtensions.swift" | cut -d: -f1 | sort -u
echo ""

# UIImage downsampling
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6️⃣  UIImage.downsampled definitions found in:"
grep -r "func downsampled" --include="*.swift" . | grep -v "CommonExtensions.swift" | cut -d: -f1 | sort -u
echo ""

# Duplicate struct/class definitions
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7️⃣  CalendarArchiveView definitions found in:"
grep -r "struct CalendarArchiveView" --include="*.swift" . | cut -d: -f1 | sort -u
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Search complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Review the files listed above"
echo "   2. Remove duplicate definitions (keep only ColorExtensions.swift and CommonExtensions.swift)"
echo "   3. For CalendarArchiveView, keep only ONE struct definition"
echo "   4. Read AMBIGUITY_FIX_GUIDE.md for detailed instructions"
echo ""
