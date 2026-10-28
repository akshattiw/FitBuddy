import Foundation

/// Production workout recommendation service connecting to the FitBuddy FastAPI backend.
/// Conforms to `WorkoutRecommendationProviding` to remain interchangeable with `MockWorkoutRecommendationService`.
public final class NetworkWorkoutRecommendationService: WorkoutRecommendationProviding, @unchecked Sendable {
    
    private let apiClient: RecommendationAPIClientProtocol
    private let fallbackService: WorkoutRecommendationProviding?
    private let enableOfflineFallback: Bool
    
    public init(
        apiClient: RecommendationAPIClientProtocol = RecommendationAPIClient(),
        fallbackService: WorkoutRecommendationProviding? = MockWorkoutRecommendationService(),
        enableOfflineFallback: Bool = true
    ) {
        self.apiClient = apiClient
        self.fallbackService = fallbackService
        self.enableOfflineFallback = enableOfflineFallback
    }
    
    public func recommendWorkouts(for input: WorkoutRecommendationInput) async throws -> [Workout] {
        do {
            let workouts = try await apiClient.requestWorkouts(input: input)
            return workouts
        } catch {
            // Respect requirement: Never silently fabricate AI output without clear distinction
            if enableOfflineFallback, let fallback = fallbackService {
                var fallbackWorkouts = try await fallback.recommendWorkouts(for: input)
                for index in 0..<fallbackWorkouts.count {
                    let originalRationale = fallbackWorkouts[index].aiRecommendationRationale ?? ""
                    fallbackWorkouts[index].aiRecommendationRationale = "[Offline Fallback] \(originalRationale)".trimmingCharacters(in: .whitespaces)
                }
                return fallbackWorkouts
            } else {
                throw error
            }
        }
    }
}
