import Foundation

/// Streak statistics computed deterministically from workout completion history.
public struct StreakStats: Equatable {
    public let currentStreakDays: Int
    public let bestStreakDays: Int
    public let isWorkoutCompletedToday: Bool
    public let activeDatesThisMonth: Set<Date>
    
    public init(
        currentStreakDays: Int,
        bestStreakDays: Int,
        isWorkoutCompletedToday: Bool,
        activeDatesThisMonth: Set<Date>
    ) {
        self.currentStreakDays = currentStreakDays
        self.bestStreakDays = bestStreakDays
        self.isWorkoutCompletedToday = isWorkoutCompletedToday
        self.activeDatesThisMonth = activeDatesThisMonth
    }
}

/// Service handling deterministic XP awards, streak calculations, and milestone pass grants.
/// Independent of SwiftUI view bodies, SwiftData, and AI networks.
public struct RewardService {
    
    public init() {}
    
    // MARK: - XP Rules
    
    /// Awards 50 baseline XP per completed workout + 1 bonus XP per full minute of active exercise duration.
    /// Only processes workouts that have not previously been awarded XP.
    /// Records an immutable audit transaction for each completed workout.
    public func processNewWorkoutsForXP(
        records: [WorkoutRecord],
        state: inout RewardInventoryState
    ) {
        for record in records {
            guard !state.processedWorkoutIds.contains(record.id) else { continue }
            
            // Mark processed to prevent duplicate awards
            state.processedWorkoutIds.insert(record.id)
            
            let minutes = Int(record.actualDurationSeconds / 60)
            let earnedXP = 50 + minutes
            state.totalXP += earnedXP
            
            state.transactions.append(
                XPTransaction(
                    type: .workoutCompletion,
                    amount: earnedXP,
                    timestamp: record.endDate,
                    note: "\(record.workoutName) (+50 base, +\(minutes) min bonus)"
                )
            )
        }
    }
    
    /// Safely deducts XP from the authoritative balance without allowing negative balances.
    /// Returns true if the deduction was successful, false if insufficient XP or invalid amount.
    /// Records an immutable audit transaction when note is provided.
    public func spendXP(
        amount: Int,
        state: inout RewardInventoryState,
        timestamp: Date = Date(),
        note: String = "Fed pet companion"
    ) -> Bool {
        guard amount > 0, state.totalXP >= amount else { return false }
        state.totalXP -= amount
        state.transactions.append(
            XPTransaction(
                type: .petFeeding,
                amount: -amount,
                timestamp: timestamp,
                note: note
            )
        )
        return true
    }
    
    // MARK: - Streak Calculation
    
    /// Computes current and best streak using user's local calendar and actual completion dates.
    /// Incorporates redeemed rest day dates to protect streaks without falsely claiming workouts.
    public func calculateStreaks(
        records: [WorkoutRecord],
        redeemedRestDates: Set<Date>,
        calendar: Calendar = .current,
        referenceDate: Date = Date()
    ) -> StreakStats {
        // Collect all distinct days with a completed workout
        let workoutDaysSet: Set<Date> = Set(records.map { calendar.startOfDay(for: $0.endDate) })
        let restDaysSet: Set<Date> = Set(redeemedRestDates.map { calendar.startOfDay(for: $0) })
        
        let today = calendar.startOfDay(for: referenceDate)
        let isTodayDone = workoutDaysSet.contains(today)
        
        // Days that count toward continuing the streak (either worked out or protected by rest pass)
        let qualifiedDays = workoutDaysSet.union(restDaysSet)
        
        // Compute Current Streak
        var currentStreak = 0
        // If today has activity, streak starts from today; otherwise starts from yesterday
        var checkDate = isTodayDone ? today : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)
        
        while qualifiedDays.contains(checkDate) {
            currentStreak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previous
        }
        
        // Compute Best Streak across full historical timeline
        let sortedDays = qualifiedDays.sorted()
        var bestStreak = 0
        var tempStreak = 0
        var prevDate: Date? = nil
        
        for day in sortedDays {
            if let prev = prevDate {
                let diff = calendar.dateComponents([.day], from: prev, to: day).day ?? 0
                if diff == 1 {
                    tempStreak += 1
                } else {
                    tempStreak = 1
                }
            } else {
                tempStreak = 1
            }
            prevDate = day
            bestStreak = max(bestStreak, tempStreak)
        }
        bestStreak = max(bestStreak, currentStreak)
        
        // Active dates for reference month
        let monthComps = calendar.dateComponents([.year, .month], from: referenceDate)
        let activeThisMonth = workoutDaysSet.filter { date in
            let c = calendar.dateComponents([.year, .month], from: date)
            return c.year == monthComps.year && c.month == monthComps.month
        }
        
        return StreakStats(
            currentStreakDays: currentStreak,
            bestStreakDays: bestStreak,
            isWorkoutCompletedToday: isTodayDone,
            activeDatesThisMonth: activeThisMonth
        )
    }
    
    // MARK: - Milestone Pass Grants
    
    /// Evaluates current streak and grants milestone passes (Cheat Meal at 3 days, Rest Day at 6 days).
    /// Uses deterministic milestone streak tokens to ensure each milestone is granted strictly once.
    public func evaluateMilestonePasses(
        streakStats: StreakStats,
        state: inout RewardInventoryState,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) {
        let currentStreak = streakStats.currentStreakDays
        let today = calendar.startOfDay(for: referenceDate)
        let streakCycle = currentStreak / 3
        
        // 3-Day Milestone (Cheat Meal Pass)
        if currentStreak >= 3 {
            let token = "streak-3-cycle-\(streakCycle)-\(calendar.component(.year, from: today))"
            if !state.passes.contains(where: { $0.qualifyingStreakToken == token }) {
                let pass = EarnedRewardPass(
                    passType: .cheatMeal,
                    earnedDate: referenceDate,
                    qualifyingStreakToken: token
                )
                state.passes.append(pass)
            }
        }
        
        // 6-Day Milestone (Rest Day Pass)
        if currentStreak >= 6 {
            let restCycle = currentStreak / 6
            let token = "streak-6-cycle-\(restCycle)-\(calendar.component(.year, from: today))"
            if !state.passes.contains(where: { $0.qualifyingStreakToken == token }) {
                let pass = EarnedRewardPass(
                    passType: .restDay,
                    earnedDate: referenceDate,
                    qualifyingStreakToken: token
                )
                state.passes.append(pass)
            }
        }
    }
    
    // MARK: - Redemption
    
    /// Redeems an available pass of the given type.
    /// If Rest Day Pass, adds designated rest date to preserve streak without recording a false workout.
    public func redeemPass(
        type: RewardPassType,
        targetRestDate: Date? = nil,
        state: inout RewardInventoryState
    ) -> Bool {
        guard let index = state.passes.firstIndex(where: { $0.passType == type && !$0.isRedeemed }) else {
            return false
        }
        
        state.passes[index].isRedeemed = true
        state.passes[index].redeemedDate = Date()
        
        if type == .restDay, let restDate = targetRestDate {
            state.redeemedRestDayDates.insert(restDate)
        }
        
        return true
    }
}
