import SwiftUI
import AVFoundation

// MARK: - Live Camera Pose Container View
/// Hosts the camera preview layer, real-time skeleton overlay, and floating posture correction pill.
/// Handles permission requests, camera readiness, simulator fallbacks, and coordinate scaling.
struct LiveCameraPoseContainerView: View {
    @ObservedObject var cameraManager: CameraCaptureManager
    let landmarks: [PoseLandmark]
    let feedback: ExerciseFeedback
    let isPaused: Bool
    let isUnsupported: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        cameraManager: CameraCaptureManager = .shared,
        landmarks: [PoseLandmark],
        feedback: ExerciseFeedback,
        isPaused: Bool,
        isUnsupported: Bool = false
    ) {
        self.cameraManager = cameraManager
        self.landmarks = landmarks
        self.feedback = feedback
        self.isPaused = isPaused
        self.isUnsupported = isUnsupported
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base Dark Surface
                Color.black
                
                // 1. Camera Feed / State Fallbacks
                if cameraManager.permissionStatus == .denied || cameraManager.permissionStatus == .restricted {
                    permissionDeniedView
                } else if !cameraManager.isCameraAvailable {
                    simulatorFallbackView
                } else if cameraManager.isPreparing {
                    cameraPreparingView
                } else {
                    // Live AVFoundation Preview Layer
                    CameraPreviewRepresentable(session: cameraManager.captureSession)
                    
                    // Real-Time Pose Skeleton Overlay
                    if !landmarks.isEmpty && !isPaused {
                        PoseSkeletonCanvas(
                            landmarks: landmarks,
                            feedback: feedback,
                            size: geometry.size
                        )
                    }
                }
                
                // 2. Paused Tint Overlay
                if isPaused {
                    ZStack {
                        Color.black.opacity(0.45)
                        
                        VStack(spacing: 6) {
                            Image(systemName: "pause.circle.fill")
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Workout Paused")
                                .font(AppTheme.Typography.cardTitle)
                                .foregroundColor(.white)
                        }
                    }
                    .transition(.opacity)
                }
                
                // 3. Floating Posture Correction / Status Pill (Top)
                VStack {
                    HStack {
                        postureFeedbackPill
                        Spacer()
                    }
                    .padding(AppTheme.Spacing.small + 2)
                    
                    Spacer()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
            .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
        }
    }
    
    // MARK: - Posture Feedback Pill
    
    @ViewBuilder
    private var postureFeedbackPill: some View {
        let text = currentFeedbackText
        if !text.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: feedbackIcon)
                    .font(.system(size: 11, weight: .bold))
                
                Text(text)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundColor(feedbackForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .background(feedbackBackground.opacity(0.25))
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
            .animation(.easeInOut(duration: 0.2), value: text)
        }
    }
    
    private var currentFeedbackText: String {
        if isPaused {
            return "Workout paused"
        }
        if isUnsupported {
            return "Live camera active • Push-ups AI supported"
        }
        if !feedback.message.isEmpty {
            return feedback.message
        }
        if !landmarks.isEmpty {
            return "Tracking form • Keep going"
        }
        return "Position yourself in view"
    }
    
    private var feedbackIcon: String {
        switch feedback {
        case .goodRep:
            return "checkmark.circle.fill"
        case .keepHipsAligned:
            return "exclamationmark.triangle.fill"
        case .lowerFurther, .extendArmsAtTop:
            return "arrow.up.and.down"
        case .moveIntoFrame:
            return "person.fill.viewfinder"
        case .paused:
            return "pause.fill"
        case .unsupportedExercise:
            return "info.circle.fill"
        case .neutral:
            return "figure.strengthtraining.traditional"
        }
    }
    
    private var feedbackForeground: Color {
        switch feedback {
        case .goodRep:
            return AppColors.mint
        case .keepHipsAligned:
            return AppColors.peachAccent
        case .lowerFurther, .extendArmsAtTop:
            return AppColors.skyBlueAccent
        default:
            return .white
        }
    }
    
    private var feedbackBackground: Color {
        switch feedback {
        case .goodRep:
            return AppColors.mint
        case .keepHipsAligned:
            return AppColors.peachAccent
        default:
            return Color.black
        }
    }
    
    // MARK: - State Views
    
    private var cameraPreparingView: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
            
            Text("Starting camera...")
                .font(AppTheme.Typography.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private var permissionDeniedView: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: "camera.fill")
                .font(.system(size: 34))
                .foregroundColor(AppColors.peachAccent)
            
            Text("Camera Access Needed")
                .font(AppTheme.Typography.cardTitle)
                .foregroundColor(.white)
            
            Text("Enable camera access in Settings to track your workout posture and count reps.")
                .font(AppTheme.Typography.caption)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.large)
            
            Button {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            } label: {
                Text("Open Settings")
                    .font(AppTheme.Typography.buttonLabel)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppTheme.Spacing.large)
                    .padding(.vertical, 8)
                    .background(AppColors.mint)
                    .clipShape(Capsule())
            }
        }
        .padding(AppTheme.Spacing.large)
    }
    
    private var simulatorFallbackView: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "camera.metering.matrix")
                    .font(.system(size: 36))
                    .foregroundColor(AppColors.mint)
            }
            
            Text("Simulator Mode")
                .font(AppTheme.Typography.cardTitle)
                .foregroundColor(.white)
            
            Text("Camera capture & live pose tracking require a physical iOS device.")
                .font(AppTheme.Typography.caption)
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.large)
        }
        .padding(AppTheme.Spacing.large)
    }
}

// MARK: - Pose Skeleton Canvas
/// Draws landmarks and connecting bones scaled to the container bounds using video aspect-fill mapping.
struct PoseSkeletonCanvas: View {
    let landmarks: [PoseLandmark]
    let feedback: ExerciseFeedback
    let size: CGSize
    
    var body: some View {
        Canvas { context, canvasSize in
            guard !landmarks.isEmpty else { return }
            let landmarkDict = Dictionary(landmarks.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
            
            // Standard iPhone camera stream aspect ratio in portrait is 9:16 (0.5625)
            let videoAspect: CGFloat = 9.0 / 16.0
            let canvasAspect = canvasSize.width / max(1.0, canvasSize.height)
            
            let renderWidth: CGFloat
            let renderHeight: CGFloat
            let offsetX: CGFloat
            let offsetY: CGFloat
            
            if canvasAspect > videoAspect {
                // Canvas is wider than 9:16 video -> video fills width, top & bottom cropped equally
                renderWidth = canvasSize.width
                renderHeight = canvasSize.width / videoAspect
                offsetX = 0
                offsetY = (canvasSize.height - renderHeight) / 2.0
            } else {
                // Canvas is taller than 9:16 video -> video fills height, left & right cropped equally
                renderHeight = canvasSize.height
                renderWidth = canvasSize.height * videoAspect
                offsetX = (canvasSize.width - renderWidth) / 2.0
                offsetY = 0
            }
            
            func point(for id: PoseLandmarkID) -> CGPoint? {
                guard let lm = landmarkDict[id], lm.confidence > 0.15 else { return nil }
                return CGPoint(
                    x: offsetX + lm.x * renderWidth,
                    y: offsetY + lm.y * renderHeight
                )
            }
            
            let boneColor: Color = (feedback == .keepHipsAligned) ? AppColors.peachAccent : AppColors.mint
            let jointColor: Color = .white
            
            // Standard Body Bone Connections
            let connections: [(PoseLandmarkID, PoseLandmarkID)] = [
                // Shoulders & Torso
                (.leftShoulder, .rightShoulder),
                (.leftShoulder, .leftHip),
                (.rightShoulder, .rightHip),
                (.leftHip, .rightHip),
                // Left Arm
                (.leftShoulder, .leftElbow),
                (.leftElbow, .leftWrist),
                // Right Arm
                (.rightShoulder, .rightElbow),
                (.rightElbow, .rightWrist),
                // Left Leg
                (.leftHip, .leftKnee),
                (.leftKnee, .leftAnkle),
                // Right Leg
                (.rightHip, .rightKnee),
                (.rightKnee, .rightAnkle)
            ]
            
            // Draw Bones
            for (startId, endId) in connections {
                if let p1 = point(for: startId), let p2 = point(for: endId) {
                    var path = Path()
                    path.move(to: p1)
                    path.addLine(to: p2)
                    context.stroke(
                        path,
                        with: .color(boneColor.opacity(0.85)),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            
            // Draw Joints
            for lm in landmarks where lm.confidence > 0.15 {
                let center = CGPoint(
                    x: offsetX + lm.x * renderWidth,
                    y: offsetY + lm.y * renderHeight
                )
                let rect = CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)
                
                // Outer glow
                context.fill(
                    Path(ellipseIn: rect.insetBy(dx: -1.5, dy: -1.5)),
                    with: .color(boneColor.opacity(0.6))
                )
                // Center dot
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(jointColor)
                )
            }
        }
    }
}

// MARK: - Camera Preview Representable
struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        if let connection = view.videoPreviewLayer.connection {
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
                connection.isVideoMirrored = (CameraCaptureManager.shared.cameraPosition == .front)
            }
        }
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        if uiView.videoPreviewLayer.session != session {
            uiView.videoPreviewLayer.session = session
        }
        if let connection = uiView.videoPreviewLayer.connection {
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90) && connection.videoRotationAngle != 90 {
                    connection.videoRotationAngle = 90
                }
            } else {
                if connection.isVideoOrientationSupported && connection.videoOrientation != .portrait {
                    connection.videoOrientation = .portrait
                }
            }
            if connection.isVideoMirroringSupported {
                let shouldMirror = (CameraCaptureManager.shared.cameraPosition == .front)
                if connection.isVideoMirrored != shouldMirror {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = shouldMirror
                }
            }
        }
    }
}

final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
