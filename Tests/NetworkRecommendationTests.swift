import Foundation

// MARK: - Mock URLProtocol for Deterministic Network Testing

public final class MockURLProtocol: URLProtocol {
    public static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    public override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    public override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    public override func stopLoading() {}
}

// MARK: - Test Runner

@main
public struct NetworkRecommendationTestsRunner {
    
    private static var passedCount = 0
    private static var failedCount = 0
    
    public static func main() async {
        print("=== FitBuddy Network Recommendation Test Suite ===")
        
        await run("testWorkoutRequestDTOEncoding", testWorkoutRequestDTOEncoding)
        await run("testWorkoutRequestDTODurationClamping", testWorkoutRequestDTODurationClamping)
        await run("testWorkoutRequestDTOCyclePrivacySafeguard", testWorkoutRequestDTOCyclePrivacySafeguard)
        await run("testNutritionRequestDTOEncoding", testNutritionRequestDTOEncoding)
        await run("testWorkoutResponseDTODecoding", testWorkoutResponseDTODecoding)
        await run("testNutritionResponseDTODecoding", testNutritionResponseDTODecoding)
        await run("testBackendErrorResponseDecoding", testBackendErrorResponseDecoding)
        await run("testMockURLProtocolSuccessWorkout", testMockURLProtocolSuccessWorkout)
        await run("testMockURLProtocolSuccessNutrition", testMockURLProtocolSuccessNutrition)
        await run("testMockURLProtocolHTTP422ValidationError", testMockURLProtocolHTTP422ValidationError)
        await run("testMockURLProtocolHTTP503BusyError", testMockURLProtocolHTTP503BusyError)
        await run("testMockURLProtocolTimeout", testMockURLProtocolTimeout)
        await run("testMockURLProtocolMalformedJSON", testMockURLProtocolMalformedJSON)
        await run("testInsecureConnectionEnforcement", testInsecureConnectionEnforcement)
        await run("testNetworkWorkoutServiceFallbackActive", testNetworkWorkoutServiceFallbackActive)
        await run("testNetworkWorkoutServiceThrowsWhenFallbackDisabled", testNetworkWorkoutServiceThrowsWhenFallbackDisabled)
        await run("testNetworkNutritionServiceFallbackActive", testNetworkNutritionServiceFallbackActive)
        
        print("\nTest Summary: \(passedCount) passed, \(failedCount) failed.")
        if failedCount > 0 {
            exit(1)
        }
    }
    
    private static func run(_ name: String, _ test: () async throws -> Void) async {
        do {
            try await test()
            passedCount += 1
            print("  ✅ \(name)")
        } catch {
            failedCount += 1
            print("  ❌ \(name): \(error)")
        }
    }
    
    private static func assertTrue(_ condition: Bool, _ message: String = "") throws {
        if !condition {
            throw NSError(domain: "TestFailure", code: 1, userInfo: [NSLocalizedDescriptionKey: "Assertion failed: \(message)"])
        }
    }
    
    private static func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
    
    // MARK: - Tests
    
    static func testWorkoutRequestDTOEncoding() throws {
        let profile = UserProfile(name: "Priya", gender: .female)
        let input = WorkoutRecommendationInput(
            userProfile: profile,
            fitnessGoal: .buildStrength,
            dailyMood: .energized,
            availableEquipment: [.none, .dumbbells],
            availableTimeSeconds: 1800,
            recentCompletedWorkouts: ["Morning Yoga"],
            cyclePhase: .follicular,
            cycleSymptoms: ["Fatigue"]
        )
        
        let dto = WorkoutRecommendationRequestDTO(from: input)
        try assertTrue(dto.user_name == "Priya")
        try assertTrue(dto.gender == "Female")
        try assertTrue(dto.fitness_goal == "Build Strength")
        try assertTrue(dto.daily_mood == "Energized ⚡️")
        try assertTrue(dto.available_equipment == ["None (Bodyweight)", "Dumbbells"])
        try assertTrue(dto.available_time_seconds == 1800)
        try assertTrue(dto.recent_completed_workouts == ["Morning Yoga"])
        try assertTrue(dto.cycle_phase == "Follicular Phase")
        try assertTrue(dto.cycle_symptoms == ["Fatigue"])
        
        let data = try JSONEncoder().encode(dto)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        try assertTrue(json?["user_name"] as? String == "Priya")
    }
    
    static func testWorkoutRequestDTODurationClamping() throws {
        let profile = UserProfile(name: "Priya", gender: .female)
        
        // Too short (< 300s) -> should clamp to 300
        let inputShort = WorkoutRecommendationInput(userProfile: profile, availableTimeSeconds: 60)
        let dtoShort = WorkoutRecommendationRequestDTO(from: inputShort)
        try assertTrue(dtoShort.available_time_seconds == 300)
        
        // Too long (> 7200s) -> should clamp to 7200
        let inputLong = WorkoutRecommendationInput(userProfile: profile, availableTimeSeconds: 10000)
        let dtoLong = WorkoutRecommendationRequestDTO(from: inputLong)
        try assertTrue(dtoLong.available_time_seconds == 7200)
    }
    
    static func testWorkoutRequestDTOCyclePrivacySafeguard() throws {
        // Male profile must NEVER include cycle data, even if mistakenly passed
        let maleProfile = UserProfile(name: "Rahul", gender: .male)
        let input = WorkoutRecommendationInput(
            userProfile: maleProfile,
            cyclePhase: .luteal,
            cycleSymptoms: ["Cramps"]
        )
        let dto = WorkoutRecommendationRequestDTO(from: input)
        try assertTrue(dto.cycle_phase == nil, "Male cycle phase must be nil")
        try assertTrue(dto.cycle_symptoms.isEmpty, "Male cycle symptoms must be empty")
    }
    
    static func testNutritionRequestDTOEncoding() throws {
        let profile = UserProfile(name: "Priya", gender: .female)
        let targets = NutritionTargets(dailyCalorieTarget: 2000, proteinGramsTarget: 140, carbohydratesGramsTarget: 200, fatGramsTarget: 65)
        let summary = NutritionSummary(
            date: Date(),
            targets: targets,
            consumedCalories: 1200,
            consumedProteinGrams: 65,
            consumedCarbohydratesGrams: 130,
            consumedFatGrams: 30
        )
        let input = NutritionRecommendationInput(
            userProfile: profile,
            fitnessGoal: .weightLoss,
            targets: targets,
            currentSummary: summary,
            dietaryPreferences: [.vegetarian],
            targetMealType: .dinner,
            budget: .budget,
            availableIngredients: ["dal", "roti", "curd"],
            date: Date(timeIntervalSince1970: 1729728000) // 2024-10-24
        )
        
        let dto = NutritionRecommendationRequestDTO(from: input)
        try assertTrue(dto.user_name == "Priya")
        try assertTrue(dto.fitness_goal == "Weight Loss")
        try assertTrue(dto.daily_calorie_target == 2000)
        try assertTrue(dto.consumed_calories == 1200)
        try assertTrue(dto.remaining_calories == 800)
        try assertTrue(dto.remaining_protein_grams == 75)
        try assertTrue(dto.dietary_preferences == ["Vegetarian"])
        try assertTrue(dto.target_meal_type == "Dinner")
        try assertTrue(dto.budget_tier == "Budget Friendly")
        try assertTrue(dto.available_ingredients == ["dal", "roti", "curd"])
        try assertTrue(!dto.request_date.isEmpty)
    }
    
    static func testWorkoutResponseDTODecoding() throws {
        let jsonString = """
        {
          "workouts": [
            {
              "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
              "name": "Morning Energy Flow",
              "description": "Dynamic flow matching energised mood.",
              "category": "Stretch & Mobility",
              "difficulty": "Beginner",
              "estimated_duration_seconds": 900,
              "estimated_calories": 110,
              "required_equipment": ["None (Bodyweight)", "Yoga Mat"],
              "ai_recommendation_rationale": "Suited to Energized mood.",
              "exercises": [
                {
                  "id": "b1a2c3d4-e5f6-7890-abcd-ef1234567890",
                  "name": "Sun Salutation",
                  "description": "Flowing sequence.",
                  "target_muscles": ["Full Body", "Core"],
                  "equipment": "Yoga Mat",
                  "difficulty": "Beginner",
                  "instructions": ["Stand tall", "Fold forward"],
                  "sets": null,
                  "repetitions": null,
                  "duration_seconds": 120,
                  "rest_interval_seconds": 15,
                  "form_notes": "Keep spine long"
                }
              ]
            }
          ],
          "model_used": "llama-3.1-8b-instant",
          "generated_at": "2026-10-24T03:00:00Z"
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let dto = try JSONDecoder().decode(WorkoutRecommendationResponseDTO.self, from: data)
        try assertTrue(dto.workouts.count == 1)
        
        let workout = dto.workouts[0].toDomain()
        try assertTrue(workout.name == "Morning Energy Flow")
        try assertTrue(workout.category == .stretch)
        try assertTrue(workout.difficulty == .beginner)
        try assertTrue(workout.estimatedCalories == 110)
        try assertTrue(workout.requiredEquipment.contains(.yogaMat))
        try assertTrue(workout.exercises.count == 1)
        
        let exercise = workout.exercises[0]
        try assertTrue(exercise.name == "Sun Salutation")
        try assertTrue(exercise.targetMuscles.contains(.core))
        try assertTrue(exercise.equipment == .yogaMat)
        try assertTrue(exercise.durationSeconds == 120)
    }
    
    static func testNutritionResponseDTODecoding() throws {
        let jsonString = """
        {
          "suggestions": [
            {
              "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
              "food_item": {
                "id": "f1a2b3c4-d5e6-7890-abcd-ef0987654321",
                "name": "Masoor Dal",
                "item_description": "Home-cooked red lentil curry",
                "serving_size": 200.0,
                "serving_unit": "g",
                "calories": 198.0,
                "protein_grams": 13.0,
                "carbohydrates_grams": 30.0,
                "fat_grams": 3.0,
                "fibre_grams": 8.0,
                "category": "Nuts & Legumes",
                "data_source": "AI Estimated",
                "icon_symbol": "🍲"
              },
              "suggested_quantity": 1.5,
              "target_meal_type": "Dinner",
              "estimated_calories": 297.0,
              "estimated_protein_grams": 19.5,
              "estimated_carbohydrates_grams": 45.0,
              "estimated_fat_grams": 4.5,
              "recommendation_rationale": "High protein, budget friendly dinner."
            }
          ],
          "model_used": "llama-3.1-8b-instant",
          "generated_at": "2026-10-24T03:00:00Z"
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let dto = try JSONDecoder().decode(NutritionRecommendationResponseDTO.self, from: data)
        try assertTrue(dto.suggestions.count == 1)
        
        let suggestion = dto.suggestions[0].toDomain()
        try assertTrue(suggestion.foodItem.name == "Masoor Dal")
        try assertTrue(suggestion.foodItem.dataSource == .aiEstimated)
        try assertTrue(suggestion.foodItem.servingUnit == .grams)
        try assertTrue(suggestion.suggestedQuantity == 1.5)
        try assertTrue(suggestion.targetMealType == .dinner)
        try assertTrue(suggestion.estimatedCalories == 297.0)
        try assertTrue(suggestion.estimatedProteinGrams == 19.5)
    }
    
    static func testBackendErrorResponseDecoding() throws {
        let jsonString = """
        {
          "error": "Validation error: available_time_seconds must be at least 300.",
          "code": "validation_error"
        }
        """
        let data = jsonString.data(using: .utf8)!
        let errDTO = try JSONDecoder().decode(BackendErrorResponseDTO.self, from: data)
        try assertTrue(errDTO.code == "validation_error")
        try assertTrue(errDTO.error.contains("available_time_seconds"))
    }
    
    static func testMockURLProtocolSuccessWorkout() async throws {
        let responseJson = """
        {
          "workouts": [
            {
              "id": "e98e29a3-5c74-4b55-857a-9c7cb6414a93",
              "name": "Core Flow",
              "description": "Flow for core strength",
              "category": "Full Body Strength",
              "difficulty": "Intermediate",
              "estimated_duration_seconds": 600,
              "estimated_calories": 80,
              "required_equipment": ["None (Bodyweight)"],
              "exercises": []
            }
          ],
          "model_used": "llama-3.1-8b-instant",
          "generated_at": "2026-10-24T00:00:00Z"
        }
        """
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, responseJson.data(using: .utf8)!)
        }
        
        let session = makeMockSession()
        let client = RecommendationAPIClient(session: session, baseURLProvider: { URL(string: "http://127.0.0.1:8000")! })
        
        let input = WorkoutRecommendationInput(userProfile: UserProfile(name: "Priya"))
        let workouts = try await client.requestWorkouts(input: input)
        try assertTrue(workouts.count == 1)
        try assertTrue(workouts[0].name == "Core Flow")
        try assertTrue(workouts[0].category == .strength)
    }
    
    static func testMockURLProtocolSuccessNutrition() async throws {
        let responseJson = """
        {
          "suggestions": [
            {
              "id": "f29e29a3-5c74-4b55-857a-9c7cb6414a93",
              "food_item": {
                "id": "b29e29a3-5c74-4b55-857a-9c7cb6414a93",
                "name": "Moong Dal Khichdi",
                "serving_size": 150,
                "serving_unit": "g",
                "calories": 220,
                "protein_grams": 9,
                "carbohydrates_grams": 40,
                "fat_grams": 3,
                "data_source": "AI Estimated"
              },
              "suggested_quantity": 1.0,
              "target_meal_type": "Dinner",
              "estimated_calories": 220,
              "estimated_protein_grams": 9,
              "estimated_carbohydrates_grams": 40,
              "estimated_fat_grams": 3,
              "recommendation_rationale": "Easily digestible evening meal."
            }
          ]
        }
        """
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, responseJson.data(using: .utf8)!)
        }
        
        let session = makeMockSession()
        let client = RecommendationAPIClient(session: session, baseURLProvider: { URL(string: "http://127.0.0.1:8000")! })
        
        let input = NutritionRecommendationInput(userProfile: UserProfile(name: "Priya"))
        let suggestions = try await client.requestNutrition(input: input)
        try assertTrue(suggestions.count == 1)
        try assertTrue(suggestions[0].foodItem.name == "Moong Dal Khichdi")
    }
    
    static func testMockURLProtocolHTTP422ValidationError() async throws {
        let errorJson = """
        {
          "error": "Validation error: user_name is required.",
          "code": "validation_error"
        }
        """
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 422, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, errorJson.data(using: .utf8)!)
        }
        
        let session = makeMockSession()
        let client = RecommendationAPIClient(session: session, baseURLProvider: { URL(string: "http://127.0.0.1:8000")! })
        
        do {
            _ = try await client.requestWorkouts(input: WorkoutRecommendationInput(userProfile: UserProfile()))
            throw NSError(domain: "Expected Failure", code: 0)
        } catch let err as RecommendationNetworkError {
            guard case .serverError(let code, let msg, let errCode) = err else {
                throw NSError(domain: "WrongErrorType", code: 1)
            }
            try assertTrue(code == 422)
            try assertTrue(errCode == "validation_error")
            try assertTrue(msg.contains("user_name is required"))
        }
    }
    
    static func testMockURLProtocolHTTP503BusyError() async throws {
        let errorJson = """
        {
          "error": "Rate limit reached.",
          "code": "model_overloaded"
        }
        """
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, errorJson.data(using: .utf8)!)
        }
        
        let session = makeMockSession()
        let client = RecommendationAPIClient(session: session, baseURLProvider: { URL(string: "http://127.0.0.1:8000")! })
        
        do {
            _ = try await client.requestWorkouts(input: WorkoutRecommendationInput(userProfile: UserProfile()))
            throw NSError(domain: "Expected Failure", code: 0)
        } catch let err as RecommendationNetworkError {
            try assertTrue(err.localizedDescription.contains("temporarily busy"))
        }
    }
    
    static func testMockURLProtocolTimeout() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }
        
        let session = makeMockSession()
        let client = RecommendationAPIClient(session: session, baseURLProvider: { URL(string: "http://127.0.0.1:8000")! })
        
        do {
            _ = try await client.requestWorkouts(input: WorkoutRecommendationInput(userProfile: UserProfile()))
            throw NSError(domain: "Expected Failure", code: 0)
        } catch let err as RecommendationNetworkError {
            try assertTrue(err == .requestTimedOut)
        }
    }
    
    static func testMockURLProtocolMalformedJSON() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, "invalid json".data(using: .utf8)!)
        }
        
        let session = makeMockSession()
        let client = RecommendationAPIClient(session: session, baseURLProvider: { URL(string: "http://127.0.0.1:8000")! })
        
        do {
            _ = try await client.requestWorkouts(input: WorkoutRecommendationInput(userProfile: UserProfile()))
            throw NSError(domain: "Expected Failure", code: 0)
        } catch let err as RecommendationNetworkError {
            guard case .decodingFailed = err else {
                throw NSError(domain: "WrongErrorType", code: 1)
            }
        }
    }
    
    static func testInsecureConnectionEnforcement() async throws {
        let session = makeMockSession()
        // Non-local public HTTP host must be rejected
        let client = RecommendationAPIClient(session: session, baseURLProvider: { URL(string: "http://api.production-fitbuddy.com")! })
        
        do {
            _ = try await client.requestWorkouts(input: WorkoutRecommendationInput(userProfile: UserProfile()))
            throw NSError(domain: "Expected Failure", code: 0)
        } catch let err as RecommendationNetworkError {
            guard case .insecureConnectionNotAllowed = err else {
                throw NSError(domain: "WrongErrorType", code: 1)
            }
        }
    }
    
    static func testNetworkWorkoutServiceFallbackActive() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.cannotConnectToHost)
        }
        
        let session = makeMockSession()
        let client = RecommendationAPIClient(session: session, baseURLProvider: { URL(string: "http://127.0.0.1:8000")! })
        
        let service = NetworkWorkoutRecommendationService(
            apiClient: client,
            fallbackService: MockWorkoutRecommendationService(),
            enableOfflineFallback: true
        )
        
        let input = WorkoutRecommendationInput(userProfile: UserProfile(name: "Priya"))
        let workouts = try await service.recommendWorkouts(for: input)
        try assertTrue(!workouts.isEmpty)
        // Ensure fallback output is clearly marked
        try assertTrue(workouts[0].aiRecommendationRationale?.contains("[Offline Fallback]") == true, "Must be clearly tagged as fallback")
    }
    
    static func testNetworkWorkoutServiceThrowsWhenFallbackDisabled() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.cannotConnectToHost)
        }
        
        let session = makeMockSession()
        let client = RecommendationAPIClient(session: session, baseURLProvider: { URL(string: "http://127.0.0.1:8000")! })
        
        let service = NetworkWorkoutRecommendationService(
            apiClient: client,
            fallbackService: MockWorkoutRecommendationService(),
            enableOfflineFallback: false
        )
        
        let input = WorkoutRecommendationInput(userProfile: UserProfile(name: "Priya"))
        do {
            _ = try await service.recommendWorkouts(for: input)
            throw NSError(domain: "Expected Failure", code: 0)
        } catch {
            // Succeeded in throwing
        }
    }
    
    static func testNetworkNutritionServiceFallbackActive() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.cannotConnectToHost)
        }
        
        let session = makeMockSession()
        let client = RecommendationAPIClient(session: session, baseURLProvider: { URL(string: "http://127.0.0.1:8000")! })
        
        let service = NetworkNutritionRecommendationService(
            apiClient: client,
            fallbackService: MockNutritionRecommendationService(),
            enableOfflineFallback: true
        )
        
        let input = NutritionRecommendationInput(userProfile: UserProfile(name: "Priya"))
        let suggestions = try await service.recommendFoods(for: input)
        try assertTrue(!suggestions.isEmpty)
        try assertTrue(suggestions[0].recommendationRationale.contains("[Offline Fallback]"), "Must be clearly tagged as fallback")
    }
}
