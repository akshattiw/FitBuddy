import Foundation

/// Configurable constants governing pet companion rules.
public enum PetCompanionConstants {
    /// The authoritative XP cost required to feed a companion pet once.
    public static let feedingXPCost: Int = 10
    
    /// Starvation threshold: 3 full elapsed days (72 hours) without a successful feed.
    public static let starvationDuration: TimeInterval = 72 * 3600
}

/// Result of attempting to feed a companion pet.
public enum FeedPetResult: Equatable {
    case success(newLevel: Int, petName: String)
    case petNotFound
    case petLocked
    case petNotAlive
    case insufficientXP(currentXP: Int, requiredXP: Int)
    case alreadyProcessing
    
    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

/// Type of artwork resource used by a pet companion.
public enum PetArtworkKind: String, Codable, Equatable, Hashable {
    case gif
    case systemSymbol
}

/// Strongly typed artwork descriptor for a pet companion.
public struct PetArtwork: Codable, Equatable, Hashable {
    public var kind: PetArtworkKind
    public var identifier: String
    public var symbolTintHex: String?
    
    public init(kind: PetArtworkKind, identifier: String, symbolTintHex: String? = nil) {
        self.kind = kind
        self.identifier = identifier
        self.symbolTintHex = symbolTintHex
    }
}

/// Typed condition required to unlock a locked pet companion.
public enum PetUnlockRequirement: Codable, Equatable, Hashable {
    case `default`
    case completeWorkouts(count: Int)
    case maintainStreak(days: Int)
    case earnXP(amount: Int)
    case level(level: Int)
    
    public var displayTitle: String {
        switch self {
        case .default:
            return "Starter Companion"
        case .completeWorkouts(let count):
            return "Complete \(count) Workouts"
        case .maintainStreak(let days):
            return "\(days)-Day Streak"
        case .earnXP(let amount):
            return "Earn \(amount) XP"
        case .level(let lvl):
            return "Reach Level \(lvl)"
        }
    }
    
    public var explanation: String {
        switch self {
        case .default:
            return "Unlocked by default as your starter companion."
        case .completeWorkouts(let count):
            return "Log and complete at least \(count) workout sessions in FitBuddy."
        case .maintainStreak(let days):
            return "Maintain a consistent workout streak for \(days) consecutive days."
        case .earnXP(let amount):
            return "Accumulate a total of \(amount) XP through workouts and activity milestones."
        case .level(let lvl):
            return "Advance your FitBuddy user profile to Level \(lvl)."
        }
    }
}

/// Life status of the pet companion. Supports vitality stages and deceased state.
public enum PetLifeStatus: String, Codable, CaseIterable, Equatable {
    case healthy = "Healthy"
    case energized = "Energized"
    case resting = "Resting"
    case hungry = "Hungry"
    case starving = "Starving"
    case exhausted = "Exhausted"
    case deceased = "Passed Away"
    
    public var displayLabel: String { rawValue }
    
    public var isAlive: Bool {
        return self != .deceased
    }
}

/// Domain model representing a virtual pet companion in FitBuddy.
public struct Pet: Identifiable, Codable, Equatable, Hashable {
    /// Stable, human-readable unique identifier (e.g. "misskalem_cat", "shiba_inu").
    public let id: String
    
    /// Given or canonical pet name (e.g. "Kuro", "Mochi").
    public var name: String
    
    /// Friendly display title / species descriptor (e.g. "Shadow Cat", "Sunny Shiba").
    public var displayName: String
    
    /// Artwork descriptor referencing bundled GIF or native illustration.
    public var artwork: PetArtwork
    
    /// Short personality description.
    public var description: String
    
    /// Whether the user has unlocked this pet.
    public var isUnlocked: Bool
    
    /// Whether this pet is currently the user's active companion.
    public var isActive: Bool
    
    /// Current pet level (starts at 1 upon ownership).
    public var level: Int
    
    /// Typed unlock requirement for unlocking this pet.
    public var unlockRequirement: PetUnlockRequirement
    
    /// Current vitality/life status.
    public var status: PetLifeStatus
    
    // Extensibility fields for future feeding, XP, and progression
    public var experiencePoints: Int
    public var lastFedDate: Date?
    public var unlockedDate: Date?
    
    public init(
        id: String,
        name: String,
        displayName: String,
        artwork: PetArtwork,
        description: String,
        isUnlocked: Bool = false,
        isActive: Bool = false,
        level: Int = 1,
        unlockRequirement: PetUnlockRequirement = .default,
        status: PetLifeStatus = .healthy,
        experiencePoints: Int = 0,
        lastFedDate: Date? = nil,
        unlockedDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.artwork = artwork
        self.description = description
        self.isUnlocked = isUnlocked
        self.isActive = isActive
        self.level = max(1, level)
        self.unlockRequirement = unlockRequirement
        self.status = status
        self.experiencePoints = experiencePoints
        self.lastFedDate = lastFedDate
        self.unlockedDate = unlockedDate
    }
    
    /// Calculates remaining time before starvation at a given reference date.
    /// Returns 0 if already past deadline or if pet is deceased.
    public func remainingTimeUntilStarvation(at referenceDate: Date = Date()) -> TimeInterval {
        guard status.isAlive, let lastFed = lastFedDate else {
            return 0
        }
        let deadline = lastFed.addingTimeInterval(PetCompanionConstants.starvationDuration)
        return max(0, deadline.timeIntervalSince(referenceDate))
    }
    
    /// Evaluates vitality/hunger status based on elapsed time since `lastFedDate`.
    public func evaluatedLifeStatus(at referenceDate: Date = Date()) -> PetLifeStatus {
        // If already persisted as deceased, preserve death state permanently
        if status == .deceased {
            return .deceased
        }
        
        guard let lastFed = lastFedDate else {
            // Missing legacy timestamp or newly initialized: keep current living status safely
            return status.isAlive ? status : .healthy
        }
        
        let elapsed = referenceDate.timeIntervalSince(lastFed)
        if elapsed >= PetCompanionConstants.starvationDuration {
            return .deceased
        } else if elapsed >= 48 * 3600 {
            return .starving
        } else if elapsed >= 24 * 3600 {
            return .hungry
        } else {
            return status == .deceased ? .healthy : status
        }
    }
}

/// Persistent state container for all pets in the user's collection.
public struct PetInventoryState: Codable, Equatable {
    public var pets: [Pet]
    public var activePetId: String
    
    public init(
        pets: [Pet] = [],
        activePetId: String = "misskalem_cat"
    ) {
        self.pets = pets
        self.activePetId = activePetId
    }
    
    public var activePet: Pet? {
        pets.first(where: { $0.id == activePetId }) ?? pets.first(where: { $0.isUnlocked })
    }
    
    public var ownedPets: [Pet] {
        pets.filter { $0.isUnlocked }
    }
    
    public var lockedPets: [Pet] {
        pets.filter { !$0.isUnlocked }
    }
}
