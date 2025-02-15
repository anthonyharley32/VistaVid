import Vision
import AVFoundation
import Combine

@Observable class BlinkDetectionManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK: - Properties
    private var captureSession: AVCaptureSession?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var faceDetectionRequest: VNDetectFaceRectanglesRequest?
    private var faceLandmarksRequest: VNDetectFaceLandmarksRequest?
    
    var isRunning = false
    private var lastGestureTime: Date?
    private let gestureResetInterval: TimeInterval = 0.8
    private var isProcessingGesture = false
    private var leftEyeWasOpen = true
    private var rightEyeWasOpen = true
    
    // Callback for navigation
    var onLeftWink: (() -> Void)?
    var onRightWink: (() -> Void)?
    var onBothEyesBlink: (() -> Void)?
    
    override init() {
        super.init()
        setupVision()
    }
    
    // MARK: - Setup
    private func setupVision() {
        // Setup face detection request
        faceDetectionRequest = VNDetectFaceRectanglesRequest()
        
        // Setup facial landmarks request
        faceLandmarksRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard error == nil else {
                print("❌ Face landmarks detection error: \(error!.localizedDescription)")
                return
            }
            
            self?.handleFaceLandmarks(request)
        }
    }
    
    // MARK: - Camera Setup
    func setupCamera() {
        print("👁️ Starting camera setup")
        
        // Prevent multiple camera setups
        guard captureSession == nil else {
            print("👁️ Camera already setup, skipping initialization")
            return
        }
        
        captureSession = AVCaptureSession()
        videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
        videoDataOutput = AVCaptureVideoDataOutput()
        
        guard let captureSession = captureSession,
              let videoDataOutput = videoDataOutput,
              let videoDataOutputQueue = videoDataOutputQueue else { return }
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("❌ Unable to access front camera")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            if captureSession.canAddOutput(videoDataOutput) {
                captureSession.addOutput(videoDataOutput)
            }
            
            // Improve efficiency by reducing resolution
            captureSession.sessionPreset = .medium
        } catch {
            print("❌ Error setting up camera: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Control
    func startDetection() {
        guard !isRunning else { 
            print("👁️ Detection already running, skipping start")
            return 
        }
        
        // If we have an existing session that's not running, just restart it
        if let existingSession = captureSession {
            print("👁️ Restarting existing camera session")
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                existingSession.startRunning()
                DispatchQueue.main.async {
                    self?.isRunning = true
                    print("👁️ Detection is now running")
                }
            }
            return
        }
        
        print("👁️ Setting up new camera for detection")
        setupCamera()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            print("👁️ Starting camera session")
            self?.captureSession?.startRunning()
            DispatchQueue.main.async {
                self?.isRunning = true
                print("👁️ Detection is now running")
            }
        }
    }
    
    func stopDetection() {
        guard isRunning else { 
            print("👁️ Detection already stopped, skipping stop")
            return 
        }
        
        print("👁️ Stopping camera session")
        cleanup()
        print("👁️ Detection is now stopped")
    }
    
    private func cleanup() {
        // Stop the capture session
        captureSession?.stopRunning()
        
        // Remove the video data output delegate
        videoDataOutput?.setSampleBufferDelegate(nil, queue: nil)
        
        // Remove inputs and outputs
        captureSession?.inputs.forEach { captureSession?.removeInput($0) }
        captureSession?.outputs.forEach { captureSession?.removeOutput($0) }
        
        // Clear capture session and related properties
        captureSession = nil
        videoDataOutput = nil
        videoDataOutputQueue = nil
        previewLayer = nil
        
        // Reset state
        isRunning = false
        lastGestureTime = nil
        isProcessingGesture = false
        leftEyeWasOpen = true
        rightEyeWasOpen = true
        
        // Clean up gesture callbacks
        onLeftWink = nil
        onRightWink = nil
        onBothEyesBlink = nil
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored)
        
        do {
            try imageRequestHandler.perform([faceLandmarksRequest].compactMap { $0 })
        } catch {
            print("❌ Failed to perform face detection: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Blink Detection
    private func handleFaceLandmarks(_ request: VNRequest) {
        guard let observations = request.results as? [VNFaceObservation] else { return }
        
        // Process only the first face
        guard let face = observations.first,
              let landmarks = face.landmarks,
              let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye else { return }
        
        // Calculate eye aspect ratio (EAR)
        let leftEAR = calculateEyeAspectRatio(eye: leftEye)
        let rightEAR = calculateEyeAspectRatio(eye: rightEye)
        
        // Debug logging for eye ratios
        print("👁️ Left EAR: \(leftEAR), Right EAR: \(rightEAR)")
        
        // Constants for detection
        let blinkThreshold: Float = 0.045
        let winkThreshold: Float = 0.10
        let normalStateThreshold: Float = 0.20
        let eyeRatioDifferenceMax: Float = 0.85
        let blinkEyeDifferenceMax: Float = 0.02
        
        // Calculate ratios between eyes
        let leftToRightRatio = leftEAR / rightEAR
        let rightToLeftRatio = rightEAR / leftEAR
        
        // Track eye states
        let isLeftEyeOpen = leftEAR > normalStateThreshold
        let isRightEyeOpen = rightEAR > normalStateThreshold
        
        // Detect gestures with optimized parameters
        if leftEAR < blinkThreshold && rightEAR < blinkThreshold && 
           abs(leftEAR - rightEAR) < blinkEyeDifferenceMax &&
           (leftEyeWasOpen || rightEyeWasOpen) {
            // Both eyes blink detected
            print("👁️ Blink detected - L:\(leftEAR) R:\(rightEAR)")
            handleGesture(type: .bothEyes)
            leftEyeWasOpen = false
            rightEyeWasOpen = false
        } else if leftEAR < winkThreshold && rightEAR > winkThreshold && 
                  leftToRightRatio < eyeRatioDifferenceMax && leftEyeWasOpen {
            // Left wink detected
            print("👁️ Left wink detected - Ratio L/R: \(leftToRightRatio)")
            handleGesture(type: .leftWink)
            leftEyeWasOpen = false
        } else if rightEAR < winkThreshold && leftEAR > winkThreshold && 
                  rightToLeftRatio < eyeRatioDifferenceMax && rightEyeWasOpen {
            // Right wink detected
            print("👁️ Right wink detected - Ratio R/L: \(rightToLeftRatio)")
            handleGesture(type: .rightWink)
            rightEyeWasOpen = false
        }
        
        // Reset eye states when eyes are open again
        if isLeftEyeOpen {
            leftEyeWasOpen = true
        }
        if isRightEyeOpen {
            rightEyeWasOpen = true
        }
    }
    
    private enum GestureType {
        case leftWink
        case rightWink
        case bothEyes
    }
    
    private func handleGesture(type: GestureType) {
        let now = Date()
        
        guard !isProcessingGesture,
              lastGestureTime == nil || now.timeIntervalSince(lastGestureTime!) > gestureResetInterval else {
            return
        }
        
        isProcessingGesture = true
        lastGestureTime = now
        
        DispatchQueue.main.async { [weak self] in
            switch type {
            case .leftWink:
                print("👁️ Left wink detected - Going to previous video")
                self?.onLeftWink?()
            case .rightWink:
                print("👁️ Right wink detected - Going to next video")
                self?.onRightWink?()
            case .bothEyes:
                print("👁️ Both eyes blink detected - Toggling play/pause")
                self?.onBothEyesBlink?()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.isProcessingGesture = false
                print("👁️ Gesture processing completed")
            }
        }
    }
    
    private func calculateEyeAspectRatio(eye: VNFaceLandmarkRegion2D) -> Float {
        let points = eye.normalizedPoints
        guard points.count >= 6 else { return 1.0 }
        
        // Calculate vertical distances
        let v1 = distance(from: points[1], to: points[5])
        let v2 = distance(from: points[2], to: points[4])
        
        // Calculate horizontal distance
        let h = distance(from: points[0], to: points[3])
        
        // Calculate EAR
        return (v1 + v2) / (2.0 * h)
    }
    
    private func distance(from p1: CGPoint, to p2: CGPoint) -> Float {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return Float(sqrt(dx*dx + dy*dy))
    }
} 