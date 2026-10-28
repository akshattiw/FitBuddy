import Foundation

/// Tunable starting values adapted from the linked Python push-up example.
/// These values require validation on real devices and are not medical standards.
struct PushUpAnalyzerConfiguration: Sendable {
    let minimumLandmarkConfidence: Double
    let topPositionAngleDegrees: Double
    let beginDescentAngleDegrees: Double
    let bottomPositionAngleDegrees: Double
    let beginAscentAngleDegrees: Double
    let minimumHipAlignmentAngleDegrees: Double
    let minimumRepDurationSeconds: Double
    let maximumFrameGapMilliseconds: Int64

    init(
        minimumLandmarkConfidence: Double = 0.25,
        topPositionAngleDegrees: Double = 145.0,
        beginDescentAngleDegrees: Double = 138.0,
        bottomPositionAngleDegrees: Double = 102.0,
        beginAscentAngleDegrees: Double = 112.0,
        minimumHipAlignmentAngleDegrees: Double = 140.0,
        minimumRepDurationSeconds: Double = 0.35,
        maximumFrameGapMilliseconds: Int64 = 1_500
    ) {
        self.minimumLandmarkConfidence = min(1.0, max(0.0, minimumLandmarkConfidence))
        self.topPositionAngleDegrees = topPositionAngleDegrees
        self.beginDescentAngleDegrees = beginDescentAngleDegrees
        self.bottomPositionAngleDegrees = bottomPositionAngleDegrees
        self.beginAscentAngleDegrees = beginAscentAngleDegrees
        self.minimumHipAlignmentAngleDegrees = minimumHipAlignmentAngleDegrees
        self.minimumRepDurationSeconds = max(0.0, minimumRepDurationSeconds)
        self.maximumFrameGapMilliseconds = max(1, maximumFrameGapMilliseconds)
    }
}
