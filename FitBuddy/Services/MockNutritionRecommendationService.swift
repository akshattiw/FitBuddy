import Foundation

/// Errors that may occur during nutrition recommendation processing.
public enum NutritionRecommendationError: LocalizedError {
    case invalidInput(String)
    case noMatchingFoodsAvailable
    
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let reason):
            return "Invalid nutrition input: \(reason)"
        case .noMatchingFoodsAvailable:
            return "No food recommendations matched the specified dietary preferences."
        }
    }
}

/// Mock nutrition recommendation service conforming strictly to `NutritionRecommendationProviding`.
/// Uses deterministic local heuristic rules to select realistic, affordable Indian food suggestions
/// (e.g., Dal Tadka, Roti, Curd/Dahi, Paneer Bhurji, Boiled Eggs, Chana/Chickpeas, Khichdi, Sprouts)
/// tailored to user goals, preferences, and remaining daily targets without calling external APIs.
public struct MockNutritionRecommendationService: NutritionRecommendationProviding {
    
    public init() {}
    
    public func recommendFoods(for input: NutritionRecommendationInput) async throws -> [FoodSuggestion] {
        let catalog = Self.indianFoodCatalog
        
        // 1. Filter by dietary preferences & restrictions
        let filtered = catalog.filter { item in
            isFood(item, compatibleWith: input.dietaryPreferences)
        }
        
        guard !filtered.isEmpty else {
            throw NutritionRecommendationError.noMatchingFoodsAvailable
        }
        
        // 2. Determine target remaining macros from summary or fallback to targets
        let remainingCalories = input.currentSummary?.remainingCalories ?? input.targets.dailyCalorieTarget
        let remainingProtein = input.currentSummary?.remainingProteinGrams ?? input.targets.proteinGramsTarget
        
        // 3. Score and prioritize candidates using deterministic local heuristic rules
        let scored = filtered.map { item -> (FoodItem, Double) in
            var score = 1.0
            
            // Goal alignment
            switch input.fitnessGoal {
            case .buildStrength:
                // High protein foods score higher
                score += item.proteinGrams * 0.8
            case .weightLoss:
                // High protein, lower calorie ratio
                let proteinRatio = item.calories > 0 ? (item.proteinGrams * 4.0) / item.calories : 0.0
                score += proteinRatio * 8.0
            case .generalFitness, .improveMobility, .stressRelief:
                // Balanced options
                score += 3.0
            }
            
            // Check if calorie fits within remaining target
            if item.calories <= remainingCalories {
                score += 4.0
            }
            
            // Prioritize foods filling protein deficit
            if remainingProtein > 20 && item.proteinGrams >= 10 {
                score += 5.0
            }
            
            // Meal type alignment
            if let cat = item.category {
                switch (input.targetMealType, cat) {
                case (.breakfast, .dairy), (.breakfast, .grains):
                    score += 3.0
                case (.lunch, .legumesNuts), (.lunch, .grains), (.lunch, .poultryMeat):
                    score += 3.0
                case (.dinner, .vegetables), (.dinner, .legumesNuts):
                    score += 3.0
                case (.postWorkout, _):
                    if item.proteinGrams >= 12 { score += 6.0 }
                case (.snack, .fruits), (.snack, .snacks), (.snack, .dairy):
                    score += 3.0
                default:
                    break
                }
            }
            
            return (item, score)
        }
        
        // Sort descending by score
        let sorted = scored.sorted { $0.1 > $1.1 }.map { $0.0 }
        
        // Build structured FoodSuggestion outputs for top candidates (3 suggestions)
        let topItems = Array(sorted.prefix(3))
        
        return topItems.map { food in
            let rationale = rationaleFor(food: food, input: input, remainingCalories: remainingCalories, remainingProtein: remainingProtein)
            return FoodSuggestion(
                foodItem: food,
                suggestedQuantity: 1.0,
                targetMealType: input.targetMealType,
                recommendationRationale: rationale
            )
        }
    }
    
    // MARK: - Compatibility Check
    private func isFood(_ food: FoodItem, compatibleWith preferences: [DietaryPreference]) -> Bool {
        for pref in preferences {
            switch pref {
            case .omnivore:
                continue
            case .vegetarian:
                if food.category == .poultryMeat || food.category == .seafood { return false }
            case .vegan:
                if food.category == .poultryMeat || food.category == .seafood || food.category == .dairy { return false }
            case .dairyFree:
                if food.category == .dairy { return false }
            case .glutenFree:
                if food.name.contains("Roti") || food.name.contains("Wheat") { return false }
            case .nutFree:
                if food.category == .legumesNuts && food.name.contains("Nut") { return false }
            case .pescatarian:
                if food.category == .poultryMeat { return false }
            case .keto, .lowCarb:
                if food.carbohydratesGrams > 25 { return false }
            }
        }
        return true
    }
    
    // MARK: - Rationale Generator
    private func rationaleFor(food: FoodItem, input: NutritionRecommendationInput, remainingCalories: Double, remainingProtein: Double) -> String {
        if food.proteinGrams >= 14 {
            return "High-protein choice (\(Int(food.proteinGrams))g) to support your \(input.fitnessGoal.rawValue.lowercased()) and help reach your remaining \(Int(remainingProtein))g protein target."
        } else if food.calories <= 160 {
            return "Nutrient-dense, low-calorie option (\(Int(food.calories)) kcal) easily fitting your remaining \(Int(remainingCalories)) kcal budget."
        } else {
            return "Balanced source of clean complex energy and micronutrients tailored for \(input.targetMealType.rawValue.lowercased())."
        }
    }
    
    // MARK: - Realistic, Affordable Indian Food Catalog
    public static var indianFoodCatalog: [FoodItem] {
        [
            // 1. Dal Tadka (Yellow Lentils)
            FoodItem(
                id: UUID(uuidString: "a1111111-1111-1111-1111-111111111111")!,
                name: "Yellow Dal Tadka",
                itemDescription: "Traditional home-cooked yellow lentil curry tempered with cumin and garlic.",
                servingSize: 1,
                servingUnit: .cup,
                calories: 180,
                proteinGrams: 11,
                carbohydratesGrams: 26,
                fatGrams: 4,
                fibreGrams: 6,
                category: .legumesNuts,
                dataSource: .verifiedDatabase,
                iconSymbol: "🍲"
            ),
            
            // 2. Whole Wheat Roti
            FoodItem(
                id: UUID(uuidString: "a2222222-2222-2222-2222-222222222222")!,
                name: "Whole Wheat Roti",
                itemDescription: "Freshly roasted Indian flatbread made of 100% whole wheat flour.",
                servingSize: 2,
                servingUnit: .piece,
                calories: 160,
                proteinGrams: 6,
                carbohydratesGrams: 32,
                fatGrams: 1.5,
                fibreGrams: 4,
                category: .grains,
                dataSource: .verifiedDatabase,
                iconSymbol: "🫓"
            ),
            
            // 3. Curd / Plain Dahi
            FoodItem(
                id: UUID(uuidString: "a3333333-3333-3333-3333-333333333333")!,
                name: "Fresh Curd (Dahi)",
                itemDescription: "Probiotic-rich plain homemade yogurt supporting digestion and cooling.",
                servingSize: 150,
                servingUnit: .grams,
                calories: 105,
                proteinGrams: 7,
                carbohydratesGrams: 8,
                fatGrams: 5,
                fibreGrams: 0,
                category: .dairy,
                dataSource: .verifiedDatabase,
                iconSymbol: "🥣"
            ),
            
            // 4. Paneer Bhurji / Grilled Paneer
            FoodItem(
                id: UUID(uuidString: "a4444444-4444-4444-4444-444444444444")!,
                name: "Paneer Bhurji",
                itemDescription: "Scrambled cottage cheese tossed with onion, tomatoes, turmeric, and green chilies.",
                servingSize: 100,
                servingUnit: .grams,
                calories: 220,
                proteinGrams: 16,
                carbohydratesGrams: 5,
                fatGrams: 16,
                fibreGrams: 1,
                category: .dairy,
                dataSource: .verifiedDatabase,
                iconSymbol: "🧀"
            ),
            
            // 5. Boiled Eggs
            FoodItem(
                id: UUID(uuidString: "a5555555-5555-5555-5555-555555555555")!,
                name: "Boiled Eggs",
                itemDescription: "Hard-boiled whole farm eggs providing complete bioavailable amino acids.",
                servingSize: 2,
                servingUnit: .piece,
                calories: 140,
                proteinGrams: 12,
                carbohydratesGrams: 1,
                fatGrams: 10,
                fibreGrams: 0,
                category: .dairy,
                dataSource: .verifiedDatabase,
                iconSymbol: "🍳"
            ),
            
            // 6. Kala Chana / Roasted Chickpeas
            FoodItem(
                id: UUID(uuidString: "a6666666-6666-6666-6666-666666666666")!,
                name: "Spiced Kala Chana",
                itemDescription: "Boiled brown chickpeas lightly sautéed with cumin, ginger, and chaat masala.",
                servingSize: 1,
                servingUnit: .cup,
                calories: 210,
                proteinGrams: 12,
                carbohydratesGrams: 34,
                fatGrams: 3,
                fibreGrams: 9,
                category: .legumesNuts,
                dataSource: .verifiedDatabase,
                iconSymbol: "🧆"
            ),
            
            // 7. Steamed Basmati Rice
            FoodItem(
                id: UUID(uuidString: "a7777777-7777-7777-7777-777777777777")!,
                name: "Steamed Rice",
                itemDescription: "Fluffy steamed white basmati rice, easy on the stomach.",
                servingSize: 1,
                servingUnit: .cup,
                calories: 205,
                proteinGrams: 4,
                carbohydratesGrams: 45,
                fatGrams: 0.5,
                fibreGrams: 1,
                category: .grains,
                dataSource: .verifiedDatabase,
                iconSymbol: "🍚"
            ),
            
            // 8. Moong Dal Sprouts Salad
            FoodItem(
                id: UUID(uuidString: "a8888888-8888-8888-8888-888888888888")!,
                name: "Moong Sprouts Salad",
                itemDescription: "Crisp sprouted green gram tossed with diced cucumber, tomatoes, and fresh lemon juice.",
                servingSize: 1,
                servingUnit: .cup,
                calories: 120,
                proteinGrams: 9,
                carbohydratesGrams: 20,
                fatGrams: 1,
                fibreGrams: 5,
                category: .vegetables,
                dataSource: .verifiedDatabase,
                iconSymbol: "🥗"
            ),
            
            // 9. Grilled Chicken Tikka
            FoodItem(
                id: UUID(uuidString: "a9999999-9999-9999-9999-999999999999")!,
                name: "Chicken Tikka (Dry)",
                itemDescription: "Lean chicken breast cubes marinated in yogurt and roasted tandoori spices.",
                servingSize: 150,
                servingUnit: .grams,
                calories: 195,
                proteinGrams: 31,
                carbohydratesGrams: 3,
                fatGrams: 6,
                fibreGrams: 0,
                category: .poultryMeat,
                dataSource: .verifiedDatabase,
                iconSymbol: "🍗"
            )
        ]
    }
}
