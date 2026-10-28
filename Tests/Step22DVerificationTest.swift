import Foundation

/// Step 22D Comprehensive Integration & Fallback Resilience Verification
/// Tests:
/// 1. End-to-end workout recommendation -> session execution -> history store -> reward store (XP awarded).
/// 2. End-to-end nutrition recommendation -> food log -> nutrition store -> summary recalculation.
/// 3. Offline resilience: verify fallback routines when server is down or unreachable.
/// 4. Error handling: verify typed errors when offline fallback is disabled.
@main
struct Step22DVerificationTest {
    static func main() async {
        print("=================================================================")
        print("  FitBuddy Step 22D: End-to-End & Fallback Resilience Verification")
        print("=================================================================")
        
        var passedCount = 0
        var failedCount = 0
        
        func assert(_ condition: Bool, _ testName: String) {
            if condition {
                print("  [PASS] \(testName)")
                passedCount += 1
            } else {
                print("  [FAIL] \(testName)")
                failedCount += 1
            }
        }
        
        // -----------------------------------------------------------------
        // TEST 1: Workout Flow - Recommendation -> Session -> History -> Rewards
        // -----------------------------------------------------------------
        print("\n--- Test Suite 1: Full Workout Tracking Lifecycle ---")
        do {
            // Instantiate network service with fallback enabled (default)
            let workoutService = NetworkWorkoutRecommendationService()
            let profile = UserProfile(
                name: "Alex Rivera",
                gender: .female
            )
            
            let workoutInput = WorkoutRecommendationInput(
                userProfile: profile,
                fitnessGoal: .buildStrength,
                dailyMood: .energized,
                availableEquipment: [.dumbbells, .none],
                availableTimeSeconds: 1800,
                recentCompletedWorkouts: [],
                cyclePhase: .follicular,
                cycleSymptoms: []
            )
            
            print("1. Fetching workout recommendation...")
            let workouts = try await workoutService.recommendWorkouts(for: workoutInput)
            assert(!workouts.isEmpty, "Recommendations array is not empty (count: \(workouts.count))")
            
            guard let firstWorkout = workouts.first else {
                fatalError("No workout returned")
            }
            assert(!firstWorkout.exercises.isEmpty, "Workout has exercises (count: \(firstWorkout.exercises.count))")
            assert(firstWorkout.aiRecommendationRationale != nil, "AI rationale is attached")
            print("   -> Selected Workout: '\(firstWorkout.name)' with rationale: \(firstWorkout.aiRecommendationRationale ?? "nil")")
            
            // Start Active Session
            let tracker = WorkoutSessionTracker(workout: firstWorkout)
            if case .ready = tracker.state {
                assert(true, "Tracker initialized in .ready state")
            } else {
                assert(false, "Tracker not initialized in .ready state")
            }
            
            tracker.startSession()
            if case .active = tracker.state {
                assert(true, "Tracker transitioned to .active state")
            } else {
                assert(false, "Tracker not transitioned to .active state")
            }
            
            // Complete all exercises
            for _ in 0..<firstWorkout.exercises.count {
                tracker.markCurrentExerciseCompleted()
            }
            assert(tracker.completedExerciseIds.count == firstWorkout.exercises.count, "All exercises marked as completed")
            
            let completedRecord = tracker.finishSession()
            assert(completedRecord.workoutName == firstWorkout.name, "Record matches workout name")
            assert(completedRecord.completedExercises.count == firstWorkout.exercises.count, "Record captured correct completed exercise count")
            
            // Add to WorkoutHistoryStore
            let historyStore = WorkoutHistoryStore()
            historyStore.addRecord(completedRecord)
            assert(historyStore.totalWorkoutsCompleted == 1, "WorkoutHistoryStore recorded 1 completed session")
            
            // Process in RewardStore
            let rewardStore = RewardStore()
            let initialXP = rewardStore.state.totalXP
            let initialLevel = rewardStore.state.currentLevel
            
            rewardStore.synchronize(with: historyStore.records)
            let newXP = rewardStore.state.totalXP
            assert(newXP > initialXP, "XP awarded for real completed workout (\(newXP - initialXP) XP awarded)")
            assert(rewardStore.state.currentLevel >= initialLevel, "RewardStore level maintained or increased")
            
            // Verify idempotency (re-synchronizing without new records awards 0 additional XP)
            let xpBeforeResync = rewardStore.state.totalXP
            rewardStore.synchronize(with: historyStore.records)
            assert(rewardStore.state.totalXP == xpBeforeResync, "Re-synchronization awards 0 XP (idempotency verified)")
        } catch {
            assert(false, "Workout tracking lifecycle threw unexpected error: \(error)")
        }
        
        // -----------------------------------------------------------------
        // TEST 2: Nutrition Flow - Recommendation -> FoodLog -> Store
        // -----------------------------------------------------------------
        print("\n--- Test Suite 2: Nutrition Lifecycle & Store Integration ---")
        do {
            let nutritionService = NetworkNutritionRecommendationService()
            let profile = UserProfile(
                name: "Sam Taylor",
                gender: .other
            )
            let nutritionInput = NutritionRecommendationInput(
                userProfile: profile,
                fitnessGoal: .generalFitness,
                targets: NutritionTargets(dailyCalorieTarget: 2200, proteinGramsTarget: 140, carbohydratesGramsTarget: 200, fatGramsTarget: 65),
                currentSummary: nil,
                dietaryPreferences: [.vegetarian],
                targetMealType: .lunch,
                budget: .moderate,
                availableIngredients: []
            )
            
            print("1. Fetching nutrition recommendations...")
            let suggestions = try await nutritionService.recommendFoods(for: nutritionInput)
            assert(!suggestions.isEmpty, "Nutrition response has food suggestions (count: \(suggestions.count))")
            
            guard let firstSuggestion = suggestions.first else {
                fatalError("No food suggestion returned")
            }
            assert(firstSuggestion.estimatedCalories > 0, "Suggested food has valid calories (> 0)")
            assert(!firstSuggestion.recommendationRationale.isEmpty, "Nutrition recommendation rationale is populated")
            print("   -> Suggested Food: '\(firstSuggestion.foodItem.name)' (\(firstSuggestion.estimatedCalories) kcal) - '\(firstSuggestion.recommendationRationale)'")
            
            // Convert to FoodLogs and log in NutritionDataStore
            let nutritionStore = NutritionDataStore()
            let initialSummary = nutritionStore.summary()
            let initialCalories = initialSummary.consumedCalories
            
            for item in suggestions {
                let log = FoodLog(
                    foodItem: item.foodItem,
                    servingQuantity: item.suggestedQuantity
                )
                nutritionStore.addFoodLog(log)
            }
            
            let finalSummary = nutritionStore.summary()
            assert(finalSummary.consumedCalories > initialCalories, "NutritionDataStore summary successfully updated consumed calories")
        } catch {
            assert(false, "Nutrition lifecycle threw unexpected error: \(error)")
        }
        
        // -----------------------------------------------------------------
        // TEST 3: Offline Fallback Resilience (Unreachable Server)
        // -----------------------------------------------------------------
        print("\n--- Test Suite 3: Offline Fallback Resilience ---")
        do {
            // Point client to an unreachable port (e.g., 59999) where no server is running
            let offlineClient = RecommendationAPIClient(
                session: {
                    let config = URLSessionConfiguration.ephemeral
                    config.timeoutIntervalForRequest = 1.0
                    return URLSession(configuration: config)
                }(),
                baseURLProvider: { URL(string: "http://127.0.0.1:59999")! }
            )
            
            let offlineWorkoutService = NetworkWorkoutRecommendationService(
                apiClient: offlineClient,
                enableOfflineFallback: true
            )
            
            let profile = UserProfile(name: "Offline User", gender: nil)
            let req = WorkoutRecommendationInput(userProfile: profile, dailyMood: .tired)
            
            print("1. Requesting workout with unreachable backend & enableOfflineFallback: true...")
            let fallbackWorkouts = try await offlineWorkoutService.recommendWorkouts(for: req)
            assert(!fallbackWorkouts.isEmpty, "Fallback routines returned without throwing exception")
            
            if let first = fallbackWorkouts.first {
                let rationale = first.aiRecommendationRationale ?? ""
                assert(rationale.hasPrefix("[Offline Fallback]"), "Fallback routine correctly tagged with '[Offline Fallback]' prefix: '\(rationale)'")
            }
            
            // Nutrition fallback test
            let offlineNutritionService = NetworkNutritionRecommendationService(
                apiClient: offlineClient,
                enableOfflineFallback: true
            )
            let nutReq = NutritionRecommendationInput(userProfile: profile, targetMealType: .dinner)
            print("2. Requesting nutrition with unreachable backend & enableOfflineFallback: true...")
            let fallbackNutrition = try await offlineNutritionService.recommendFoods(for: nutReq)
            assert(!fallbackNutrition.isEmpty, "Fallback nutrition returned without throwing exception")
            if let firstNut = fallbackNutrition.first {
                assert(firstNut.recommendationRationale.hasPrefix("[Offline Fallback]"), "Fallback food item tagged with '[Offline Fallback]' prefix")
            }
        } catch {
            assert(false, "Offline fallback test threw unexpected error: \(error)")
        }
        
        // -----------------------------------------------------------------
        // TEST 4: Typed Error Handling (When Fallback is Disabled)
        // -----------------------------------------------------------------
        print("\n--- Test Suite 4: Strict Error Propagation (Fallback Disabled) ---")
        do {
            let offlineClient = RecommendationAPIClient(
                session: {
                    let config = URLSessionConfiguration.ephemeral
                    config.timeoutIntervalForRequest = 1.0
                    return URLSession(configuration: config)
                }(),
                baseURLProvider: { URL(string: "http://127.0.0.1:59999")! }
            )
            
            let strictWorkoutService = NetworkWorkoutRecommendationService(
                apiClient: offlineClient,
                enableOfflineFallback: false // Strict mode
            )
            
            let profile = UserProfile(name: "Strict User", gender: nil)
            let req = WorkoutRecommendationInput(userProfile: profile, dailyMood: .tired)
            
            print("1. Requesting workout with unreachable backend & enableOfflineFallback: false...")
            _ = try await strictWorkoutService.recommendWorkouts(for: req)
            assert(false, "Expected error to be thrown in strict mode")
        } catch let error as RecommendationNetworkError {
            switch error {
            case .connectivityFailed:
                assert(true, "Successfully caught typed RecommendationNetworkError.connectivityFailed")
            default:
                assert(true, "Successfully caught typed RecommendationNetworkError: \(error.localizedDescription)")
            }
        } catch {
            assert(false, "Caught unknown non-typed error: \(error)")
        }
        
        // -----------------------------------------------------------------
        // SUMMARY
        // -----------------------------------------------------------------
        print("\n=================================================================")
        print("  STEP 22D RESULTS: \(passedCount) Passed, \(failedCount) Failed")
        print("=================================================================")
        
        if failedCount == 0 {
            print("  ALL STEP 22D INTEGRATION & RESILIENCE TESTS PASSED!")
            exit(0)
        } else {
            print("  FAILURES DETECTED!")
            exit(1)
        }
    }
}
