import Foundation

/// Centralized configuration for FitBuddy's network environment and AI recommendation backend.
/// Strictly follows AGENTS.md Rule 12: Zero permanent API keys or secrets in the client codebase.
nonisolated public enum AppBackendConfig {
    
    /// Environment variable key used to override backend base URL during development or UI testing.
    public static let environmentVariableKey = "FITBUDDY_BACKEND_BASE_URL"
    
    /// Info.plist key used to define backend base URL in build configurations.
    public static let infoPlistKey = "FITBUDDY_BACKEND_BASE_URL"
    
    /// Default development URL pointing to local proxy / backend service.
    /// Note: This is an explicit local development address; production builds require HTTPS.
    public static let defaultDevelopmentBaseURL = URL(string: "http://127.0.0.1:8000")!
    
    /// Resolves the current backend base URL based on environment variables, Info.plist, or fallback.
    nonisolated public static var currentBaseURL: URL {
        // 1. Process environment variable (e.g. Xcode scheme environment variable FITBUDDY_BACKEND_BASE_URL)
        if let envString = ProcessInfo.processInfo.environment[environmentVariableKey],
           let envURL = URL(string: envString.trimmingCharacters(in: .whitespacesAndNewlines)),
           isValidURL(envURL) {
            return envURL
        }
        
        // 2. Info.plist configuration (e.g. bundle setting per build configuration)
        if let plistString = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String,
           let plistURL = URL(string: plistString.trimmingCharacters(in: .whitespacesAndNewlines)),
           isValidURL(plistURL) {
            return plistURL
        }
        
        // 3. Fallback to default local development base URL
        return defaultDevelopmentBaseURL
    }
    
    /// API Version 1 endpoint paths conforming to the backend contract.
    nonisolated public enum Endpoints {
        public static let workoutRecommendations = "/api/v1/workout/recommendations"
        public static let nutritionRecommendations = "/api/v1/nutrition/recommendations"
        public static let health = "/api/v1/health"
    }
    
    /// Resolves full URL for workout recommendations.
    nonisolated public static func workoutEndpointURL(baseURL: URL = currentBaseURL) -> URL? {
        URL(string: Endpoints.workoutRecommendations, relativeTo: baseURL)?.absoluteURL
    }
    
    /// Resolves full URL for nutrition recommendations.
    nonisolated public static func nutritionEndpointURL(baseURL: URL = currentBaseURL) -> URL? {
        URL(string: Endpoints.nutritionRecommendations, relativeTo: baseURL)?.absoluteURL
    }
    
    /// Resolves full URL for backend health check.
    nonisolated public static func healthEndpointURL(baseURL: URL = currentBaseURL) -> URL? {
        URL(string: Endpoints.health, relativeTo: baseURL)?.absoluteURL
    }
    
    /// Validates whether a given URL meets basic scheme and host criteria.
    public static func isValidURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), (scheme == "https" || scheme == "http") else {
            return false
        }
        guard let host = url.host, !host.isEmpty else {
            return false
        }
        return true
    }
    
    /// Enforces HTTPS requirement for non-local production hosts.
    /// Localhost/127.0.0.1 and private LAN networks (192.168.x, 10.x, .local) are permitted for developer testing.
    public static func requiresSecureTransport(for url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return true }
        let isLoopback = host == "localhost" || host == "127.0.0.1" || host == "::1"
        let isLocalNetwork = host.hasSuffix(".local")
            || host.hasPrefix("192.168.")
            || host.hasPrefix("10.")
            || isPrivate172(host)
        return !(isLoopback || isLocalNetwork)
    }
    
    private static func isPrivate172(_ host: String) -> Bool {
        guard host.hasPrefix("172.") else { return false }
        let parts = host.split(separator: ".")
        guard parts.count >= 2, let secondOctet = Int(parts[1]) else { return false }
        return secondOctet >= 16 && secondOctet <= 31
    }
}
