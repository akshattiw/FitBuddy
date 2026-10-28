import Foundation

/// Targeted muscle groups for exercises and analytics matching the muscle engagement stats map.
public enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case core = "Core"
    case quads = "Quads"
    case hamstrings = "Hamstrings"
    case calves = "Calves"
    case glutes = "Glutes"
    case fullBody = "Full Body"
    
    public var id: String { rawValue }
}

/// Equipment types required for exercises or workouts.
public enum EquipmentType: String, Codable, CaseIterable, Identifiable {
    case none = "None (Bodyweight)"
    case dumbbells = "Dumbbells"
    case resistanceBands = "Resistance Bands"
    case yogaMat = "Yoga Mat"
    case kettlebell = "Kettlebell"
    case pullUpBar = "Pull-up Bar"
    case foamRoller = "Foam Roller"
    
    public var id: String { rawValue }
}

/// Difficulty levels for exercises and overall workouts.
public enum FitnessDifficulty: String, Codable, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    
    public var id: String { rawValue }
}

/// Strongly typed exercise domain model supporting variable metrics (reps vs duration).
public struct Exercise: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var description: String
    public var targetMuscles: [MuscleGroup]
    public var equipment: EquipmentType
    public var difficulty: FitnessDifficulty
    public var instructions: [String]
    
    // Performance parameters (optional to support duration-based vs repetition-based exercises)
    public var sets: Int?
    public var repetitions: Int?
    public var durationSeconds: TimeInterval?
    public var restIntervalSeconds: TimeInterval?
    
    // Form and guidance
    public var formNotes: String?
    public var illustrationName: String?
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        targetMuscles: [MuscleGroup],
        equipment: EquipmentType = .none,
        difficulty: FitnessDifficulty = .beginner,
        instructions: [String] = [],
        sets: Int? = nil,
        repetitions: Int? = nil,
        durationSeconds: TimeInterval? = nil,
        restIntervalSeconds: TimeInterval? = nil,
        formNotes: String? = nil,
        illustrationName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.targetMuscles = targetMuscles
        self.equipment = equipment
        self.difficulty = difficulty
        self.instructions = instructions
        self.sets = sets
        self.repetitions = repetitions
        self.durationSeconds = durationSeconds
        self.restIntervalSeconds = restIntervalSeconds
        self.formNotes = formNotes
        self.illustrationName = illustrationName
    }
}
