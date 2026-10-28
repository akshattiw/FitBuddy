import Foundation

/// Common dietary preferences and restrictions.
public enum DietaryPreference: String, Codable, CaseIterable, Identifiable {
    case omnivore = "Omnivore"
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case pescatarian = "Pescatarian"
    case keto = "Ketogenic"
    case lowCarb = "Low Carb"
    case dairyFree = "Dairy-Free"
    case glutenFree = "Gluten-Free"
    case nutFree = "Nut-Free"
    
    public var id: String { rawValue }
}

/// Target meal slot for meal-specific suggestions.
public enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    case postWorkout = "Post-Workout"
    
    public var id: String { rawValue }
}

/// Budget tiers for meal and ingredient suggestions.
public enum BudgetTier: String, Codable, CaseIterable, Identifiable {
    case budget = "Budget Friendly"
    case moderate = "Moderate"
    case premium = "Premium"
    
    public var id: String { rawValue }
}

/// Structured recommendation suggestion returned by a `NutritionRecommendationProviding` service.
/// Wraps a suggested `FoodItem` with proposed serving size, computed estimated nutrients,
/// and an explanation for why this item fits the user's remaining macros.
public struct FoodSuggestion: Identifiable, Codable, Equatable {
    public let id: UUID
    public let foodItem: FoodItem
    public let suggestedQuantity: Double
    public let targetMealType: MealType
    
    /// Estimated calories for the suggested serving quantity
    public let estimatedCalories: Double
    
    /// Estimated protein in grams for the suggested serving quantity
    public let estimatedProteinGrams: Double
    
    /// Estimated carbs in grams for the suggested serving quantity
    public let estimatedCarbohydratesGrams: Double
    
    /// Estimated fat in grams for the suggested serving quantity
    public let estimatedFatGrams: Double
    
    /// Clear explanation of why this item was suggested relative to daily targets
    public let recommendationRationale: String
    
    public init(
        id: UUID = UUID(),
        foodItem: FoodItem,
        suggestedQuantity: Double = 1.0,
        targetMealType: MealType = .snack,
        recommendationRationale: String
    ) {
        self.id = id
        self.foodItem = foodItem
        self.suggestedQuantity = max(0.1, suggestedQuantity)
        self.targetMealType = targetMealType
        self.estimatedCalories = foodItem.calories * suggestedQuantity
        self.estimatedProteinGrams = foodItem.proteinGrams * suggestedQuantity
        self.estimatedCarbohydratesGrams = foodItem.carbohydratesGrams * suggestedQuantity
        self.estimatedFatGrams = foodItem.fatGrams * suggestedQuantity
        self.recommendationRationale = recommendationRationale
    }
    
    /// Formatted suggested serving description (e.g. "1.5 × 100 g")
    public var formattedSuggestedServing: String {
        if suggestedQuantity == 1.0 {
            return foodItem.formattedServing
        } else {
            let qtyStr = suggestedQuantity.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(suggestedQuantity))" : String(format: "%.1f", suggestedQuantity)
            return "\(qtyStr) × \(foodItem.formattedServing)"
        }
    }
}

/// Strongly typed input payload containing context required to generate tailored food suggestions.
/// Free of any UI dependencies, Groq-specific parameters, or network client types.
public struct NutritionRecommendationInput: Codable, Equatable {
    /// Relevant user profile (name, gender)
    public var userProfile: UserProfile
    
    /// Target fitness goal (e.g. weightLoss, buildStrength)
    public var fitnessGoal: FitnessGoal
    
    /// Daily targets (calories, protein, carbs, fat)
    public var targets: NutritionTargets
    
    /// Actual daily summary representing consumed and remaining nutrients (if logs exist)
    public var currentSummary: NutritionSummary?
    
    /// Dietary preferences or restrictions (e.g. [.vegan, .glutenFree])
    public var dietaryPreferences: [DietaryPreference]
    
    /// Specific meal occasion targeted (e.g. .postWorkout, .lunch)
    public var targetMealType: MealType
    
    /// Budget preference
    public var budget: BudgetTier
    
    /// Available ingredients on hand, if provided by user
    public var availableIngredients: [String]
    
    /// Current day context (timestamp, day of week)
    public var date: Date
    
    public init(
        userProfile: UserProfile,
        fitnessGoal: FitnessGoal = .generalFitness,
        targets: NutritionTargets = NutritionTargets(),
        currentSummary: NutritionSummary? = nil,
        dietaryPreferences: [DietaryPreference] = [.omnivore],
        targetMealType: MealType = .snack,
        budget: BudgetTier = .moderate,
        availableIngredients: [String] = [],
        date: Date = Date()
    ) {
        self.userProfile = userProfile
        self.fitnessGoal = fitnessGoal
        self.targets = targets
        self.currentSummary = currentSummary
        self.dietaryPreferences = dietaryPreferences
        self.targetMealType = targetMealType
        self.budget = budget
        self.availableIngredients = availableIngredients
        self.date = date
    }
}

/// Protocol defining the contract for nutrition and food recommendation providers.
/// Enables deterministic mock providers and live AI backends to be interchanged without altering UI code.
public protocol NutritionRecommendationProviding {
    /// Asynchronously generates personalized food suggestions based on user targets, remaining macros, and preferences.
    /// - Parameter input: The user context, remaining nutrients, and dietary constraints.
    /// - Returns: An array of `FoodSuggestion` recommendations.
    func recommendFoods(for input: NutritionRecommendationInput) async throws -> [FoodSuggestion]
}
