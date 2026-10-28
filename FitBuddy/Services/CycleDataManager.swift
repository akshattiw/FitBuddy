import SwiftUI

/// Observable store managing user cycle data, period logging, and symptom history.
/// Decouples cycle tracking state and predictions from SwiftUI view bodies.
@Observable
public final class CycleDataManager {
    public var data: CycleData
    public var onDidChange: (() -> Void)?
    
    public init(data: CycleData = CycleData()) {
        self.data = data
    }
    
    /// Records a new period start or updates an existing entry.
    public func logPeriod(startDate: Date, endDate: Date? = nil, calendar: Calendar = .current) {
        let startDay = calendar.startOfDay(for: startDate)
        
        // Prevent duplicate record for the same starting day
        if let index = data.periodEntries.firstIndex(where: { calendar.isDate($0.startDate, inSameDayAs: startDay) }) {
            data.periodEntries[index].endDate = endDate
        } else {
            let entry = PeriodEntry(startDate: startDay, endDate: endDate.map { calendar.startOfDay(for: $0) })
            data.periodEntries.append(entry)
            data.periodEntries.sort(by: { $0.startDate < $1.startDate })
        }
        onDidChange?()
    }
    
    /// Deletes a period entry.
    public func deletePeriod(id: UUID) {
        data.periodEntries.removeAll { $0.id == id }
        onDidChange?()
    }
    
    /// Logs a symptom with date and intensity.
    public func logSymptom(type: CycleSymptomType, intensity: SymptomIntensity = .mild, date: Date = Date(), notes: String? = nil) {
        let entry = LoggedSymptom(type: type, intensity: intensity, date: date, notes: notes)
        data.loggedSymptoms.append(entry)
        onDidChange?()
    }
    
    /// Removes a logged symptom.
    public func deleteSymptom(id: UUID) {
        data.loggedSymptoms.removeAll { $0.id == id }
        onDidChange?()
    }
    
    /// Toggles cycle tracking enabled state (does not erase historical data).
    public func toggleTracking(enabled: Bool) {
        data.isTrackingEnabled = enabled
        onDidChange?()
    }
    
    /// Toggles whether cycle data informs workout recommendation intensity.
    public func toggleWorkoutAdaptation(allowed: Bool) {
        data.allowWorkoutAdaptation = allowed
        onDidChange?()
    }
    
    /// Current calculated predictions (returns nil if insufficient data).
    public var predictions: CyclePrediction? {
        data.calculatePredictions()
    }
}
