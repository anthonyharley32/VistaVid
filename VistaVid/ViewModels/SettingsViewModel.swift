import Foundation

@Observable class SettingsViewModel {
    // MARK: - Properties
    private let defaults = UserDefaults.standard
    private let handsFreeModeKey = "handsFreeMode"
    
    var isHandsFreeEnabled: Bool {
        get { defaults.bool(forKey: handsFreeModeKey) }
        set { 
            defaults.set(newValue, forKey: handsFreeModeKey)
            if newValue {
                blinkManager.startDetection()
            } else {
                blinkManager.stopDetection()
            }
        }
    }
    
    // MARK: - Blink Detection
    let blinkManager = BlinkDetectionManager()
    
    init() {
        // Setup blink detection callbacks
        blinkManager.onSingleBlink = {
            print("👁️ Single blink detected - Navigating to next video")
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToNextVideo"), object: nil)
        }
        
        blinkManager.onDoubleBlink = {
            print("👁️ Double blink detected - Navigating to previous video")
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToPreviousVideo"), object: nil)
        }
        
        // Start detection if enabled
        if isHandsFreeEnabled {
            blinkManager.startDetection()
        }
    }
} 