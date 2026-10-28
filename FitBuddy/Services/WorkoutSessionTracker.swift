import SwiftUI
import Combine

/// State machine tracking live workout execution.
/// Decouples active session timing, pause/resume, and progress from SwiftUI view hierarchies.
@Observable
public final class WorkoutSessionTracker {
    public enum SessionState {
        case ready
        case active
        case paused
        case completed(WorkoutRecord)
        case cancelled
    }
    
    public let workout: Workout
    public private(set) var state: SessionState = .ready
    
    // Timing state
    public private(set) var elapsedSeconds: TimeInterval = 0
    public private(set) var sessionStartDate: Date?
    private var timerSubscription: AnyCancellable?
    
    // Progress state
    public private(set) var currentExerciseIndex: Int = 0
    public private(set) var completedExerciseIds: Set<UUID> = []
    
    public init(workout: Workout, startingExerciseIndex: Int = 0) {
        self.workout = workout
        if startingExerciseIndex >= 0 && startingExerciseIndex < workout.exercises.count {
            self.currentExerciseIndex = startingExerciseIndex
        } else {
            self.currentExerciseIndex = 0
        }
    }
    
    public var currentExercise: Exercise? {
        guard currentExerciseIndex < workout.exercises.count else { return nil }
        return workout.exercises[currentExerciseIndex]
    }
    
    public var isFirstExercise: Bool {
        currentExerciseIndex == 0
    }
    
    public var isLastExercise: Bool {
        currentExerciseIndex >= max(0, workout.exercises.count - 1)
    }
    
    public var progressRatio: Double {
        guard !workout.exercises.isEmpty else { return 0 }
        return Double(completedExerciseIds.count) / Double(workout.exercises.count)
    }
    
    // MARK: - Session Controls
    
    public func startSession() {
        guard case .ready = state else { return }
        sessionStartDate = Date()
        state = .active
        startTimer()
    }
    
    public func pauseSession() {
        guard case .active = state else { return }
        state = .paused
        stopTimer()
    }
    
    public func resumeSession() {
        guard case .paused = state else { return }
        state = .active
        startTimer()
    }
    
    public func togglePlayPause() {
        if case .active = state {
            pauseSession()
        } else if case .paused = state {
            resumeSession()
        }
    }
    
    public func markCurrentExerciseCompleted() {
        guard let current = currentExercise else { return }
        completedExerciseIds.insert(current.id)
        if !isLastExercise {
            currentExerciseIndex += 1
        }
    }
    
    public func previousExercise() {
        if currentExerciseIndex > 0 {
            currentExerciseIndex -= 1
        }
    }
    
    public func nextExercise() {
        if currentExerciseIndex < workout.exercises.count - 1 {
            currentExerciseIndex += 1
        }
    }
    
    /// Concludes session and builds a verified `WorkoutRecord`.
    /// Does not claim calories were measured; computes conservative estimate based on routine ratio.
    public func finishSession() -> WorkoutRecord {
        stopTimer()
        let endDate = Date()
        let startDate = sessionStartDate ?? endDate
        
        if completedExerciseIds.isEmpty, let current = currentExercise {
            completedExerciseIds.insert(current.id)
        }
        
        let completedRecords = workout.exercises.compactMap { exercise -> CompletedExerciseRecord? in
            guard completedExerciseIds.contains(exercise.id) else { return nil }
            return CompletedExerciseRecord(
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                setsCompleted: exercise.sets ?? 1,
                repsCompleted: exercise.repetitions,
                durationSeconds: exercise.durationSeconds,
                targetedMuscles: exercise.targetMuscles
            )
        }
        
        // Compute estimated calories burned based on completion ratio and elapsed duration
        let ratio = workout.exercises.isEmpty ? 1.0 : Double(completedRecords.count) / Double(workout.exercises.count)
        let estimatedBurn = Int(Double(workout.estimatedCalories) * max(0.2, min(1.0, ratio)))
        
        let record = WorkoutRecord(
            workoutId: workout.id,
            workoutName: workout.name,
            category: workout.category,
            startDate: startDate,
            endDate: endDate,
            actualDurationSeconds: elapsedSeconds,
            estimatedCaloriesBurned: estimatedBurn,
            completedExercises: completedRecords
        )
        
        state = .completed(record)
        return record
    }
    
    /// Exits without creating a record.
    public func cancelSession() {
        stopTimer()
        state = .cancelled
    }
    
    // MARK: - Timer internals
    private func startTimer() {
        timerSubscription = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.elapsedSeconds += 1
            }
    }
    
    private func stopTimer() {
        timerSubscription?.cancel()
        timerSubscription = nil
    }
    
    public var formattedElapsedTime: String {
        let mins = Int(elapsedSeconds) / 60
        let secs = Int(elapsedSeconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
