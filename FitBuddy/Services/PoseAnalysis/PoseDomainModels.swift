import Foundation

/// MediaPipe Pose Landmarker uses the standard 33-landmark topology.
/// Keep SDK-specific types out of the analysis layer: the camera/MediaPipe
/// adapter should convert SDK results into these app-owned value types.
enum PoseLandmarkID: Int, CaseIterable, Hashable, Sendable {
    case nose = 0

    case leftShoulder = 11
    case rightShoulder = 12
    case leftElbow = 13
    case rightElbow = 14
    case leftWrist = 15
    case rightWrist = 16

    case leftHip = 23
    case rightHip = 24
    case leftKnee = 25
    case rightKnee = 26
    case leftAnkle = 27
    case rightAnkle = 28
}

struct PoseLandmark: Equatable, Sendable {
    let id: PoseLandmarkID
    /// Normalised image coordinates where x and y are ordinarily in 0...1.
    let x: Double
    let y: Double
    let z: Double?
    /// Normalised visibility/confidence supplied by the detector, if available.
    /// The adapter should use the detector's documented value and clamp it to 0...1.
    let confidence: Double

    var hasFiniteCoordinates: Bool {
        x.isFinite && y.isFinite && (z?.isFinite ?? true) && confidence.isFinite
    }

    func isUsable(minimumConfidence: Double) -> Bool {
        hasFiniteCoordinates && confidence >= minimumConfidence
    }
}

struct PoseFrame: Sendable {
    let timestampMilliseconds: Int64
    private let landmarkMap: [PoseLandmarkID: PoseLandmark]

    init(timestampMilliseconds: Int64, landmarks: [PoseLandmark]) {
        self.timestampMilliseconds = timestampMilliseconds
        self.landmarkMap = Dictionary(
            landmarks.map { ($0.id, $0) },
            uniquingKeysWith: { _, newer in newer }
        )
    }

    subscript(_ id: PoseLandmarkID) -> PoseLandmark? {
        landmarkMap[id]
    }

    var hasAnyLandmarks: Bool {
        !landmarkMap.isEmpty
    }
}

enum BodySide: String, Sendable {
    case left
    case right
}

enum AnalysisStatus: String, Sendable {
    case tracking
    case trackingLost
    case paused
    case unsupported
}

enum ExerciseMovementPhase: String, Sendable {
    case waitingForStartPosition
    case ready
    case descending
    case bottomPosition
    case ascending
}

enum ExerciseFeedback: String, Sendable {
    case neutral
    case moveIntoFrame
    case keepHipsAligned
    case lowerFurther
    case extendArmsAtTop
    case goodRep
    case paused
    case unsupportedExercise

    var message: String {
        switch self {
        case .neutral:
            return ""
        case .moveIntoFrame:
            return "Move into the frame and keep your body visible."
        case .keepHipsAligned:
            return "Keep your hips aligned with your shoulders and knees."
        case .lowerFurther:
            return "Lower further to complete the full range of motion."
        case .extendArmsAtTop:
            return "Begin from the top position with your arms extended."
        case .goodRep:
            return "Good repetition."
        case .paused:
            return "Workout paused."
        case .unsupportedExercise:
            return "Form tracking is not available for this exercise yet."
        }
    }
}

/// Immutable result produced by an exercise analyser for one processed frame.
/// `isRepetitionComplete` is a one-frame event, not a persistent state.
struct ExerciseAnalysisResult: Sendable {
    let status: AnalysisStatus
    let phase: ExerciseMovementPhase
    let completedRepetitions: Int
    let isRepetitionComplete: Bool
    let feedback: ExerciseFeedback
    let selectedSide: BodySide?
    let elbowAngleDegrees: Double?
    let shoulderAngleDegrees: Double?
    let hipAngleDegrees: Double?

    static func unsupported() -> ExerciseAnalysisResult {
        ExerciseAnalysisResult(
            status: .unsupported,
            phase: .waitingForStartPosition,
            completedRepetitions: 0,
            isRepetitionComplete: false,
            feedback: .unsupportedExercise,
            selectedSide: nil,
            elbowAngleDegrees: nil,
            shoulderAngleDegrees: nil,
            hipAngleDegrees: nil
        )
    }
}
