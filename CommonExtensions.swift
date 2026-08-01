import SwiftUI
import UIKit

// MARK: - Haptic Feedback Extensions

extension View {
    /// Provides light haptic feedback
    func lightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// Provides medium haptic feedback
    func mediumHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// Provides heavy haptic feedback
    func heavyHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    /// Provides swipe feedback (light haptic)
    func swipeFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Array Safe Subscript

extension Array {
    /// Safe subscript that returns nil if index is out of bounds
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    /// Downsamples the image to a target size
    func downsampled(to targetSize: CGSize) async -> UIImage {
        let scale = max(targetSize.width / size.width, targetSize.height / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        return await Task.detached(priority: .userInitiated) {
            UIGraphicsBeginImageContextWithOptions(newSize, true, 1)
            defer { UIGraphicsEndImageContext() }
            self.draw(in: CGRect(origin: .zero, size: newSize))
            return UIGraphicsGetImageFromCurrentImageContext() ?? self
        }.value
    }
}

// MARK: - Date Extensions

extension Date {
    /// Returns true if this date is in the same day as the given date
    func isSameDay(as other: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(self, inSameDayAs: other)
    }
    
    /// Returns the start of the day for this date
    func startOfDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }
}
