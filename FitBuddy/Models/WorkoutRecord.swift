import Foundation

/// Record of an exercise completed during a workout session.
public struct CompletedExerciseRecord: Identifiable, Codable, Equatable {
    public let id: UUID
    public let exerciseId: UUID
    public let exerciseName: String
    public let setsCompleted: Int
    public let repsCompleted: Int?
    public let durationSeconds: TimeInterval?
    public let targetedMuscles: [MuscleGroup]
    
    public init(
        id: UUID = UUID(),
        exerciseId: UUID,
        exerciseName: String,
        setsCompleted: Int = 1,
        repsCompleted: Int? = nil,
        durationSeconds: TimeInterval? = nil,
        targetedMuscles: [MuscleGroup] = []
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.setsCompleted = setsCompleted
        self.repsCompleted = repsCompleted
        self.durationSeconds = durationSeconds
        self.targetedMuscles = targetedMuscles
    }
    
    enum CodingKeys: String, CodingKey {
        case id, exerciseId, exerciseName, setsCompleted, repsCompleted, durationSeconds, targetedMuscles
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.exerciseId = try container.decode(UUID.self, forKey: .exerciseId)
        self.exerciseName = try container.decode(String.self, forKey: .exerciseName)
        self.setsCompleted = try container.decode(Int.self, forKey: .setsCompleted)
        self.repsCompleted = try container.decodeIfPresent(Int.self, forKey: .repsCompleted)
        self.durationSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .durationSeconds)
        self.targetedMuscles = try container.decodeIfPresent([MuscleGroup].self, forKey: .targetedMuscles) ?? []
    }
}

/// Persistent and queryable record of a workout session actually completed by the user.
/// Strictly decoupled from recommendation definitions (`Workout`).
public struct WorkoutRecord: Identifiable, Codable, Equatable {
    public let id: UUID
    public let workoutId: UUID
    public let workoutName: String
    public let category: WorkoutCategory
    
    /// Timestamp when workout session started
    public let startDate: Date
    
    /// Timestamp when workout session completed
    public let endDate: Date
    
    /// Actual measured elapsed time in seconds (excluding paused intervals)
    public let actualDurationSeconds: TimeInterval
    
    /// Estimated calories based on routine metadata and completion ratio (clearly designated as estimated, not measured)
    public let estimatedCaloriesBurned: Int
    
    /// Detailed list of exercises actually marked completed
    public let completedExercises: [CompletedExerciseRecord]
    
    public init(
        id: UUID = UUID(),
        workoutId: UUID,
        workoutName: String,
        category: WorkoutCategory,
        startDate: Date,
        endDate: Date,
        actualDurationSeconds: TimeInterval,
        estimatedCaloriesBurned: Int,
        completedExercises: [CompletedExerciseRecord]
    ) {
        self.id = id
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.category = category
        self.startDate = startDate
        self.endDate = endDate
        self.actualDurationSeconds = actualDurationSeconds
        self.estimatedCaloriesBurned = estimatedCaloriesBurned
        self.completedExercises = completedExercises
    }
    
    /// Formatted actual duration (e.g. "18 mins 30 secs")
    public var formattedDuration: String {
        let minutes = Int(actualDurationSeconds) / 60
        let seconds = Int(actualDurationSeconds) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    /// Estimated calorie display clearly labeled as an estimate
    public var formattedCaloriesEstimate: String {
        return "\(estimatedCaloriesBurned) kcal (est.)"
    }
}
