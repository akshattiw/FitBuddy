import Foundation

/// Snapshot of baseline nutritional values per serving, captured at the moment of logging.
/// Guarantees that historical log entries remain permanently accurate even if the reusable
/// master `FoodItem` definition is later edited or updated.
public struct FoodNutritionalSnapshot: Codable, Equatable {
    public let foodName: String
    public let servingSize: Double
    public let servingUnit: ServingUnit
    public let caloriesPerServing: Double
    public let proteinGramsPerServing: Double
    public let carbohydratesGramsPerServing: Double
    public let fatGramsPerServing: Double
    public let fibreGramsPerServing: Double?
    public let iconSymbol: String?
    
    public init(from item: FoodItem) {
        self.foodName = item.name
        self.servingSize = item.servingSize
        self.servingUnit = item.servingUnit
        self.caloriesPerServing = item.calories
        self.proteinGramsPerServing = item.proteinGrams
        self.carbohydratesGramsPerServing = item.carbohydratesGrams
        self.fatGramsPerServing = item.fatGrams
        self.fibreGramsPerServing = item.fibreGrams
        self.iconSymbol = item.iconSymbol
    }
}

/// Food log entry representing food actually consumed and recorded by the user.
public struct FoodLog: Identifiable, Codable, Equatable {
    public let id: UUID
    
    /// Reference to the originating food item ID (if known)
    public let foodItemId: UUID?
    
    /// Immutable nutritional snapshot captured at log creation
    public let snapshot: FoodNutritionalSnapshot
    
    /// Multiplier representing how many servings were consumed (e.g. 1.5 servings)
    public var servingQuantity: Double
    
    /// Timestamp when the food was logged or consumed
    public var loggedAt: Date
    
    public init(
        id: UUID = UUID(),
        foodItemId: UUID? = nil,
        snapshot: FoodNutritionalSnapshot,
        servingQuantity: Double = 1.0,
        loggedAt: Date = Date()
    ) {
        self.id = id
        self.foodItemId = foodItemId
        self.snapshot = snapshot
        self.servingQuantity = max(0.01, servingQuantity)
        self.loggedAt = loggedAt
    }
    
    /// Convenience initializer directly from a `FoodItem`
    public init(
        id: UUID = UUID(),
        foodItem: FoodItem,
        servingQuantity: Double = 1.0,
        loggedAt: Date = Date()
    ) {
        self.init(
            id: id,
            foodItemId: foodItem.id,
            snapshot: FoodNutritionalSnapshot(from: foodItem),
            servingQuantity: servingQuantity,
            loggedAt: loggedAt
        )
    }
    
    // MARK: - Calculated Consumed Nutrition
    
    /// Total calculated calories consumed in kilocalories (kcal)
    public var totalCalories: Double {
        snapshot.caloriesPerServing * servingQuantity
    }
    
    /// Total calculated protein consumed in grams (g)
    public var totalProteinGrams: Double {
        snapshot.proteinGramsPerServing * servingQuantity
    }
    
    /// Total calculated carbohydrates consumed in grams (g)
    public var totalCarbohydratesGrams: Double {
        snapshot.carbohydratesGramsPerServing * servingQuantity
    }
    
    /// Total calculated fat consumed in grams (g)
    public var totalFatGrams: Double {
        snapshot.fatGramsPerServing * servingQuantity
    }
    
    /// Total calculated dietary fibre consumed in grams (g)
    public var totalFibreGrams: Double? {
        guard let fibre = snapshot.fibreGramsPerServing else { return nil }
        return fibre * servingQuantity
    }
}
