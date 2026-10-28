import SwiftUI

/// Observable store managing user reward inventory, XP, and streak calculations.
/// Decouples rewards state and calculations from view hierarchies.
@Observable
public final class RewardStore {
    public var state: RewardInventoryState
    public let service: RewardService
    public var onDidChange: (() -> Void)?
    
    public init(
        state: RewardInventoryState = RewardInventoryState(),
        service: RewardService = RewardService()
    ) {
        self.state = state
        self.service = service
    }
    
    /// Synchronizes XP and milestone passes against completed workout records.
    public func synchronize(with records: [WorkoutRecord], calendar: Calendar = .current) {
        service.processNewWorkoutsForXP(records: records, state: &state)
        let stats = service.calculateStreaks(
            records: records,
            redeemedRestDates: state.redeemedRestDayDates,
            calendar: calendar
        )
        service.evaluateMilestonePasses(streakStats: stats, state: &state, calendar: calendar)
        onDidChange?()
    }
    
    /// Computes streak metrics for a specific reference date.
    public func streakStats(records: [WorkoutRecord], calendar: Calendar = .current, referenceDate: Date = Date()) -> StreakStats {
        service.calculateStreaks(
            records: records,
            redeemedRestDates: state.redeemedRestDayDates,
            calendar: calendar,
            referenceDate: referenceDate
        )
    }
    
    /// Redeems an available pass of the given type.
    @discardableResult
    public func redeem(type: RewardPassType, targetRestDate: Date? = nil) -> Bool {
        let success = service.redeemPass(type: type, targetRestDate: targetRestDate, state: &state)
        if success {
            onDidChange?()
        }
        return success
    }
    
    /// Deducts XP from the authoritative balance if sufficient funds exist.
    /// Returns true if deduction succeeded, false if balance was insufficient.
    @discardableResult
    public func spendXP(amount: Int, timestamp: Date = Date(), note: String = "Fed pet companion") -> Bool {
        let success = service.spendXP(amount: amount, state: &state, timestamp: timestamp, note: note)
        if success {
            onDidChange?()
        }
        return success
    }
}
