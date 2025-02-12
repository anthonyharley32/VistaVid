import SwiftUI

public struct ScrollBehaviorManager {
    public static let snapThreshold: CGFloat = 0.15
    public static let velocityThreshold: CGFloat = 100
    
    public static func shouldMove(offset: CGFloat, velocity: CGFloat, screenHeight: CGFloat) -> Bool {
        let offsetPercentage = offset / screenHeight
        return abs(offsetPercentage) > snapThreshold || abs(velocity) > velocityThreshold
    }
    
    public static func calculateNewIndex(currentIndex: Int, maxIndex: Int, dragOffset: CGFloat) -> Int {
        let direction = dragOffset > 0 ? -1 : 1
        return max(0, min(maxIndex, currentIndex + direction))
    }
} 