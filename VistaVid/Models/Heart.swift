import SwiftUI

public struct Heart: Identifiable {
    public let id = UUID()
    public let position: CGPoint
    public let rotation: Double
    
    public init(position: CGPoint, rotation: Double) {
        self.position = position
        self.rotation = rotation
    }
} 