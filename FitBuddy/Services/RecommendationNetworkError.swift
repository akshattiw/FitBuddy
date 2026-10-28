import Foundation

/// Specific, typed errors encountered during recommendation API communication.
public enum RecommendationNetworkError: LocalizedError, Equatable {
    case invalidURL
    case insecureConnectionNotAllowed(String)
    case requestEncodingFailed(String)
    case connectivityFailed(String)
    case requestTimedOut
    case serverError(statusCode: Int, message: String, code: String?)
    case invalidResponse
    case decodingFailed(String)
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid recommendation server URL configuration."
        case .insecureConnectionNotAllowed(let host):
            return "Insecure connection is not allowed for host '\(host)'. HTTPS is required."
        case .requestEncodingFailed(let message):
            return "Failed to prepare request: \(message)"
        case .connectivityFailed(let message):
            return "Unable to connect to recommendation server. Please check your network connection: \(message)"
        case .requestTimedOut:
            return "Recommendation request timed out. Please try again."
        case .serverError(let statusCode, let message, _):
            if statusCode == 503 {
                return "The recommendation service is temporarily busy. Please try again in a moment."
            }
            return message.isEmpty ? "Recommendation server error (HTTP \(statusCode))." : message
        case .invalidResponse:
            return "Received an unexpected response from the recommendation service."
        case .decodingFailed(let message):
            return "Failed to parse recommendations from server: \(message)"
        case .cancelled:
            return "Recommendation request was cancelled."
        }
    }
}
