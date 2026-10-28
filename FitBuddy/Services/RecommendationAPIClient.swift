import Foundation

/// Protocol abstraction for communicating with the FitBuddy FastAPI recommendation service.
public protocol RecommendationAPIClientProtocol: Sendable {
    /// Dispatches a request for workout recommendations matching the input parameters.
    func requestWorkouts(input: WorkoutRecommendationInput) async throws -> [Workout]
    
    /// Dispatches a request for nutrition recommendations matching the input parameters.
    func requestNutrition(input: NutritionRecommendationInput) async throws -> [FoodSuggestion]
    
    /// Checks operational health of the backend server.
    func checkHealth() async throws -> Bool
}

/// Concrete network client using `URLSession` to communicate with the FitBuddy FastAPI backend.
/// Strictly follows AGENTS.md rules: zero embedded secrets, no direct third-party AI calls from iOS.
public final class RecommendationAPIClient: RecommendationAPIClientProtocol, @unchecked Sendable {
    
    private let session: URLSession
    private let baseURLProvider: @Sendable () -> URL
    
    /// Initializes the API client with an optional custom `URLSession` and base URL provider.
    public init(
        session: URLSession? = nil,
        baseURLProvider: @escaping @Sendable () -> URL = { AppBackendConfig.currentBaseURL }
    ) {
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30.0
            config.timeoutIntervalForResource = 60.0
            config.waitsForConnectivity = false
            self.session = URLSession(configuration: config)
        }
        self.baseURLProvider = baseURLProvider
    }
    
    // MARK: - Workout Recommendations
    
    public func requestWorkouts(input: WorkoutRecommendationInput) async throws -> [Workout] {
        try Task.checkCancellation()
        
        let baseURL = baseURLProvider()
        guard let endpointURL = AppBackendConfig.workoutEndpointURL(baseURL: baseURL) else {
            throw RecommendationNetworkError.invalidURL
        }
        
        // Security rule: Ensure non-local connections enforce HTTPS
        if AppBackendConfig.requiresSecureTransport(for: endpointURL) && endpointURL.scheme?.lowercased() != "https" {
            throw RecommendationNetworkError.insecureConnectionNotAllowed(endpointURL.host ?? "unknown")
        }
        
        let dto = WorkoutRecommendationRequestDTO(from: input)
        let bodyData: Data
        do {
            bodyData = try JSONEncoder().encode(dto)
        } catch {
            throw RecommendationNetworkError.requestEncodingFailed(error.localizedDescription)
        }
        
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = bodyData
        
        let data = try await performRequest(request)
        
        do {
            let responseDTO = try JSONDecoder().decode(WorkoutRecommendationResponseDTO.self, from: data)
            return responseDTO.workouts.map { $0.toDomain() }
        } catch {
            throw RecommendationNetworkError.decodingFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Nutrition Recommendations
    
    public func requestNutrition(input: NutritionRecommendationInput) async throws -> [FoodSuggestion] {
        try Task.checkCancellation()
        
        let baseURL = baseURLProvider()
        guard let endpointURL = AppBackendConfig.nutritionEndpointURL(baseURL: baseURL) else {
            throw RecommendationNetworkError.invalidURL
        }
        
        // Security rule: Ensure non-local connections enforce HTTPS
        if AppBackendConfig.requiresSecureTransport(for: endpointURL) && endpointURL.scheme?.lowercased() != "https" {
            throw RecommendationNetworkError.insecureConnectionNotAllowed(endpointURL.host ?? "unknown")
        }
        
        let dto = NutritionRecommendationRequestDTO(from: input)
        let bodyData: Data
        do {
            bodyData = try JSONEncoder().encode(dto)
        } catch {
            throw RecommendationNetworkError.requestEncodingFailed(error.localizedDescription)
        }
        
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = bodyData
        
        let data = try await performRequest(request)
        
        do {
            let responseDTO = try JSONDecoder().decode(NutritionRecommendationResponseDTO.self, from: data)
            return responseDTO.suggestions.map { $0.toDomain() }
        } catch {
            throw RecommendationNetworkError.decodingFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Health Check
    
    public func checkHealth() async throws -> Bool {
        let baseURL = baseURLProvider()
        guard let endpointURL = AppBackendConfig.healthEndpointURL(baseURL: baseURL) else {
            return false
        }
        
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let data = try await performRequest(request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String, status == "ok" {
                return true
            }
            return false
        } catch {
            return false
        }
    }
    
    // MARK: - Core Request Executor
    
    private func performRequest(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                throw RecommendationNetworkError.requestTimedOut
            } else if urlError.code == .cancelled {
                throw RecommendationNetworkError.cancelled
            } else {
                throw RecommendationNetworkError.connectivityFailed(urlError.localizedDescription)
            }
        } catch {
            throw RecommendationNetworkError.connectivityFailed(error.localizedDescription)
        }
        
        try Task.checkCancellation()
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RecommendationNetworkError.invalidResponse
        }
        
        if (200...299).contains(httpResponse.statusCode) {
            return data
        }
        
        // Attempt to parse structured error response from backend
        var errorMessage = ""
        var errorCode: String? = nil
        if let errorDTO = try? JSONDecoder().decode(BackendErrorResponseDTO.self, from: data) {
            errorMessage = errorDTO.error
            errorCode = errorDTO.code
        } else if let rawString = String(data: data, encoding: .utf8), !rawString.isEmpty {
            errorMessage = rawString
        }
        
        throw RecommendationNetworkError.serverError(
            statusCode: httpResponse.statusCode,
            message: errorMessage,
            code: errorCode
        )
    }
}
