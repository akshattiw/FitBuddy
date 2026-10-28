import SwiftUI

@main struct MyApp: App {
    // Production recommendation services wired to the FastAPI backend
    private let workoutService: WorkoutRecommendationProviding
    private let nutritionService: NutritionRecommendationProviding
    
    public init() {
        self.workoutService = NetworkWorkoutRecommendationService()
        self.nutritionService = NetworkNutritionRecommendationService()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                workoutRecommendationService: workoutService,
                nutritionRecommendationService: nutritionService
            )
        }
    }
}
