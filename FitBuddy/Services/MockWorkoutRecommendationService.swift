import Foundation

/// Errors that may occur during workout recommendation processing.
public enum WorkoutRecommendationError: LocalizedError {
    case invalidInput(String)
    case noMatchingWorkoutsAvailable
    
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let reason):
            return "Invalid recommendation input: \(reason)"
        case .noMatchingWorkoutsAvailable:
            return "No workouts matched the specified duration and equipment constraints."
        }
    }
}

/// Mock workout recommendation service conforming strictly to `WorkoutRecommendationProviding`.
/// Uses deterministic local heuristic rules to select and tailor workouts based on user goals,
/// equipment, duration, mood, and cycle symptoms without invoking external network/AI APIs.
public struct MockWorkoutRecommendationService: WorkoutRecommendationProviding {
    
    public init() {}
    
    public func recommendWorkouts(for input: WorkoutRecommendationInput) async throws -> [Workout] {
        // Validate input constraints
        guard input.availableTimeSeconds > 0 else {
            throw WorkoutRecommendationError.invalidInput("Available time must be greater than zero seconds.")
        }
        
        let catalog = Self.workoutCatalog
        
        // 1. Filter out workouts requiring equipment that is not available to the user
        // (If availableEquipment contains .none, bodyweight workouts are permitted)
        let filteredByEquipment = catalog.filter { workout in
            workout.requiredEquipment.allSatisfy { req in
                req == .none || input.availableEquipment.contains(req)
            }
        }
        
        // 2. Adjust for duration: Prefer workouts whose estimated duration <= availableTimeSeconds + 5 minutes
        let durationCeiling = input.availableTimeSeconds + 300
        var candidates = filteredByEquipment.filter { $0.estimatedDurationSeconds <= durationCeiling }
        
        // If duration filter eliminated everything, fall back to the equipment-safe workouts
        if candidates.isEmpty {
            candidates = filteredByEquipment
        }
        
        guard !candidates.isEmpty else {
            throw WorkoutRecommendationError.noMatchingWorkoutsAvailable
        }
        
        // 3. Score and prioritize candidates using deterministic local rules
        let scoredWorkouts = candidates.map { workout -> (Workout, Int) in
            var score = 0
            
            // Goal alignment
            switch (input.fitnessGoal, workout.category) {
            case (.buildStrength, .strength):
                score += 5
            case (.improveMobility, .stretch), (.improveMobility, .yoga):
                score += 5
            case (.stressRelief, .yoga), (.stressRelief, .recovery):
                score += 5
            case (.weightLoss, .cardio), (.weightLoss, .strength):
                score += 5
            case (.generalFitness, _):
                score += 2
            default:
                break
            }
            
            // Mood and energy level adaptation
            if let mood = input.dailyMood {
                switch (mood, workout.category) {
                case (.energized, .strength), (.energized, .cardio):
                    score += 4
                case (.tired, .stretch), (.tired, .recovery), (.tired, .yoga):
                    score += 4
                case (.relaxed, .yoga), (.relaxed, .stretch):
                    score += 3
                case (.happy, _):
                    score += 2
                default:
                    break
                }
            }
            
            // Cycle symptoms adaptation (e.g. cramps or fatigue prioritize gentle stretch & mobility)
            if input.cycleSymptoms.contains(where: { $0.caseInsensitiveCompare("cramps") == .orderedSame || $0.caseInsensitiveCompare("fatigue") == .orderedSame }) {
                if workout.category == .stretch || workout.category == .recovery || workout.category == .yoga {
                    score += 6
                }
            }
            
            // Recent workout recovery balancing: avoid repeating identical workout recently completed
            if input.recentCompletedWorkouts.contains(workout.name) {
                score -= 3
            }
            
            return (workout, score)
        }
        
        // Sort by highest score descending
        let sorted = scoredWorkouts.sorted { $0.1 > $1.1 }.map { $0.0 }
        
        // Return up to 3 diverse recommendations (as displayed in Today tab design)
        return Array(sorted.prefix(3))
    }
    
    // MARK: - Local Workout Catalog (Realistic sample library matching DesignReferences/today-screen.jpeg)
    
    private static var workoutCatalog: [Workout] {
        [
            // 1. Morning Stretch
            Workout(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                name: "Morning Stretch",
                description: "Gentle full-body mobility flow to awaken joints and improve circulation.",
                exercises: [
                    Exercise(
                        name: "Cat-Cow Flow",
                        description: "Spinal flexion and extension to release tension.",
                        targetMuscles: [.back, .core],
                        equipment: .yogaMat,
                        difficulty: .beginner,
                        instructions: ["Start on hands and knees.", "Inhale arching back, exhale rounding spine."],
                        durationSeconds: 120,
                        restIntervalSeconds: 30
                    ),
                    Exercise(
                        name: "Standing Side Reach",
                        description: "Elongates the lats and lateral abdominal wall.",
                        targetMuscles: [.back, .core],
                        equipment: .none,
                        difficulty: .beginner,
                        instructions: ["Reach right arm overhead leaning left.", "Switch sides smoothly."],
                        durationSeconds: 180,
                        restIntervalSeconds: 30
                    ),
                    Exercise(
                        name: "Downward Dog Hold",
                        description: "Calf and hamstring stretch with shoulder stabilization.",
                        targetMuscles: [.calves, .hamstrings, .shoulders],
                        equipment: .yogaMat,
                        difficulty: .beginner,
                        instructions: ["Press heels toward mat while lifting hips high."],
                        durationSeconds: 180,
                        restIntervalSeconds: 30
                    )
                ],
                category: .stretch,
                difficulty: .beginner,
                estimatedDurationSeconds: 900, // 15 mins
                estimatedCalories: 80,
                requiredEquipment: [.none],
                aiRecommendationRationale: "Selected to gently activate your body with minimal fatigue.",
                dateCreated: Date()
            ),
            
            // 2. Full Body Strength
            Workout(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                name: "Full Body Strength",
                description: "Compound functional strength circuit building muscular endurance.",
                exercises: [
                    Exercise(
                        name: "Goblet Squats",
                        description: "Lower body squat targeting quads and glutes.",
                        targetMuscles: [.quads, .glutes],
                        equipment: .dumbbells,
                        difficulty: .intermediate,
                        instructions: ["Hold dumbbell close to chest.", "Lower hips past parallel, stand upright."],
                        sets: 3,
                        repetitions: 12,
                        restIntervalSeconds: 60
                    ),
                    Exercise(
                        name: "Push-ups",
                        description: "Upper body pressing exercise for chest and core.",
                        targetMuscles: [.chest, .triceps, .core],
                        equipment: .none,
                        difficulty: .intermediate,
                        instructions: ["Maintain rigid plank.", "Lower chest to ground and push through palms."],
                        sets: 3,
                        repetitions: 10,
                        restIntervalSeconds: 45
                    ),
                    Exercise(
                        name: "Dumbbell Bent-Over Rows",
                        description: "Posterior chain pull strengthening lats and rhomboids.",
                        targetMuscles: [.back, .biceps],
                        equipment: .dumbbells,
                        difficulty: .intermediate,
                        instructions: ["Hinge at hips with flat back.", "Pull dumbbells towards lower ribs."],
                        sets: 3,
                        repetitions: 12,
                        restIntervalSeconds: 60
                    )
                ],
                category: .strength,
                difficulty: .intermediate,
                estimatedDurationSeconds: 1500, // 25 mins
                estimatedCalories: 180,
                requiredEquipment: [.dumbbells],
                aiRecommendationRationale: "Targeted to build total-body strength matching your energy level.",
                dateCreated: Date()
            ),
            
            // 3. Yoga Flow
            Workout(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                name: "Yoga Flow",
                description: "Restorative sequence focusing on breath synchronization and mindful hip openers.",
                exercises: [
                    Exercise(
                        name: "Warrior II Hold",
                        description: "Grounding posture strengthening legs and opening hips.",
                        targetMuscles: [.quads, .glutes, .shoulders],
                        equipment: .yogaMat,
                        difficulty: .beginner,
                        instructions: ["Front knee at 90 degrees.", "Gaze over front fingertips."],
                        durationSeconds: 180,
                        restIntervalSeconds: 30
                    ),
                    Exercise(
                        name: "Pigeon Pose",
                        description: "Deep hip flexor and glute tension release.",
                        targetMuscles: [.glutes, .hamstrings],
                        equipment: .yogaMat,
                        difficulty: .beginner,
                        instructions: ["Fold forward over front bent leg.", "Breathe deeply for 90 seconds per side."],
                        durationSeconds: 240,
                        restIntervalSeconds: 30
                    ),
                    Exercise(
                        name: "Child's Pose",
                        description: "Calming resting pose gently decompressing lower back.",
                        targetMuscles: [.back],
                        equipment: .none,
                        difficulty: .beginner,
                        instructions: ["Knees wide, big toes touching.", "Rest forehead gently on mat."],
                        durationSeconds: 180,
                        restIntervalSeconds: 0
                    )
                ],
                category: .yoga,
                difficulty: .beginner,
                estimatedDurationSeconds: 900, // 15 mins
                estimatedCalories: 60,
                requiredEquipment: [.none],
                aiRecommendationRationale: "Designed for recovery, stress reduction, and mind-body balance.",
                dateCreated: Date()
            ),
            
            // 4. Bodyweight Core & Cardio Blast
            Workout(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                name: "Core & Cardio Blast",
                description: "High-energy equipment-free interval session to burn calories and tone midsection.",
                exercises: [
                    Exercise(
                        name: "Mountain Climbers",
                        description: "Dynamic core exercise elevating heart rate.",
                        targetMuscles: [.core, .shoulders],
                        equipment: .none,
                        difficulty: .intermediate,
                        instructions: ["Drive knees alternately toward chest in rapid rhythm."],
                        durationSeconds: 180,
                        restIntervalSeconds: 30
                    ),
                    Exercise(
                        name: "Bicycle Crunches",
                        description: "Rotational abdominal exercise engaging obliques.",
                        targetMuscles: [.core],
                        equipment: .none,
                        difficulty: .intermediate,
                        instructions: ["Touch opposite elbow to knee with control."],
                        sets: 3,
                        repetitions: 20,
                        restIntervalSeconds: 45
                    )
                ],
                category: .cardio,
                difficulty: .intermediate,
                estimatedDurationSeconds: 720, // 12 mins
                estimatedCalories: 130,
                requiredEquipment: [.none],
                aiRecommendationRationale: "Short, intense session maximizing workout efficiency without equipment.",
                dateCreated: Date()
            ),
            
            // 5. Active Recovery & Mobility
            Workout(
                id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                name: "Active Recovery",
                description: "Low-impact restorative sequence for rest days and fatigue alleviation.",
                exercises: [
                    Exercise(
                        name: "Foam Rolling Quads & Back",
                        description: "Self-myofascial release improving soft-tissue flexibility.",
                        targetMuscles: [.quads, .back],
                        equipment: .foamRoller,
                        difficulty: .beginner,
                        instructions: ["Roll slowly over tight trigger points for 30-60 seconds."],
                        durationSeconds: 300,
                        restIntervalSeconds: 30
                    ),
                    Exercise(
                        name: "Legs Up The Wall",
                        description: "Passive inversion assisting lymphatic drainage and relaxation.",
                        targetMuscles: [.calves, .hamstrings],
                        equipment: .none,
                        difficulty: .beginner,
                        instructions: ["Rest legs vertically against a wall while lying flat on back."],
                        durationSeconds: 300,
                        restIntervalSeconds: 0
                    )
                ],
                category: .recovery,
                difficulty: .beginner,
                estimatedDurationSeconds: 600, // 10 mins
                estimatedCalories: 45,
                requiredEquipment: [.foamRoller],
                aiRecommendationRationale: "Selected to soothe muscles and support active recovery.",
                dateCreated: Date()
            )
        ]
    }
}
