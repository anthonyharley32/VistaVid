import SwiftUI
import AVFoundation

struct RecordingView: View {
    // MARK: - Properties
    @StateObject private var cameraManager = CameraManager()
    @ObservedObject var videoViewModel: VideoViewModel
    @State private var showingDescriptionSheet = false
    @State private var description = ""
    @State private var selectedAlgorithmTags: [String] = []
    @State private var isUploading = false
    @State private var uploadError: Error?
    @State private var moderationState: VideoModerationState = .none
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    @State private var selectedCommunityId = ""
    @StateObject private var communityModel = CommunityViewModel()
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview
                if let previewLayer = cameraManager.previewLayer {
                    CameraPreviewView(previewLayer: previewLayer)
                        .onAppear {
                            print("🎥 [RecordingView]: CameraPreviewView appeared")
                            previewLayer.frame = geometry.frame(in: .global)
                        }
                } else {
                    Color.black
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
                
                // Close button
                VStack {
                    GeometryReader { geo in
                        HStack(spacing: 20) {
                            Button(action: {
                                print("🎥 [RecordingView]: Close button tapped")
                                // First dismiss the view
                                dismiss()
                                // Then cleanup camera
                                Task { @MainActor in
                                    print("🎥 [RecordingView]: Starting camera cleanup after dismiss")
                                    await cameraManager.cleanupCamera()
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44) // Larger touch target
                            }
                        }
                        .position(x: 50, y: 60) // Adjusted position for single button
                    }
                    Spacer()
                    
                    // Recording controls
                    VStack(spacing: 20) {
                        if cameraManager.isRecording {
                            Text(cameraManager.recordingTimeString)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        // Camera controls row
                        HStack(spacing: 40) {
                            // Switch camera button
                            Button(action: {
                                print("🎥 [RecordingView]: Switch camera button tapped")
                                cameraManager.flipCamera()
                            }) {
                                Image(systemName: "camera.rotate")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                            }
                            
                            // Record button
                            Button(action: {
                                if cameraManager.isRecording {
                                    Task {
                                        cameraManager.stopRecording()
                                        showingDescriptionSheet = true
                                    }
                                } else {
                                    cameraManager.startRecording()
                                }
                            }) {
                                Circle()
                                    .fill(cameraManager.isRecording ? Color.red : Color.white)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 4)
                                            .frame(width: 70, height: 70)
                                    )
                            }
                            
                            // Empty spacer view to balance the layout
                            Color.clear
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .ignoresSafeArea()
        .statusBar(hidden: true) // Hide status bar
        .task {
            print("🎥 [RecordingView]: View appeared, initializing camera")
            await MainActor.run {
                cameraManager.checkPermissions()
                cameraManager.setupCamera()
            }
        }
        .onChange(of: scenePhase, { _, newPhase in
            if newPhase == .active {
                print("🎥 [RecordingView]: Scene became active")
                Task { @MainActor in
                    cameraManager.checkPermissions()
                    cameraManager.setupCamera()
                }
            } else if newPhase == .background {
                print("🎥 [RecordingView]: Scene went to background")
                Task { @MainActor in
                    await cameraManager.cleanupCamera()
                }
            }
        })
        .sheet(isPresented: $showingDescriptionSheet) {
            NavigationView {
                VStack(spacing: 20) {
                    // Description field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("What's happening in your video?", text: $description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }
                    .padding(.horizontal)
                    
                    // Community Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Community (Optional)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if communityModel.isLoading {
                            ProgressView()
                        } else {
                            Picker("Select Community", selection: $selectedCommunityId) {
                                Text("None").tag("")
                                ForEach(communityModel.communities) { community in
                                    Text(community.name).tag(community.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .padding(.horizontal)
                    .task {
                        await communityModel.fetchCommunities()
                    }
                    
                    // Upload button
                    Button(action: {
                        Task {
                            guard let videoURL = cameraManager.lastRecordedVideoURL else {
                                print("❌ [RecordingView]: No video URL available")
                                return
                            }
                            
                            isUploading = true
                            moderationState = .uploading
                            defer { isUploading = false }
                            
                            do {
                                print("📤 [RecordingView]: Starting video upload")
                                let videoId = try await videoViewModel.uploadVideo(
                                    videoURL: videoURL,
                                    description: description,
                                    algorithmTags: selectedAlgorithmTags,
                                    communityId: selectedCommunityId
                                )
                                
                                // Start monitoring moderation status
                                moderationState = .moderating
                                print("🎯 [RecordingView]: Monitoring video ID: \(videoId)")
                                
                                // Add initial delay to allow Firebase Functions to start processing
                                print("⏳ [RecordingView]: Waiting for initial processing delay...")
                                try await Task.sleep(nanoseconds: 5_000_000_000) // Wait 5 seconds
                                
                                // Poll for moderation status
                                for attempt in 0..<45 { // Poll for up to 90 seconds
                                    do {
                                        print("🔄 [RecordingView]: Status check attempt \(attempt + 1)")
                                        let videoDoc = try await videoViewModel.getVideoStatus(videoId)
                                        print("📊 [RecordingView]: Current status: \(videoDoc.status)")
                                        
                                        switch videoDoc.status {
                                            case "blocked":
                                                print("🚫 [RecordingView]: Video blocked")
                                                moderationState = .blocked
                                                return
                                            case "moderation_failed":
                                                print("❌ [RecordingView]: Moderation failed")
                                                moderationState = .failed
                                                return
                                            case "moderation_passed", "processed":
                                                print("✅ [RecordingView]: Video processed successfully")
                                                moderationState = .passed
                                                showingDescriptionSheet = false
                                                description = ""
                                                dismiss()
                                                return
                                            default:
                                                print("⏳ [RecordingView]: Status still processing: \(videoDoc.status)")
                                                try await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
                                                continue
                                        }
                                    } catch let error as NSError where error.domain == "VideoStatus" && error.code == 404 {
                                        // Video not found yet, wait and retry
                                        print("⏳ [RecordingView]: Video document not ready (attempt \(attempt + 1))")
                                        try await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
                                        continue
                                    } catch {
                                        print("❌ [RecordingView]: Error checking status: \(error.localizedDescription)")
                                        throw error
                                    }
                                }
                                
                                // If we get here, polling timed out
                                print("⚠️ [RecordingView]: Status check timed out after 90 seconds")
                                moderationState = .failed
                                
                            } catch {
                                print("❌ [RecordingView]: Upload failed - \(error.localizedDescription)")
                                uploadError = error
                                moderationState = .failed
                            }
                        }
                    }) {
                        HStack {
                            if isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(width: 20, height: 20)
                            } else {
                                Text(moderationState == .none ? "Post" : moderationState.message)
                                    .fontWeight(.semibold)
                                if moderationState == .none {
                                    Image(systemName: "arrow.up.circle.fill")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            moderationState == .blocked ? Color.red :
                            moderationState == .failed ? Color.orange :
                            moderationState == .passed ? Color.green :
                            description.isEmpty ? Color.gray.opacity(0.3) : Color.blue
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(description.isEmpty || isUploading || moderationState == .blocked)
                    .alert(
                        "Content Moderation",
                        isPresented: .constant(moderationState == .blocked),
                        actions: {
                            Button("OK", role: .cancel) {
                                moderationState = .none
                                showingDescriptionSheet = false
                            }
                        },
                        message: {
                            Text("Your video contains content that violates our community guidelines. Please review our guidelines and try again.")
                        }
                    )
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top)
                .navigationTitle("New Video")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingDescriptionSheet = false
                            description = ""
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> UIView {
        print("🎥 [Preview]: Creating UIView for camera preview")
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        print("🎥 [Preview]: View frame: \(view.frame)")
        
        previewLayer.frame = view.frame
        print("🎥 [Preview]: Layer frame: \(previewLayer.frame)")
        
        previewLayer.videoGravity = .resizeAspectFill
        print("🎥 [Preview]: Adding preview layer to view")
        view.layer.addSublayer(previewLayer)
        
        // Debug the layer hierarchy
        print("🎥 [Preview]: View layer hierarchy:")
        print("🎥 [Preview]: - Main layer: \(view.layer)")
        print("🎥 [Preview]: - Sublayers: \(String(describing: view.layer.sublayers))")
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        print("🎥 [Preview]: Updating UIView bounds: \(uiView.bounds)")
        previewLayer.frame = uiView.bounds
    }
}

// MARK: - Camera Manager
@MainActor
final class CameraManager: NSObject, ObservableObject {
    // MARK: - Properties
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var isRecording = false
    @Published var recordingTimeString = "00:00"
    @Published var lastRecordedVideoURL: URL?
    
    // Internal for view access
    var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var frontCamera: AVCaptureDevice?
    private var backCamera: AVCaptureDevice?
    private var currentCamera: AVCaptureDevice?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private let sessionQueue = DispatchQueue(label: "com.vistavid.camera.session")
    
    override init() {
        super.init()
        print("🎥 [CameraManager]: Initializing")
    }
    
    deinit {
        print("🎥 [CameraManager]: Deinitializing")
        // Using Task.detached to avoid capturing self in closure
        Task.detached { [captureSession] in
            captureSession?.stopRunning()
        }
    }
    
    // MARK: - Cleanup Methods
    
    /// Public method to cleanup camera resources
    public func cleanupCamera() async {
        print("🎥 [CameraManager]: Starting cleanup")
        
        // Stop recording if active
        if isRecording {
            print("🎥 [CameraManager]: Stopping active recording")
            stopRecording()
        }
        
        // Stop session on background queue
        await Task.detached { [weak captureSession] in
            print("🎥 [CameraManager]: Stopping capture session")
            captureSession?.stopRunning()
        }.value
        
        // Cleanup on main actor
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            print("🎥 [CameraManager]: Cleaning up resources on main actor")
            
            // Cleanup timer
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            
            // Clear references
            self.previewLayer?.removeFromSuperlayer()
            self.previewLayer = nil
            self.videoOutput = nil
            self.frontCamera = nil
            self.backCamera = nil
            self.currentCamera = nil
            self.captureSession = nil
            
            print("🎥 [CameraManager]: Cleanup complete")
        }
    }
    
    // MARK: - Setup Methods
    
    func checkPermissions() {
        print("🎥 [CameraManager]: Checking camera permissions")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            print("🎥 [CameraManager]: Requesting camera access")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    print("🎥 [CameraManager]: Camera access granted")
                    Task { @MainActor in
                        self?.setupCamera()
                    }
                } else {
                    print("❌ [CameraManager]: Camera access denied")
                }
            }
        case .restricted:
            print("❌ [CameraManager]: Camera access restricted")
        case .denied:
            print("❌ [CameraManager]: Camera access denied")
        case .authorized:
            print("🎥 [CameraManager]: Camera access already authorized")
            setupCamera()
        @unknown default:
            break
        }
        
        // Also check audio permissions
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            print("🎥 [CameraManager]: Requesting microphone access")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print(granted ? "🎥 [CameraManager]: Microphone access granted" : "❌ [CameraManager]: Microphone access denied")
            }
        default:
            break
        }
    }
    
    func setupCamera() {
        print("🎥 [CameraManager]: Starting camera setup")
        
        // Check if we already have a running session
        if let existingSession = captureSession {
            if existingSession.isRunning {
                print("🎥 [CameraManager]: Camera session already running")
                return
            } else {
                print("🎥 [CameraManager]: Restarting existing session")
                existingSession.startRunning()
                return
            }
        }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        print("🎥 [CameraManager]: Session configuration started")
        
        // Configure session for high quality video
        session.sessionPreset = .high
        print("🎥 [CameraManager]: Set session preset to high quality")
        
        // Find cameras
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            backCamera = device
            currentCamera = device
            print("🎥 [CameraManager]: Found back camera: \(device.localizedName)")
        }
        
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            frontCamera = device
            print("🎥 [CameraManager]: Found front camera: \(device.localizedName)")
        }
        
        // Setup video input
        do {
            if let currentCamera = currentCamera {
                let videoInput = try AVCaptureDeviceInput(device: currentCamera)
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                    print("🎥 [CameraManager]: Added video input from camera: \(currentCamera.localizedName)")
                } else {
                    print("❌ [CameraManager]: Could not add video input to session")
                }
            }
            
            // Setup audio input
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
               session.canAddInput(audioInput) {
                session.addInput(audioInput)
                print("🎥 [CameraManager]: Added audio input")
            }
            
            // Setup video output
            let output = AVCaptureMovieFileOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                videoOutput = output
                print("🎥 [CameraManager]: Added video output")
            }
            
            // Create and setup preview layer
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            self.previewLayer = previewLayer
            print("🎥 [CameraManager]: Created preview layer")
            
            // Commit configuration
            session.commitConfiguration()
            print("🎥 [CameraManager]: Committed session configuration")
            
            // Start running
            captureSession = session
            
            // Start the session on a background thread
            Task.detached {
                print("🎥 [CameraManager]: Starting capture session")
                session.startRunning()
                print("🎥 [CameraManager]: Capture session is running: \(session.isRunning)")
            }
            
        } catch {
            print("❌ [CameraManager]: Error setting up camera: \(error.localizedDescription)")
            print("❌ [CameraManager]: Detailed error: \(error)")
        }
    }
    
    // MARK: - Recording Methods
    
    func startRecording() {
        guard let output = videoOutput,
              !output.isRecording else { return }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(UUID().uuidString).mov"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        output.startRecording(to: fileURL, recordingDelegate: self)
        isRecording = true
        recordingStartTime = Date()
        
        // Start timer for recording duration
        Task { @MainActor in
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateRecordingTime()
                }
            }
        }
    }
    
    func stopRecording() {
        guard let output = videoOutput,
              output.isRecording else { return }
        
        output.stopRecording()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    func flipCamera() {
        guard let session = captureSession,
              let currentInput = session.inputs.first as? AVCaptureDeviceInput else { return }
        
        // Get new camera
        let newCamera = currentInput.device.position == .back ? frontCamera : backCamera
        
        // Remove current input
        session.beginConfiguration()
        session.removeInput(currentInput)
        
        // Add new input
        if let newCamera = newCamera,
           let newInput = try? AVCaptureDeviceInput(device: newCamera),
           session.canAddInput(newInput) {
            session.addInput(newInput)
            currentCamera = newCamera
        }
        
        session.commitConfiguration()
    }
    
    private func updateRecordingTime() {
        guard let startTime = recordingStartTime else { return }
        let duration = Int(Date().timeIntervalSince(startTime))
        let minutes = duration / 60
        let seconds = duration % 60
        recordingTimeString = String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error recording video: \(error)")
            return
        }
        
        Task { @MainActor in
            self.lastRecordedVideoURL = outputFileURL
        }
    }
    
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // Recording started successfully
        print("Started recording to: \(fileURL)")
    }
}

// MARK: - Algorithm Tags Selection View
struct AlgorithmTagsSelectionView: View {
    @Binding var selectedTags: [String]
    
    // Sample algorithm tags (in a real app, these would come from your backend)
    let availableTags = ["AI", "Fitness", "Makeup", "Tech", "Food", "Travel", "Music", "Dance"]
    
    var body: some View {
        List {
            ForEach(availableTags, id: \.self) { tag in
                Button(action: {
                    if selectedTags.contains(tag) {
                        selectedTags.removeAll { $0 == tag }
                    } else {
                        selectedTags.append(tag)
                    }
                }) {
                    HStack {
                        Text(tag)
                        Spacer()
                        if selectedTags.contains(tag) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Tags")
    }
}

extension RecordingView {
    // Hide status bar
    var prefersStatusBarHidden: Bool {
        return true
    }
}

#Preview {
    RecordingView(videoViewModel: VideoViewModel())
}

// Add this enum after the RecordingView struct
enum VideoModerationState {
    case none
    case uploading
    case moderating
    case blocked
    case failed
    case passed
    
    var message: String {
        switch self {
            case .none: return ""
            case .uploading: return "Uploading video..."
            case .moderating: return "Checking content..."
            case .blocked: return "Content violates community guidelines"
            case .failed: return "Content check failed, please try again"
            case .passed: return "Content check passed!"
        }
    }
}