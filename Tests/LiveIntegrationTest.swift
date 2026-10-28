import Foundation

/// Standalone live integration runner.
/// Requires the FastAPI backend to be running on http://127.0.0.1:8000 with a valid GROQ_API_KEY.
@main
public struct LiveIntegrationTestRunner {
    public static func main() async {
        print("=== FitBuddy Live AI Backend Integration Test ===")
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        let liveSession = URLSession(configuration: config)
        
        let client = RecommendationAPIClient(
            session: liveSession,
            baseURLProvider: { AppBackendConfig.currentBaseURL }
        )
        
        do {
            print("1. Checking backend health...")
            let isHealthy = try await client.checkHealth()
            if !isHealthy {
                print("❌ Backend is not healthy or unreachable at \(AppBackendConfig.currentBaseURL).")
                exit(1)
            }
            print("   ✅ Backend is online and healthy!")
            
            print("2. Requesting live workout recommendations...")
            let workoutInput = WorkoutRecommendationInput(
                userProfile: UserProfile(name: "Priya", gender: .female),
                fitnessGoal: .generalFitness,
                dailyMood: .energized,
                availableEquipment: [.none, .yogaMat],
                availableTimeSeconds: 1200
            )
            let workouts = try await client.requestWorkouts(input: workoutInput)
            print("   ✅ Received \(workouts.count) live workout routines:")
            for w in workouts {
                print("      • \(w.name) (\(w.category.rawValue), \(w.formattedDuration), \(w.exercises.count) exercises)")
            }
            
            print("3. Requesting live nutrition recommendations...")
            let nutritionInput = NutritionRecommendationInput(
                userProfile: UserProfile(name: "Priya", gender: .female),
                fitnessGoal: .weightLoss,
                targets: NutritionTargets(dailyCalorieTarget: 2000, proteinGramsTarget: 140, carbohydratesGramsTarget: 200, fatGramsTarget: 65),
                dietaryPreferences: [.vegetarian],
                targetMealType: .dinner,
                budget: .budget
            )
            let suggestions = try await client.requestNutrition(input: nutritionInput)
            print("   ✅ Received \(suggestions.count) live food suggestions:")
            for s in suggestions {
                print("      • \(s.foodItem.name) (\(Int(s.estimatedCalories)) kcal, \(Int(s.estimatedProteinGrams))g protein) - \(s.recommendationRationale)")
            }
            
            print("\n🎉 Live End-to-End AI Integration Verification: PASSED!")
        } catch {
            print("\n❌ Live Integration Failed: \(error.localizedDescription)")
            exit(1)
        }
    }
}
