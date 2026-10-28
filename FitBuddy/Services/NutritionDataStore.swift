import SwiftUI

/// Observable store managing user food intake logs and daily nutrition targets.
/// Provides a single source of truth for DietView and persistent storage.
@Observable
public final class NutritionDataStore {
    public var targets: NutritionTargets
    public var loggedItems: [FoodLog]
    public var onDidChange: (() -> Void)?
    
    public init(
        targets: NutritionTargets = NutritionTargets(
            dailyCalorieTarget: 2160,
            proteinGramsTarget: 140,
            carbohydratesGramsTarget: 200,
            fatGramsTarget: 65
        ),
        loggedItems: [FoodLog] = []
    ) {
        self.targets = targets
        self.loggedItems = loggedItems
    }
    
    /// Records a new food log entry.
    public func addFoodLog(_ log: FoodLog) {
        loggedItems.append(log)
        loggedItems.sort(by: { $0.loggedAt > $1.loggedAt })
        onDidChange?()
    }
    
    /// Deletes a logged entry.
    public func deleteFoodLog(id: UUID) {
        loggedItems.removeAll { $0.id == id }
        onDidChange?()
    }
    
    /// Computes deterministic daily summary for a given date.
    public func summary(for date: Date = Date(), calendar: Calendar = .current) -> NutritionSummary {
        NutritionSummary.calculate(for: date, logs: loggedItems, targets: targets, calendar: calendar)
    }
}
