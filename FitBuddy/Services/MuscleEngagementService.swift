import Foundation

/// Intensity level of muscle group engagement.
public enum MuscleEngagementIntensity: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case light = "Light"
    case moderate = "Moderate"
    case high = "High"
    
    public var id: String { rawValue }
    
    public var relativeWeight: Double {
        switch self {
        case .none: return 0.0
        case .light: return 0.33
        case .moderate: return 0.66
        case .high: return 1.0
        }
    }
}

/// Service that computes muscle engagement from genuinely completed workout records.
/// Decouples scoring, volume calculations, and recency fading from SwiftUI views.
public struct MuscleEngagementService {
    
    public init() {}
    
    /// Computes engagement scores (0.0 to 1.0) for each muscle group based on completed workout records.
    /// Incorporates completed exercise sets and time-based recency decay (decaying over 7 days).
    public func calculateEngagement(
        from records: [WorkoutRecord],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [MuscleGroup: Double] {
        var rawScores: [MuscleGroup: Double] = [:]
        for group in MuscleGroup.allCases {
            rawScores[group] = 0.0
        }
        
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: referenceDate) ?? referenceDate
        let recentRecords = records.filter { $0.endDate >= sevenDaysAgo }
        
        for record in recentRecords {
            // Days elapsed since workout (0 to 7)
            let daysAgo = max(0, min(7, calendar.dateComponents([.day], from: record.endDate, to: referenceDate).day ?? 0))
            // Linear recency factor: today = 1.0, 7 days ago = 0.3
            let recencyFactor = 1.0 - (Double(daysAgo) * 0.1)
            
            // Map completed exercises back to their targeted muscles
            for exercise in record.completedExercises {
                let muscles = exercise.targetedMuscles.isEmpty
                    ? inferMuscleGroups(for: exercise.exerciseName, category: record.category)
                    : exercise.targetedMuscles
                let setsWeight = Double(max(1, exercise.setsCompleted))
                
                for muscle in muscles {
                    if muscle == .fullBody {
                        for subGroup in [MuscleGroup.chest, .back, .quads, .core, .shoulders] {
                            rawScores[subGroup, default: 0.0] += setsWeight * recencyFactor * 0.5
                        }
                    } else {
                        rawScores[muscle, default: 0.0] += setsWeight * recencyFactor
                    }
                }
            }
        }
        
        // Normalize scores against a standard baseline (e.g. 10 sets in a week = 1.0 maximum engagement)
        var normalized: [MuscleGroup: Double] = [:]
        for (muscle, score) in rawScores {
            normalized[muscle] = min(1.0, score / 10.0)
        }
        return normalized
    }
    
    /// Maps normalized score to categorical intensity.
    public func intensity(for score: Double) -> MuscleEngagementIntensity {
        if score >= 0.65 {
            return .high
        } else if score >= 0.30 {
            return .moderate
        } else if score > 0.05 {
            return .light
        } else {
            return .none
        }
    }
    
    // MARK: - Exercise name to muscle group resolution
    private func inferMuscleGroups(for exerciseName: String, category: WorkoutCategory) -> [MuscleGroup] {
        let lower = exerciseName.lowercased()
        if lower.contains("squat") || lower.contains("lunge") { return [.quads, .glutes] }
        if lower.contains("push-up") || lower.contains("bench") || lower.contains("chest") { return [.chest, .triceps] }
        if lower.contains("shoulder") || lower.contains("overhead") || lower.contains("military") || lower.contains("deltoid") { return [.shoulders, .triceps] }
        if lower.contains("bicep") || lower.contains("curl") { return [.biceps] }
        if lower.contains("tricep") || lower.contains("dip") { return [.triceps] }
        if lower.contains("row") || lower.contains("pull-up") || lower.contains("lat") || lower.contains("pull") { return [.back, .biceps] }
        if lower.contains("deadlift") { return [.hamstrings, .glutes, .back] }
        if lower.contains("cat-cow") || lower.contains("reach") || lower.contains("child") { return [.back, .core] }
        if lower.contains("dog") || lower.contains("hamstring") { return [.hamstrings, .calves] }
        if lower.contains("warrior") || lower.contains("pigeon") { return [.quads, .glutes, .hamstrings] }
        if lower.contains("climber") || lower.contains("crunch") || lower.contains("core") || lower.contains("plank") || lower.contains("ab") { return [.core] }
        if lower.contains("roller") { return [.quads, .back] }
        if lower.contains("calf") || lower.contains("calves") || lower.contains("heel") { return [.calves] }
        if lower.contains("leg") { return [.calves, .hamstrings, .quads] }
        
        // Category fallback
        switch category {
        case .strength: return [.chest, .quads, .back]
        case .stretch: return [.back, .core]
        case .yoga: return [.glutes, .back, .hamstrings]
        case .cardio: return [.core, .quads]
        case .recovery: return [.back, .hamstrings]
        }
    }
}
