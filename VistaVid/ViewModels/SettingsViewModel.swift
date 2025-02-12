import Foundation
import AVFoundation

@Observable class SettingsViewModel {
    // MARK: - Properties
    static let shared = SettingsViewModel()
    
    private let defaults = UserDefaults.standard
    private let handsFreeModeKey = "handsFreeMode"
    
    // Make init private to enforce singleton pattern
    private init() {
        // Delay setup to ensure proper initialization
        DispatchQueue.main.async {
            self.setupBlinkDetection()
        }
    }
    
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
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if newValue {
                    print("👁️ Starting blink detection")
                    // Check camera permissions before starting
                    self.checkCameraPermissions { granted in
                        if granted {
                            self.blinkManager.startDetection()
                        } else {
                            print("❌ Camera permissions not granted")
                            // Reset the toggle if permissions denied
                            self.defaults.set(false, forKey: self.handsFreeModeKey)
                        }
                    }
                } else {
                    print("👁️ Stopping blink detection")
                    self.blinkManager.stopDetection()
                }
            }
        }
    }
    
    // MARK: - Blink Detection
    let blinkManager = BlinkDetectionManager()
    
    private func checkCameraPermissions(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    private func setupBlinkDetection() {
        // Setup gesture detection callbacks with weak self references
        blinkManager.onLeftWink = { [weak self] in
            guard self != nil else { return }
            print("👁️ Left wink detected - Going to previous video")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateVideo"),
                    object: nil,
                    userInfo: ["direction": "previous"]
                )
            }
        }
        
        blinkManager.onRightWink = { [weak self] in
            guard self != nil else { return }
            print("👁️ Right wink detected - Going to next video")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateVideo"),
                    object: nil,
                    userInfo: ["direction": "next"]
                )
            }
        }
        
        blinkManager.onBothEyesBlink = { [weak self] in
            guard self != nil else { return }
            print("👁️ Both eyes blink detected - Toggling play/pause")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ToggleVideoPlayback"),
                    object: nil
                )
            }
        }
        
        // Start detection if enabled, but with proper permission checks
        if isHandsFreeEnabled {
            print("👁️ Initializing blink detection on startup with permission check")
            checkCameraPermissions { [weak self] granted in
                guard let self = self, granted else { 
                    print("❌ Camera permissions not granted or self is nil")
                    return 
                }
                
                // Add extra delay to ensure UI is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    print("👁️ Starting blink detection after delay")
                    self.blinkManager.startDetection()
                }
            }
        }
    }
} 