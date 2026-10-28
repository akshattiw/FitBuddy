import Foundation

/// Target goals or categories for fitness routines.
public enum WorkoutCategory: String, Codable, CaseIterable, Identifiable {
    case stretch = "Stretch & Mobility"
    case strength = "Full Body Strength"
    case yoga = "Yoga & Flow"
    case cardio = "Cardio & HIIT"
    case recovery = "Active Recovery"
    
    public var id: String { rawValue }
}

/// Strongly typed workout routine domain model.
/// Independent of UI views, network requests, and external AI services.
public struct Workout: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var description: String
    public var exercises: [Exercise]
    public var category: WorkoutCategory
    public var difficulty: FitnessDifficulty
    
    /// Estimated duration in seconds (e.g. 900s for 15 mins)
    public var estimatedDurationSeconds: TimeInterval
    
    /// Estimated energy expenditure in kilocalories (clearly labeled as an estimate)
    public var estimatedCalories: Int
    
    /// Consolidated equipment required across all exercises
    public var requiredEquipment: [EquipmentType]
    
    /// Optional AI-generated explanation for why this workout was recommended
    public var aiRecommendationRationale: String?
    
    /// Recommendation or creation timestamp
    public var dateCreated: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        exercises: [Exercise] = [],
        category: WorkoutCategory,
        difficulty: FitnessDifficulty = .beginner,
        estimatedDurationSeconds: TimeInterval,
        estimatedCalories: Int,
        requiredEquipment: [EquipmentType] = [.none],
        aiRecommendationRationale: String? = nil,
        dateCreated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.exercises = exercises
        self.category = category
        self.difficulty = difficulty
        self.estimatedDurationSeconds = estimatedDurationSeconds
        self.estimatedCalories = estimatedCalories
        self.requiredEquipment = requiredEquipment
        self.aiRecommendationRationale = aiRecommendationRationale
        self.dateCreated = dateCreated
    }
    
    /// Formatted estimated duration in minutes (e.g. "15 mins")
    public var formattedDuration: String {
        let minutes = Int(estimatedDurationSeconds / 60)
        return "\(minutes) mins"
    }
    
    /// Formatted estimated calorie label (e.g. "80 kcal est.")
    public var formattedCaloriesEstimate: String {
        return "\(estimatedCalories) kcal est."
    }
}
