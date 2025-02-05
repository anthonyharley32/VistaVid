import SwiftUI
import AVFoundation

struct RecordingView: View {
    // MARK: - Properties
    @StateObject private var cameraManager = CameraManager()
    @Environment(\.dismiss) private var dismiss
    @State private var showingDescriptionSheet = false
    @State private var description = ""
    @State private var selectedAlgorithmTags: [String] = []
    
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
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .padding()
                        }
                        Spacer()
                    }
                    Spacer()
                    
                    // Recording controls
                    VStack(spacing: 20) {
                        if cameraManager.isRecording {
                            Text(cameraManager.recordingTimeString)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        HStack(spacing: 50) {
                            // Flip camera button
                            Button(action: { cameraManager.flipCamera() }) {
                                Image(systemName: "camera.rotate.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                            }
                            
                            // Record button
                            Button(action: {
                                if cameraManager.isRecording {
                                    cameraManager.stopRecording()
                                    showingDescriptionSheet = true
                                } else {
                                    cameraManager.startRecording()
                                }
                            }) {
                                Circle()
                                    .fill(cameraManager.isRecording ? .red : .white)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 4)
                                            .frame(width: 70, height: 70)
                                    )
                            }
                            
                            // Settings button (placeholder for future features)
                            Button(action: { /* TODO: Add settings */ }) {
                                Image(systemName: "gear")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showingDescriptionSheet) {
            NavigationView {
                Form {
                    Section(header: Text("Video Details")) {
                        TextField("Add a description...", text: $description)
                        
                        NavigationLink {
                            AlgorithmTagsSelectionView(selectedTags: $selectedAlgorithmTags)
                        } label: {
                            HStack {
                                Text("Algorithm Tags")
                                Spacer()
                                Text("\(selectedAlgorithmTags.count) selected")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Section {
                        Button("Upload Video") {
                            Task {
                                if let videoURL = cameraManager.lastRecordedVideoURL {
                                    do {
                                        try await VideoViewModel().uploadVideo(
                                            videoURL: videoURL,
                                            description: description,
                                            algorithmTags: selectedAlgorithmTags
                                        )
                                        showingDescriptionSheet = false
                                        description = ""
                                        selectedAlgorithmTags = []
                                        dismiss() // Dismiss the camera view after successful upload
                                    } catch {
                                        print("Error uploading video: \(error)")
                                        // TODO: Show error alert
                                    }
                                }
                            }
                        }
                        .disabled(description.isEmpty)
                    }
                }
                .navigationTitle("New Video")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingDescriptionSheet = false
                            description = ""
                            selectedAlgorithmTags = []
                        }
                    }
                }
            }
        }
        .task {
            print("🎥 [RecordingView]: View appeared, initializing camera")
            await MainActor.run {
                cameraManager.checkPermissions()
                cameraManager.setupCamera()
            }
        }
        .onDisappear {
            print("🎥 [RecordingView]: View disappeared, cleaning up")
            if let session = cameraManager.captureSession {
                session.stopRunning()
            }
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
    
    override init() {
        super.init()
        print("🎥 [CameraManager]: Initializing")
    }
    
    deinit {
        print("🎥 [CameraManager]: Deinitializing")
        Task { @MainActor in
            await cleanup()
        }
    }
    
    private func cleanup() async {
        print("🎥 [CameraManager]: Cleaning up resources")
        recordingTimer?.invalidate()
        recordingTimer = nil
        if isRecording {
            stopRecording()
        }
        captureSession?.stopRunning()
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

#Preview {
    RecordingView()
} 