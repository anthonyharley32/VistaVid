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
    private var lastBlinkTime: Date?
    private var blinkCount = 0
    private let blinkResetInterval: TimeInterval = 1.0
    
    // Callback for navigation
    var onSingleBlink: (() -> Void)?
    var onDoubleBlink: (() -> Void)?
    
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
            captureSession.sessionPreset = .low
        } catch {
            print("❌ Error setting up camera: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Control
    func startDetection() {
        guard !isRunning else { return }
        
        setupCamera()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
            DispatchQueue.main.async {
                self?.isRunning = true
            }
        }
    }
    
    func stopDetection() {
        guard isRunning else { return }
        
        captureSession?.stopRunning()
        isRunning = false
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
        let averageEAR = (leftEAR + rightEAR) / 2.0
        
        // Detect blink
        let blinkThreshold: Float = 0.2
        if averageEAR < blinkThreshold {
            handleBlink()
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
    
    private func handleBlink() {
        let now = Date()
        
        if let lastBlink = lastBlinkTime {
            let timeSinceLastBlink = now.timeIntervalSince(lastBlink)
            
            if timeSinceLastBlink < blinkResetInterval {
                blinkCount += 1
                
                if blinkCount == 2 {
                    DispatchQueue.main.async { [weak self] in
                        self?.onDoubleBlink?()
                    }
                    blinkCount = 0
                }
            } else {
                blinkCount = 1
                DispatchQueue.main.async { [weak self] in
                    self?.onSingleBlink?()
                }
            }
        } else {
            blinkCount = 1
            DispatchQueue.main.async { [weak self] in
                self?.onSingleBlink?()
            }
        }
        
        lastBlinkTime = now
    }
} 