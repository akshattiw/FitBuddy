import Foundation

/// Contract shared by exercise-specific analysers. Camera capture, pose-model
/// inference, workout session state, and SwiftUI presentation remain separate.
protocol ExerciseAnalyzer: AnyObject {
    /// Stable identifier used by the app's exercise model, not a display title.
    var exerciseIdentifier: String { get }

    /// Process one detector result. Calls should be serial and timestamps monotonic.
    func process(frame: PoseFrame) -> ExerciseAnalysisResult

    /// Pausing must suppress analysis events. Resuming must not complete a rep
    /// based on a movement that happened while paused.
    func setPaused(_ paused: Bool)

    /// Reset state for a new exercise session, including its rep count.
    func reset()
}
