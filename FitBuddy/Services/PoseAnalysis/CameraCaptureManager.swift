import AVFoundation
import SwiftUI
import Combine

// MARK: - Native Camera Capture Manager
/// Manages AVFoundation camera permissions, capture session setup, front/back camera selection,
/// video sample buffer output, and clean lifecycle management for real-time pose tracking.
public final class CameraCaptureManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    public static let shared = CameraCaptureManager()
    
    @Published public var permissionStatus: AVAuthorizationStatus = .notDetermined
    @Published public var isSessionRunning: Bool = false
    @Published public var isCameraAvailable: Bool = true
    @Published public var isPreparing: Bool = false
    @Published public var errorMessage: String? = nil
    
    public let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.fitbuddy.camera.sessionQueue")
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    public var onFrameCaptured: ((CMSampleBuffer, CGImagePropertyOrientation) -> Void)?
    public private(set) var cameraPosition: AVCaptureDevice.Position = .front
    
    public override init() {
        super.init()
        self.permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    // MARK: - Permission & Initialization
    
    public func requestPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            self.permissionStatus = status
        }
        
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.permissionStatus = granted ? .authorized : .denied
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    // MARK: - Session Configuration
    
    public func startSession() {
        requestPermission { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                DispatchQueue.main.async {
                    self.errorMessage = "Camera permission is required for live AI workout form tracking."
                }
                return
            }
            
            self.sessionQueue.async {
                self.setupAndStartSession()
            }
        }
    }
    
    public func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            DispatchQueue.main.async {
                self.isSessionRunning = false
                self.isPreparing = false
            }
        }
    }
    
    private func setupAndStartSession() {
        guard !captureSession.isRunning else {
            DispatchQueue.main.async { self.isSessionRunning = true }
            return
        }
        
        DispatchQueue.main.async {
            self.isPreparing = true
            self.errorMessage = nil
        }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1280x720 // Optimal balance of resolution & thermal performance
        
        // Discover suitable camera (prefer front-facing camera for workout monitoring)
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition)
            ?? AVCaptureDevice.default(for: .video)
        
        guard let camera = device else {
            captureSession.commitConfiguration()
            DispatchQueue.main.async {
                self.isCameraAvailable = false
                self.isPreparing = false
                self.errorMessage = "No camera hardware detected (iOS Simulator or camera disabled)."
            }
            return
        }
        
        do {
            // Remove previous inputs
            if let existingInput = videoDeviceInput {
                captureSession.removeInput(existingInput)
            }
            
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                self.videoDeviceInput = input
            }
            
            // Configure Video Data Output
            if captureSession.outputs.isEmpty {
                videoDataOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ]
                videoDataOutput.alwaysDiscardsLateVideoFrames = true
                
                let videoQueue = DispatchQueue(label: "com.fitbuddy.camera.videoQueue", qos: .userInteractive)
                videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
                
                if captureSession.canAddOutput(videoDataOutput) {
                    captureSession.addOutput(videoDataOutput)
                }
            }
            
            // Set orientation and mirroring on output connection
            if let connection = videoDataOutput.connection(with: .video) {
                if #available(iOS 17.0, *) {
                    if connection.isVideoRotationAngleSupported(90) {
                        connection.videoRotationAngle = 90
                    }
                } else {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = (cameraPosition == .front)
                }
            }
            
            captureSession.commitConfiguration()
            captureSession.startRunning()
            
            DispatchQueue.main.async {
                self.isSessionRunning = self.captureSession.isRunning
                self.isCameraAvailable = true
                self.isPreparing = false
            }
        } catch {
            captureSession.commitConfiguration()
            DispatchQueue.main.async {
                self.errorMessage = "Failed to initialize camera: \(error.localizedDescription)"
                self.isPreparing = false
            }
        }
    }
    
    // MARK: - Sample Buffer Delegate
    
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Since connection.videoOrientation = .portrait is configured on the connection,
        // AVFoundation delivers pixel buffers that are physically in portrait (width < height, e.g. 1080x1920).
        // Passing .leftMirrored would instruct Vision to rotate this already-portrait image by 90° into landscape!
        // Therefore, when width < height, the buffer is upright portrait and the orientation for Vision is .up.
        // If width >= height (raw sensor landscape), we tell Vision how to rotate it into upright portrait.
        let orientation: CGImagePropertyOrientation
        if width < height {
            orientation = .up
        } else {
            orientation = (cameraPosition == .front) ? .leftMirrored : .right
        }
        
        onFrameCaptured?(sampleBuffer, orientation)
    }
}
