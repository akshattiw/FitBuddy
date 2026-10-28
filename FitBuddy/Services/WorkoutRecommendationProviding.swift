import Foundation

/// Daily mood state for recommendation personalization.
public enum DailyMood: String, Codable, CaseIterable, Identifiable {
    case energized = "Energized ⚡️"
    case happy = "Feeling... 😊"
    case relaxed = "Relaxed 😌"
    case tired = "Tired 😴"
    
    public var id: String { rawValue }
}

/// Primary fitness goal selected by the user.
public enum FitnessGoal: String, Codable, CaseIterable, Identifiable {
    case generalFitness = "General Fitness"
    case buildStrength = "Build Strength"
    case improveMobility = "Improve Mobility"
    case stressRelief = "Stress Relief"
    case weightLoss = "Weight Loss"
    
    public var id: String { rawValue }
}

/// Cycle phase context for cycle-aware workout recommendations when permitted.
public enum CyclePhase: String, Codable, CaseIterable, Identifiable {
    case menstrual = "Menstrual Phase"
    case follicular = "Follicular Phase"
    case ovulatory = "Ovulatory Phase"
    case luteal = "Luteal Phase"
    
    public var id: String { rawValue }
}

/// Strongly typed input payload for generating tailored workout recommendations.
/// Free of any UI dependencies, Groq-specific parameters, or network client types.
public struct WorkoutRecommendationInput: Codable, Equatable {
    /// Relevant user profile (name, gender)
    public var userProfile: UserProfile
    
    /// Target fitness goal
    public var fitnessGoal: FitnessGoal
    
    /// Daily subjective mood and energy level
    public var dailyMood: DailyMood?
    
    /// Available equipment filtered by user (e.g. [.none, .dumbbells])
    public var availableEquipment: [EquipmentType]
    
    /// Available duration in seconds for the session (default: 900s / 15 mins)
    public var availableTimeSeconds: TimeInterval
    
    /// Recent completed workout titles or categories for recovery balance
    public var recentCompletedWorkouts: [String]
    
    /// Cycle phase (only provided when user's gender enables cycle tracking and user permitted cycle data usage)
    public var cyclePhase: CyclePhase?
    
    /// Logged cycle symptoms (e.g. Cramps, Fatigue) when permitted
    public var cycleSymptoms: [String]
    
    public init(
        userProfile: UserProfile,
        fitnessGoal: FitnessGoal = .generalFitness,
        dailyMood: DailyMood? = nil,
        availableEquipment: [EquipmentType] = [.none],
        availableTimeSeconds: TimeInterval = 900,
        recentCompletedWorkouts: [String] = [],
        cyclePhase: CyclePhase? = nil,
        cycleSymptoms: [String] = []
    ) {
        self.userProfile = userProfile
        self.fitnessGoal = fitnessGoal
        self.dailyMood = dailyMood
        self.availableEquipment = availableEquipment
        self.availableTimeSeconds = availableTimeSeconds
        self.recentCompletedWorkouts = recentCompletedWorkouts
        
        // Strict privacy safeguard: Cycle data can only be included if the profile enables cycle tracking
        if userProfile.gender?.enablesCycleTracking == true {
            self.cyclePhase = cyclePhase
            self.cycleSymptoms = cycleSymptoms
        } else {
            self.cyclePhase = nil
            self.cycleSymptoms = []
        }
    }
}

/// Protocol defining the contract for workout recommendation providers.
/// Enables mock providers and live AI backends to be interchanged without altering UI code.
public protocol WorkoutRecommendationProviding {
    /// Asynchronously generates personalized workout routines based on the provided input.
    /// - Parameter input: The user context, equipment, duration, and preferences.
    /// - Returns: An array of recommended `Workout` routines.
    func recommendWorkouts(for input: WorkoutRecommendationInput) async throws -> [Workout]
}
