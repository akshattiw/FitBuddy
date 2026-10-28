import SwiftUI

/// Shared observable store for completed workout records across the app lifecycle.
/// Follows AGENTS.md rule 8 (Single Source of Truth) and keeps tracking independent of AI (rule 11).
@Observable
public final class WorkoutHistoryStore {
    public var records: [WorkoutRecord]
    public var onDidChange: (() -> Void)?
    
    public init(records: [WorkoutRecord] = []) {
        self.records = records
    }
    
    /// Records a genuinely completed workout session.
    public func addRecord(_ record: WorkoutRecord) {
        records.append(record)
        records.sort(by: { $0.endDate > $1.endDate })
        onDidChange?()
    }
    
    /// Returns workouts completed within a given date range.
    public func records(from startDate: Date, to endDate: Date) -> [WorkoutRecord] {
        records.filter { $0.endDate >= startDate && $0.endDate <= endDate }
    }
    
    /// Total workouts completed.
    public var totalWorkoutsCompleted: Int {
        records.count
    }
    
    /// Total duration in seconds across all completed workouts.
    public var totalDurationSeconds: TimeInterval {
        records.reduce(0) { $0 + $1.actualDurationSeconds }
    }
}
