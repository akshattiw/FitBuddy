import Foundation

/// User-recorded menstrual period entry.
/// Strictly separates recorded historical events from future statistical projections.
public struct PeriodEntry: Identifiable, Codable, Equatable {
    public let id: UUID
    public var startDate: Date
    public var endDate: Date?
    
    public init(id: UUID = UUID(), startDate: Date, endDate: Date? = nil) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
    }
    
    /// Checks whether a given calendar date falls within this recorded period.
    public func contains(date: Date, calendar: Calendar = .current) -> Bool {
        let start = calendar.startOfDay(for: startDate)
        let target = calendar.startOfDay(for: date)
        if let endDate = endDate {
            let end = calendar.startOfDay(for: endDate)
            return target >= start && target <= end
        } else {
            return target == start
        }
    }
}

/// Estimated prediction milestone for the next cycle.
/// Strictly identified as a statistical estimate and never medical certainty.
public struct CyclePrediction: Codable, Equatable {
    public let estimatedNextPeriodStart: Date
    public let estimatedFertileWindowStart: Date
    public let estimatedFertileWindowEnd: Date
    public let estimatedOvulationDate: Date
    public let confidenceLevel: String
    public let basedOnCycleCount: Int
    
    public init(
        estimatedNextPeriodStart: Date,
        estimatedFertileWindowStart: Date,
        estimatedFertileWindowEnd: Date,
        estimatedOvulationDate: Date,
        confidenceLevel: String,
        basedOnCycleCount: Int
    ) {
        self.estimatedNextPeriodStart = estimatedNextPeriodStart
        self.estimatedFertileWindowStart = estimatedFertileWindowStart
        self.estimatedFertileWindowEnd = estimatedFertileWindowEnd
        self.estimatedOvulationDate = estimatedOvulationDate
        self.confidenceLevel = confidenceLevel
        self.basedOnCycleCount = basedOnCycleCount
    }
}

/// Cycle data container holding user-logged period entries, symptoms, and settings.
/// Strictly decoupled from UserProfile.swift.
public struct CycleData: Codable, Equatable {
    /// User privacy preference: whether cycle tracking is active
    public var isTrackingEnabled: Bool
    
    /// User privacy preference: whether cycle data may inform workout intensity
    public var allowWorkoutAdaptation: Bool
    
    /// User-recorded average cycle length (in days, e.g. 28)
    public var averageCycleLengthDays: Int
    
    /// User-recorded average period duration (in days, e.g. 5)
    public var averagePeriodDurationDays: Int
    
    /// User-recorded period history
    public var periodEntries: [PeriodEntry]
    
    /// User-recorded symptom entries
    public var loggedSymptoms: [LoggedSymptom]
    
    public init(
        isTrackingEnabled: Bool = true,
        allowWorkoutAdaptation: Bool = false,
        averageCycleLengthDays: Int = 28,
        averagePeriodDurationDays: Int = 5,
        periodEntries: [PeriodEntry] = [],
        loggedSymptoms: [LoggedSymptom] = []
    ) {
        self.isTrackingEnabled = isTrackingEnabled
        self.allowWorkoutAdaptation = allowWorkoutAdaptation
        self.averageCycleLengthDays = max(20, min(45, averageCycleLengthDays))
        self.averagePeriodDurationDays = max(2, min(10, averagePeriodDurationDays))
        self.periodEntries = periodEntries
        self.loggedSymptoms = loggedSymptoms
    }
    
    // MARK: - Prediction Engine (Deterministic, statistical calculations)
    
    /// Calculates statistical estimates only when at least 1 verified period start is recorded.
    /// Returns nil if insufficient user history is available.
    public func calculatePredictions(calendar: Calendar = .current) -> CyclePrediction? {
        guard isTrackingEnabled else { return nil }
        guard let latestEntry = periodEntries.sorted(by: { $0.startDate < $1.startDate }).last else {
            return nil
        }
        
        let cycleDays = computeEffectiveCycleLength(calendar: calendar)
        guard let nextPeriod = calendar.date(byAdding: .day, value: cycleDays, to: latestEntry.startDate) else {
            return nil
        }
        
        // Typical luteal phase is approximately 14 days before next period
        guard let ovulation = calendar.date(byAdding: .day, value: -14, to: nextPeriod),
              let fertileStart = calendar.date(byAdding: .day, value: -4, to: ovulation),
              let fertileEnd = calendar.date(byAdding: .day, value: 1, to: ovulation) else {
            return nil
        }
        
        let confidence: String
        let historyCount = periodEntries.count
        if historyCount >= 3 {
            confidence = "Personalized (Based on \(historyCount) cycles)"
        } else {
            confidence = "Initial Estimate (Default \(cycleDays)-day interval)"
        }
        
        return CyclePrediction(
            estimatedNextPeriodStart: nextPeriod,
            estimatedFertileWindowStart: fertileStart,
            estimatedFertileWindowEnd: fertileEnd,
            estimatedOvulationDate: ovulation,
            confidenceLevel: confidence,
            basedOnCycleCount: historyCount
        )
    }
    
    /// Determines current estimated cycle phase for workout recommendations when user permitted.
    public func currentPhase(on date: Date = Date(), calendar: Calendar = .current) -> CyclePhase? {
        guard isTrackingEnabled && allowWorkoutAdaptation else { return nil }
        guard let latest = periodEntries.sorted(by: { $0.startDate < $1.startDate }).last else { return nil }
        
        let dayOfCycle = calendar.dateComponents([.day], from: calendar.startOfDay(for: latest.startDate), to: calendar.startOfDay(for: date)).day ?? 0
        if dayOfCycle < 0 { return nil }
        
        if dayOfCycle <= averagePeriodDurationDays {
            return .menstrual
        } else if dayOfCycle < 12 {
            return .follicular
        } else if dayOfCycle <= 16 {
            return .ovulatory
        } else {
            return .luteal
        }
    }
    
    /// Returns symptoms logged today or recently for workout adaptation.
    public func recentSymptomNames(on date: Date = Date(), calendar: Calendar = .current) -> [String] {
        guard isTrackingEnabled && allowWorkoutAdaptation else { return [] }
        let cutoff = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        return loggedSymptoms
            .filter { $0.date >= cutoff }
            .map { $0.type.rawValue }
    }
    
    // MARK: - Internal cycle interval calculation
    private func computeEffectiveCycleLength(calendar: Calendar) -> Int {
        let sorted = periodEntries.sorted(by: { $0.startDate < $1.startDate })
        guard sorted.count >= 2 else { return averageCycleLengthDays }
        
        var totalDays = 0
        var intervals = 0
        for i in 1..<sorted.count {
            let diff = calendar.dateComponents([.day], from: sorted[i - 1].startDate, to: sorted[i].startDate).day ?? 0
            if diff >= 21 && diff <= 45 {
                totalDays += diff
                intervals += 1
            }
        }
        return intervals > 0 ? (totalDays / intervals) : averageCycleLengthDays
    }
}
