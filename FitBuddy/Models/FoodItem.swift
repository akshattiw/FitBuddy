import Foundation

/// General food classification category for meal organization and filtering.
public enum FoodCategory: String, Codable, CaseIterable, Identifiable {
    case fruits = "Fruits"
    case vegetables = "Vegetables"
    case poultryMeat = "Meat & Poultry"
    case seafood = "Seafood"
    case grains = "Grains & Pasta"
    case dairy = "Dairy & Eggs"
    case legumesNuts = "Nuts & Legumes"
    case beverages = "Beverages"
    case snacks = "Snacks"
    case preparedMeals = "Prepared Meals"
    
    public var id: String { rawValue }
}

/// Data provenance and quality classification to distinguish verified standard data from AI estimates.
public enum NutritionDataSource: String, Codable, CaseIterable, Identifiable {
    case verifiedDatabase = "Verified Database"
    case aiEstimated = "AI Estimated"
    case userCreated = "User Created"
    
    public var id: String { rawValue }
}

/// Measurement unit for food servings.
public enum ServingUnit: String, Codable, CaseIterable, Identifiable {
    case grams = "g"
    case milliliters = "ml"
    case piece = "piece"
    case cup = "cup"
    case tablespoon = "tbsp"
    case teaspoon = "tsp"
    case ounce = "oz"
    
    public var id: String { rawValue }
}

/// Reusable nutritional food model representing a baseline serving of food.
public struct FoodItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var itemDescription: String?
    
    /// Baseline serving size (e.g. 100)
    public var servingSize: Double
    
    /// Serving measurement unit (e.g. .grams, .piece)
    public var servingUnit: ServingUnit
    
    /// Calories in kilocalories (kcal) per serving size
    public var calories: Double
    
    /// Protein in grams (g) per serving size
    public var proteinGrams: Double
    
    /// Carbohydrates in grams (g) per serving size
    public var carbohydratesGrams: Double
    
    /// Fat in grams (g) per serving size
    public var fatGrams: Double
    
    /// Dietary fibre in grams (g) per serving size
    public var fibreGrams: Double?
    
    /// Optional food classification category
    public var category: FoodCategory?
    
    /// Data provenance (verified database vs. AI estimated)
    public var dataSource: NutritionDataSource
    
    /// Optional emoji or asset reference for UI display (e.g. "🍎", "🍗")
    public var iconSymbol: String?
    
    public init(
        id: UUID = UUID(),
        name: String,
        itemDescription: String? = nil,
        servingSize: Double,
        servingUnit: ServingUnit,
        calories: Double,
        proteinGrams: Double,
        carbohydratesGrams: Double,
        fatGrams: Double,
        fibreGrams: Double? = nil,
        category: FoodCategory? = nil,
        dataSource: NutritionDataSource = .verifiedDatabase,
        iconSymbol: String? = nil
    ) {
        self.id = id
        self.name = name
        self.itemDescription = itemDescription
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydratesGrams = carbohydratesGrams
        self.fatGrams = fatGrams
        self.fibreGrams = fibreGrams
        self.category = category
        self.dataSource = dataSource
        self.iconSymbol = iconSymbol
    }
    
    /// Formatted serving description (e.g. "1 piece" or "100 g")
    public var formattedServing: String {
        let sizeString = servingSize.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(servingSize))" : String(format: "%.1f", servingSize)
        return "\(sizeString) \(servingUnit.rawValue)"
    }
}
