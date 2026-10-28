import Foundation

/// Production nutrition recommendation service connecting to the FitBuddy FastAPI backend.
/// Conforms to `NutritionRecommendationProviding` to remain interchangeable with `MockNutritionRecommendationService`.
public final class NetworkNutritionRecommendationService: NutritionRecommendationProviding, @unchecked Sendable {
    
    private let apiClient: RecommendationAPIClientProtocol
    private let fallbackService: NutritionRecommendationProviding?
    private let enableOfflineFallback: Bool
    
    public init(
        apiClient: RecommendationAPIClientProtocol = RecommendationAPIClient(),
        fallbackService: NutritionRecommendationProviding? = MockNutritionRecommendationService(),
        enableOfflineFallback: Bool = true
    ) {
        self.apiClient = apiClient
        self.fallbackService = fallbackService
        self.enableOfflineFallback = enableOfflineFallback
    }
    
    public func recommendFoods(for input: NutritionRecommendationInput) async throws -> [FoodSuggestion] {
        do {
            let suggestions = try await apiClient.requestNutrition(input: input)
            return suggestions
        } catch {
            // Respect requirement: Never silently fabricate AI output without clear distinction
            if enableOfflineFallback, let fallback = fallbackService {
                let fallbackSuggestions = try await fallback.recommendFoods(for: input)
                return fallbackSuggestions.map { suggestion in
                    FoodSuggestion(
                        id: suggestion.id,
                        foodItem: suggestion.foodItem,
                        suggestedQuantity: suggestion.suggestedQuantity,
                        targetMealType: suggestion.targetMealType,
                        recommendationRationale: "[Offline Fallback] \(suggestion.recommendationRationale)".trimmingCharacters(in: .whitespaces)
                    )
                }
            } else {
                throw error
            }
        }
    }
}
