import Foundation

@Observable class SettingsViewModel {
    // MARK: - Properties
    private let defaults = UserDefaults.standard
    private let handsFreeModeKey = "handsFreeMode"
    
    var isHandsFreeEnabled: Bool {
        get { 
            let enabled = defaults.bool(forKey: handsFreeModeKey)
            print("👁️ Hands-free mode is: \(enabled ? "ON" : "OFF")")
            return enabled 
        }
        set { 
            print("👁️ Setting hands-free mode to: \(newValue ? "ON" : "OFF")")
            defaults.set(newValue, forKey: handsFreeModeKey)
            
            // Ensure we're on the main thread for UI updates
            DispatchQueue.main.async {
                if newValue {
                    print("👁️ Starting blink detection")
                    self.blinkManager.startDetection()
                } else {
                    print("👁️ Stopping blink detection")
                    self.blinkManager.stopDetection()
                    // Reset any ongoing gesture processing
                    self.blinkManager.isRunning = false
                }
            }
        }
    }
    
    // MARK: - Blink Detection
    let blinkManager = BlinkDetectionManager()
    
    init() {
        // Setup gesture detection callbacks
        blinkManager.onLeftWink = {
            print("👁️ Left wink detected - Going to previous video")
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToPreviousVideo"),
                object: nil,
                userInfo: ["direction": "up"]
            )
        }
        
        blinkManager.onRightWink = {
            print("👁️ Right wink detected - Going to next video")
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToNextVideo"),
                object: nil,
                userInfo: ["direction": "down"]
            )
        }
        
        blinkManager.onBothEyesBlink = {
            print("👁️ Both eyes blink detected - Toggling play/pause")
            NotificationCenter.default.post(
                name: NSNotification.Name("TogglePlayback"),
                object: nil,
                userInfo: nil
            )
        }
        
        // Start detection if enabled, but only if not already running
        if isHandsFreeEnabled && !blinkManager.isRunning {
            print("👁️ Initializing blink detection on startup")
            blinkManager.startDetection()
        }
    }
} 