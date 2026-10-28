import Foundation

/// Types of milestone reward passes in FitBuddy.
public enum RewardPassType: String, Codable, CaseIterable, Identifiable {
    case cheatMeal = "Cheat Meal Pass"
    case restDay = "Rest Day Pass"
    
    public var id: String { rawValue }
    
    public var iconSymbol: String {
        switch self {
        case .cheatMeal: return "🍔"
        case .restDay: return "⏳"
        }
    }
    
    public var requiredConsecutiveDays: Int {
        switch self {
        case .cheatMeal: return 3
        case .restDay: return 6
        }
    }
    
    public var description: String {
        switch self {
        case .cheatMeal:
            return "Motivational reward for 3 consecutive workout days. Does not modify your food log."
        case .restDay:
            return "Protects your streak for one scheduled rest day after 6 consecutive workout days."
        }
    }
}

/// Represents an earned reward pass in the user's inventory.
public struct EarnedRewardPass: Identifiable, Codable, Equatable {
    public let id: UUID
    public let passType: RewardPassType
    public let earnedDate: Date
    public var isRedeemed: Bool
    public var redeemedDate: Date?
    
    /// Unique milestone streak sequence token preventing duplicate grants for the same streak milestone
    public let qualifyingStreakToken: String
    
    public init(
        id: UUID = UUID(),
        passType: RewardPassType,
        earnedDate: Date = Date(),
        isRedeemed: Bool = false,
        redeemedDate: Date? = nil,
        qualifyingStreakToken: String
    ) {
        self.id = id
        self.passType = passType
        self.earnedDate = earnedDate
        self.isRedeemed = isRedeemed
        self.redeemedDate = redeemedDate
        self.qualifyingStreakToken = qualifyingStreakToken
    }
}

/// Category of XP balance transactions.
public enum XPTransactionType: String, Codable, Equatable {
    case workoutCompletion = "Workout Completed"
    case petFeeding = "Pet Feeding"
}

/// Persistent transaction record tracking XP earnings and spends.
public struct XPTransaction: Identifiable, Codable, Equatable {
    public let id: UUID
    public let type: XPTransactionType
    /// Positive for XP earned, negative for XP spent.
    public let amount: Int
    public let timestamp: Date
    public let note: String
    
    public init(
        id: UUID = UUID(),
        type: XPTransactionType,
        amount: Int,
        timestamp: Date = Date(),
        note: String
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.timestamp = timestamp
        self.note = note
    }
}

/// Overall user rewards inventory and XP profile state.
public struct RewardInventoryState: Codable, Equatable {
    public var totalXP: Int
    public var passes: [EarnedRewardPass]
    public var processedWorkoutIds: Set<UUID>
    public var redeemedRestDayDates: Set<Date>
    public var transactions: [XPTransaction]
    
    enum CodingKeys: String, CodingKey {
        case totalXP
        case passes
        case processedWorkoutIds
        case redeemedRestDayDates
        case transactions
    }
    
    public init(
        totalXP: Int = 0,
        passes: [EarnedRewardPass] = [],
        processedWorkoutIds: Set<UUID> = [],
        redeemedRestDayDates: Set<Date> = [],
        transactions: [XPTransaction] = []
    ) {
        self.totalXP = totalXP
        self.passes = passes
        self.processedWorkoutIds = processedWorkoutIds
        self.redeemedRestDayDates = redeemedRestDayDates
        self.transactions = transactions
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.totalXP = try container.decodeIfPresent(Int.self, forKey: .totalXP) ?? 0
        self.passes = try container.decodeIfPresent([EarnedRewardPass].self, forKey: .passes) ?? []
        self.processedWorkoutIds = try container.decodeIfPresent(Set<UUID>.self, forKey: .processedWorkoutIds) ?? []
        self.redeemedRestDayDates = try container.decodeIfPresent(Set<Date>.self, forKey: .redeemedRestDayDates) ?? []
        self.transactions = try container.decodeIfPresent([XPTransaction].self, forKey: .transactions) ?? []
    }
    
    /// User level derived from XP (Level = (totalXP / 100) + 1)
    public var currentLevel: Int {
        max(1, (totalXP / 100) + 1)
    }
    
    /// XP progress towards the next level (0 to 99)
    public var currentLevelXPProgress: Int {
        totalXP % 100
    }
    
    /// Count of available (unredeemed) passes for a given type
    public func availableCount(for type: RewardPassType) -> Int {
        passes.filter { $0.passType == type && !$0.isRedeemed }.count
    }
}
