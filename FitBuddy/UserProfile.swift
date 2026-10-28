import SwiftUI

/// Gender options for user profile representation.
public enum UserGender: String, Codable, CaseIterable, Identifiable {
    case female = "Female"
    case male = "Male"
    case other = "Other"
    case preferNotToSay = "Prefer not to say"
    
    public var id: String { rawValue }
    
    /// Whether this gender profile enables menstrual cycle tracking.
    public var enablesCycleTracking: Bool {
        self == .female
    }
}

/// Minimal user profile representation for FitBuddy following AGENTS.md single-source-of-truth rules.
/// Kept separate from cycle tracking data and services.
public struct UserProfile: Codable, Equatable {
    public var name: String
    public var gender: UserGender?
    
    public init(name: String = "", gender: UserGender? = nil) {
        self.name = name
        self.gender = gender
    }
}

/// Observable state manager for user profile, allowing reactive tab bar and navigation updates.
@Observable
public final class UserProfileManager {
    public var profile: UserProfile {
        didSet {
            onDidChange?()
        }
    }
    public var onDidChange: (() -> Void)?
    
    public init(profile: UserProfile = UserProfile(gender: nil)) {
        self.profile = profile
    }
    
    /// Returns whether the Cycle tab should be visible based strictly on explicit Female gender.
    public var isCycleTrackingEnabled: Bool {
        profile.gender?.enablesCycleTracking ?? false
    }
}
