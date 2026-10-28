import Foundation

/// Exercise-specific push-up analyser, independent of camera capture, MediaPipe,
/// SwiftUI, calorie estimation, and workout persistence.
///
/// Design notes:
/// - Consumes normalised pose landmarks through `PoseFrame`.
/// - Requires a complete top -> bottom -> top cycle before adding one rep.
/// - Invalid hip alignment during a cycle invalidates that cycle.
/// - Missing/low-confidence landmarks reset the in-progress cycle, never the
///   already completed rep total.
/// - `isRepetitionComplete` is true for only the frame that completes the rep.
final class PushUpAnalyzer: ExerciseAnalyzer {
    let exerciseIdentifier = "push_up"

    private let configuration: PushUpAnalyzerConfiguration
    private var phase: ExerciseMovementPhase = .waitingForStartPosition
    private var completedRepetitions = 0
    private var selectedSide: BodySide?
    private var cycleStartedAtMilliseconds: Int64?
    private var reachedBottom = false
    private var cycleFormValid = true
    private var isPaused = false
    private var lastTimestampMilliseconds: Int64?
    private var lastResult: ExerciseAnalysisResult?
    private var minElbowAngleInCycle: Double = 180.0
    private var consecutiveLostFrames: Int = 0

    init(configuration: PushUpAnalyzerConfiguration = PushUpAnalyzerConfiguration()) {
        self.configuration = configuration
    }

    func setPaused(_ paused: Bool) {
        guard paused != isPaused else { return }
        isPaused = paused

        // Do not allow a partial repetition from before/during a pause to be
        // completed after resuming. The completed-rep total remains intact.
        if !paused {
            resetMovementCycle()
            selectedSide = nil
            lastTimestampMilliseconds = nil
        }
    }

    func reset() {
        phase = .waitingForStartPosition
        completedRepetitions = 0
        selectedSide = nil
        cycleStartedAtMilliseconds = nil
        reachedBottom = false
        cycleFormValid = true
        minElbowAngleInCycle = 180.0
        consecutiveLostFrames = 0
        lastTimestampMilliseconds = nil
        lastResult = nil
    }

    func process(frame: PoseFrame) -> ExerciseAnalysisResult {
        if isPaused {
            return makeResult(
                status: .paused,
                feedback: .paused,
                measurements: nil,
                isRepetitionComplete: false
            )
        }

        if let previousTimestamp = lastTimestampMilliseconds,
           frame.timestampMilliseconds <= previousTimestamp {
            // Do not emit a second rep event for a duplicate/out-of-order frame.
            return resultWithoutRepEvent(from: lastResult) ?? makeResult(
                status: .trackingLost,
                feedback: .moveIntoFrame,
                measurements: nil,
                isRepetitionComplete: false
            )
        }

        if let previousTimestamp = lastTimestampMilliseconds,
           frame.timestampMilliseconds - previousTimestamp > configuration.maximumFrameGapMilliseconds {
            resetMovementCycle()
            selectedSide = nil
        }
        lastTimestampMilliseconds = frame.timestampMilliseconds

        guard let measurements = measurements(for: frame) else {
            consecutiveLostFrames += 1
            if consecutiveLostFrames > 8 {
                resetMovementCycle()
                selectedSide = nil
                let result = makeResult(
                    status: .trackingLost,
                    feedback: .moveIntoFrame,
                    measurements: nil,
                    isRepetitionComplete: false
                )
                lastResult = result
                return result
            } else {
                return makeResult(
                    status: .tracking,
                    feedback: lastResult?.feedback ?? .neutral,
                    measurements: nil,
                    isRepetitionComplete: false
                )
            }
        }
        consecutiveLostFrames = 0

        if selectedSide == nil {
            selectedSide = measurements.side
        }

        let hipsAligned = measurements.hipAngleDegrees >= configuration.minimumHipAlignmentAngleDegrees
        var feedback: ExerciseFeedback = hipsAligned ? .neutral : .keepHipsAligned
        var completedRepThisFrame = false

        // Once alignment fails during a movement cycle, that cycle is invalid.
        // This prevents a user from briefly correcting form at the end and
        // receiving credit for a repetition that was performed out of alignment.
        if !hipsAligned && isMidCycle(phase) {
            cycleFormValid = false
        }

        switch phase {
        case .waitingForStartPosition:
            if !hipsAligned {
                feedback = .keepHipsAligned
            } else if measurements.elbowAngleDegrees >= configuration.topPositionAngleDegrees {
                phase = .ready
                feedback = .neutral
            } else {
                feedback = .extendArmsAtTop
            }

        case .ready:
            if !hipsAligned {
                feedback = .keepHipsAligned
            } else if measurements.elbowAngleDegrees <= configuration.beginDescentAngleDegrees {
                phase = .descending
                cycleStartedAtMilliseconds = frame.timestampMilliseconds
                reachedBottom = false
                cycleFormValid = true
                minElbowAngleInCycle = measurements.elbowAngleDegrees
                feedback = .neutral
            }

        case .descending:
            minElbowAngleInCycle = min(minElbowAngleInCycle, measurements.elbowAngleDegrees)
            if !hipsAligned {
                feedback = .keepHipsAligned
            }

            if measurements.elbowAngleDegrees <= configuration.bottomPositionAngleDegrees {
                phase = .bottomPosition
                reachedBottom = true
                feedback = .neutral
            } else if measurements.elbowAngleDegrees >= minElbowAngleInCycle + 15.0 && measurements.elbowAngleDegrees >= configuration.beginAscentAngleDegrees {
                // The user started returning upward before reaching the target depth.
                phase = .ascending
                feedback = .lowerFurther
            }

        case .bottomPosition:
            minElbowAngleInCycle = min(minElbowAngleInCycle, measurements.elbowAngleDegrees)
            if !hipsAligned {
                feedback = .keepHipsAligned
            }
            if measurements.elbowAngleDegrees >= configuration.bottomPositionAngleDegrees + 10.0 {
                phase = .ascending
                feedback = .neutral
            }

        case .ascending:
            if !hipsAligned {
                feedback = .keepHipsAligned
            }

            if measurements.elbowAngleDegrees >= configuration.topPositionAngleDegrees {
                let durationMilliseconds = cycleStartedAtMilliseconds.map {
                    frame.timestampMilliseconds - $0
                } ?? 0
                let durationSeconds = Double(durationMilliseconds) / 1_000.0
                let durationIsPlausible = durationSeconds >= configuration.minimumRepDurationSeconds

                if reachedBottom && cycleFormValid && hipsAligned && durationIsPlausible {
                    completedRepetitions += 1
                    completedRepThisFrame = true
                    feedback = .goodRep
                } else if !cycleFormValid || !hipsAligned {
                    feedback = .keepHipsAligned
                } else {
                    feedback = .lowerFurther
                }

                phase = .ready
                cycleStartedAtMilliseconds = nil
                reachedBottom = false
                cycleFormValid = true
                minElbowAngleInCycle = 180.0
            }
        }

        let result = makeResult(
            status: .tracking,
            feedback: feedback,
            measurements: measurements,
            isRepetitionComplete: completedRepThisFrame
        )
        lastResult = result
        return result
    }

    // MARK: - Measurements

    private struct Measurements {
        let side: BodySide
        let elbowAngleDegrees: Double
        let shoulderAngleDegrees: Double
        let hipAngleDegrees: Double
        let confidenceScore: Double
    }

    private func measurements(for frame: PoseFrame) -> Measurements? {
        // Evaluate both sides; prioritize currently tracked side if confidence is good,
        // but seamlessly allow switching if the other side becomes more clearly visible.
        let leftMeasurement = measurements(for: frame, side: .left)
        let rightMeasurement = measurements(for: frame, side: .right)
        
        switch (leftMeasurement, rightMeasurement) {
        case (let left?, let right?):
            if let active = selectedSide {
                let activeMeasurement = (active == .left) ? left : right
                let otherMeasurement = (active == .left) ? right : left
                // Retain current side unless other side is substantially more confident
                if activeMeasurement.confidenceScore >= otherMeasurement.confidenceScore - 0.20 {
                    return activeMeasurement
                } else {
                    selectedSide = otherMeasurement.side
                    return otherMeasurement
                }
            } else {
                let chosen = (left.confidenceScore >= right.confidenceScore) ? left : right
                selectedSide = chosen.side
                return chosen
            }
        case (let left?, nil):
            selectedSide = .left
            return left
        case (nil, let right?):
            selectedSide = .right
            return right
        case (nil, nil):
            return nil
        }
    }

    private func measurements(for frame: PoseFrame, side: BodySide) -> Measurements? {
        let shoulderId: PoseLandmarkID
        let elbowId: PoseLandmarkID
        let wristId: PoseLandmarkID
        let hipId: PoseLandmarkID
        let kneeId: PoseLandmarkID
        let ankleId: PoseLandmarkID

        switch side {
        case .left:
            shoulderId = .leftShoulder
            elbowId = .leftElbow
            wristId = .leftWrist
            hipId = .leftHip
            kneeId = .leftKnee
            ankleId = .leftAnkle
        case .right:
            shoulderId = .rightShoulder
            elbowId = .rightElbow
            wristId = .rightWrist
            hipId = .rightHip
            kneeId = .rightKnee
            ankleId = .rightAnkle
        }

        guard let shoulder = frame[shoulderId],
              let elbow = frame[elbowId],
              let wrist = frame[wristId] else {
            return nil
        }

        // Arm landmarks must have required minimum confidence
        let armPoints = [shoulder, elbow, wrist]
        guard armPoints.allSatisfy({ $0.isUsable(minimumConfidence: configuration.minimumLandmarkConfidence) }),
              let elbowAngle = JointAngleCalculator.angleDegrees(first: shoulder, vertex: elbow, third: wrist) else {
            return nil
        }

        // Calculate shoulder angle if hip is present
        let hip = frame[hipId]
        let shoulderAngle: Double
        if let hip = hip, hip.isUsable(minimumConfidence: configuration.minimumLandmarkConfidence),
           let sAngle = JointAngleCalculator.angleDegrees(first: elbow, vertex: shoulder, third: hip) {
            shoulderAngle = sAngle
        } else {
            shoulderAngle = 90.0
        }

        // Calculate hip angle: prioritize knee, fallback to ankle, or default to 180 (aligned)
        let hipAngle: Double
        var allTrackedPoints = armPoints
        if let hip = hip, hip.isUsable(minimumConfidence: configuration.minimumLandmarkConfidence) {
            allTrackedPoints.append(hip)
            if let knee = frame[kneeId], knee.isUsable(minimumConfidence: configuration.minimumLandmarkConfidence),
               let angle = JointAngleCalculator.angleDegrees(first: shoulder, vertex: hip, third: knee) {
                hipAngle = angle
                allTrackedPoints.append(knee)
            } else if let ankle = frame[ankleId], ankle.isUsable(minimumConfidence: configuration.minimumLandmarkConfidence),
                      let angle = JointAngleCalculator.angleDegrees(first: shoulder, vertex: hip, third: ankle) {
                hipAngle = angle
                allTrackedPoints.append(ankle)
            } else {
                hipAngle = 180.0
            }
        } else {
            hipAngle = 180.0
        }

        let averageConfidence = allTrackedPoints.map(\.confidence).reduce(0, +) / Double(allTrackedPoints.count)
        return Measurements(
            side: side,
            elbowAngleDegrees: elbowAngle,
            shoulderAngleDegrees: shoulderAngle,
            hipAngleDegrees: hipAngle,
            confidenceScore: averageConfidence
        )
    }

    // MARK: - State and result helpers

    private func isMidCycle(_ phase: ExerciseMovementPhase) -> Bool {
        phase == .descending || phase == .bottomPosition || phase == .ascending
    }

    private func resetMovementCycle() {
        phase = .waitingForStartPosition
        cycleStartedAtMilliseconds = nil
        reachedBottom = false
        cycleFormValid = true
    }

    private func makeResult(
        status: AnalysisStatus,
        feedback: ExerciseFeedback,
        measurements: Measurements?,
        isRepetitionComplete: Bool
    ) -> ExerciseAnalysisResult {
        ExerciseAnalysisResult(
            status: status,
            phase: phase,
            completedRepetitions: completedRepetitions,
            isRepetitionComplete: isRepetitionComplete,
            feedback: feedback,
            selectedSide: measurements?.side ?? selectedSide,
            elbowAngleDegrees: measurements?.elbowAngleDegrees,
            shoulderAngleDegrees: measurements?.shoulderAngleDegrees,
            hipAngleDegrees: measurements?.hipAngleDegrees
        )
    }

    private func resultWithoutRepEvent(from result: ExerciseAnalysisResult?) -> ExerciseAnalysisResult? {
        guard let result else { return nil }
        return ExerciseAnalysisResult(
            status: result.status,
            phase: result.phase,
            completedRepetitions: result.completedRepetitions,
            isRepetitionComplete: false,
            feedback: result.feedback,
            selectedSide: result.selectedSide,
            elbowAngleDegrees: result.elbowAngleDegrees,
            shoulderAngleDegrees: result.shoulderAngleDegrees,
            hipAngleDegrees: result.hipAngleDegrees
        )
    }
}
