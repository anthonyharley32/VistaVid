import SwiftUI

struct VisibilityModifier: ViewModifier {
    let index: Int
    @Binding var currentVisibleIndex: Int?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                print("📱 [Visibility]: View \(index) APPEARED")
                currentVisibleIndex = index
            }
            .onDisappear {
                print("📱 [Visibility]: View \(index) DISAPPEARED")
                if currentVisibleIndex == index {
                    currentVisibleIndex = nil
                }
            }
            .onChange(of: currentVisibleIndex) { oldValue, newValue in
                print("📱 [Visibility]: Visibility changed for \(index) - Old: \(String(describing: oldValue)), New: \(String(describing: newValue))")
            }
    }
} 