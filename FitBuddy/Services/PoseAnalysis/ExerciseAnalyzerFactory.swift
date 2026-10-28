import Foundation

// MARK: - Exercise Analyzer Factory
/// Maps the app's exercise models to appropriate domain analyzers.
/// Push-ups are handled by `PushUpAnalyzer`; other exercises are honestly marked unsupported.
final class ExerciseAnalyzerFactory {
    
    static func analyzer(for exercise: Exercise) -> ExerciseAnalyzer {
        let nameLower = exercise.name.lowercased()
        if nameLower.contains("push-up") || nameLower.contains("pushup") || exercise.id.uuidString == "push_up" {
            return PushUpAnalyzer(configuration: PushUpAnalyzerConfiguration())
        }
        
        // Unsupported exercises return an honest placeholder analyzer
        return UnsupportedExerciseAnalyzer(exerciseName: exercise.name)
    }
}

// MARK: - Unsupported Exercise Fallback Analyzer
final class UnsupportedExerciseAnalyzer: ExerciseAnalyzer {
    let exerciseIdentifier: String
    private var isPaused = false
    
    init(exerciseName: String) {
        self.exerciseIdentifier = exerciseName
    }
    
    func process(frame: PoseFrame) -> ExerciseAnalysisResult {
        if isPaused {
            return ExerciseAnalysisResult(
                status: .paused,
                phase: .waitingForStartPosition,
                completedRepetitions: 0,
                isRepetitionComplete: false,
                feedback: .paused,
                selectedSide: nil,
                elbowAngleDegrees: nil,
                shoulderAngleDegrees: nil,
                hipAngleDegrees: nil
            )
        }
        return ExerciseAnalysisResult.unsupported()
    }
    
    func setPaused(_ paused: Bool) {
        self.isPaused = paused
    }
    
    func reset() {
        self.isPaused = false
    }
}
