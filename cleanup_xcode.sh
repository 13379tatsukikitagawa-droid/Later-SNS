#!/bin/bash

# 🧹 Xcode Build Cleanup Script
# This script cleans all Xcode build artifacts and derived data

echo "🧹 Starting Xcode cleanup..."
echo ""

# Close Xcode first (optional - comment out if you want to close manually)
# echo "⚠️  Closing Xcode..."
# osascript -e 'quit app "Xcode"'
# sleep 2

# Clean DerivedData
echo "🗑️  Removing DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData
echo "✅ DerivedData removed"
echo ""

# Clean ModuleCache
echo "🗑️  Removing Module Cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex
echo "✅ Module Cache removed"
echo ""

# Clean Archives (optional - commented out by default)
# echo "🗑️  Removing Archives..."
# rm -rf ~/Library/Developer/Xcode/Archives
# echo "✅ Archives removed"
# echo ""

# Clean iOS DeviceSupport (optional - commented out by default)
# This can free up a LOT of space but you'll need to re-download device support
# echo "🗑️  Removing iOS DeviceSupport..."
# rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport
# echo "✅ iOS DeviceSupport removed"
# echo ""

echo "✨ Cleanup complete!"
echo ""
echo "📝 Next steps:"
echo "1. Reopen Xcode"
echo "2. Press Cmd+Shift+K to Clean Build Folder"
echo "3. Press Cmd+B to Build"
echo ""
echo "If errors persist:"
echo "• Check for duplicate file definitions"
echo "• Delete files with '2' suffix (e.g., 'VotingManager 2.swift')"
echo "• Ensure extensions are defined only once"
echo ""
