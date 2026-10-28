import Foundation

// MARK: - Error DTO

/// Standard error payload returned by the FitBuddy recommendation backend.
public struct BackendErrorResponseDTO: Codable, Equatable {
    public let error: String
    public let code: String?
}

// MARK: - Workout Recommendation DTOs

/// Outgoing request payload matching POST /api/v1/workout/recommendations.
public struct WorkoutRecommendationRequestDTO: Encodable, Equatable {
    public let user_name: String
    public let gender: String?
    public let fitness_goal: String
    public let daily_mood: String?
    public let available_equipment: [String]
    public let available_time_seconds: Double
    public let recent_completed_workouts: [String]
    public let cycle_phase: String?
    public let cycle_symptoms: [String]
    
    public init(from input: WorkoutRecommendationInput) {
        let trimmedName = input.userProfile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.user_name = trimmedName.isEmpty ? "FitBuddy User" : String(trimmedName.prefix(100))
        self.gender = input.userProfile.gender?.rawValue
        self.fitness_goal = input.fitnessGoal.rawValue
        self.daily_mood = input.dailyMood?.rawValue
        
        let equipment = input.availableEquipment.map { $0.rawValue }
        self.available_equipment = equipment.isEmpty ? [EquipmentType.none.rawValue] : equipment
        
        // Duration clamped between 300s (5m) and 7200s (2h) per contract
        self.available_time_seconds = max(300, min(7200, input.availableTimeSeconds))
        
        // Up to 10 recent workouts, each clamped to 100 characters
        self.recent_completed_workouts = Array(input.recentCompletedWorkouts.prefix(10).map { String($0.prefix(100)) })
        
        // Privacy rule: cyclePhase and cycleSymptoms are already strictly gated in WorkoutRecommendationInput.init
        self.cycle_phase = input.cyclePhase?.rawValue
        self.cycle_symptoms = Array(input.cycleSymptoms.prefix(10).map { String($0.prefix(100)) })
    }
}

/// Incoming response payload matching POST /api/v1/workout/recommendations.
public struct WorkoutRecommendationResponseDTO: Decodable {
    public let workouts: [WorkoutDTO]
    public let model_used: String?
    public let generated_at: String?
    
    public init(workouts: [WorkoutDTO], model_used: String? = nil, generated_at: String? = nil) {
        self.workouts = workouts
        self.model_used = model_used
        self.generated_at = generated_at
    }
}

/// Single workout routine DTO.
public struct WorkoutDTO: Decodable {
    public let id: String
    public let name: String
    public let description: String
    public let category: String
    public let difficulty: String
    public let estimated_duration_seconds: Double
    public let estimated_calories: Int
    public let required_equipment: [String]
    public let ai_recommendation_rationale: String?
    public let exercises: [ExerciseDTO]
    
    public init(
        id: String,
        name: String,
        description: String,
        category: String,
        difficulty: String,
        estimated_duration_seconds: Double,
        estimated_calories: Int,
        required_equipment: [String],
        ai_recommendation_rationale: String? = nil,
        exercises: [ExerciseDTO]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.difficulty = difficulty
        self.estimated_duration_seconds = estimated_duration_seconds
        self.estimated_calories = estimated_calories
        self.required_equipment = required_equipment
        self.ai_recommendation_rationale = ai_recommendation_rationale
        self.exercises = exercises
    }
    
    public func toDomain() -> Workout {
        let uuid = UUID(uuidString: id) ?? UUID()
        let cat = WorkoutCategory(rawValue: category) ?? .stretch
        let diff = FitnessDifficulty(rawValue: difficulty) ?? .beginner
        let eq = required_equipment.compactMap { EquipmentType(rawValue: $0) }
        let domainExercises = exercises.map { $0.toDomain() }
        
        return Workout(
            id: uuid,
            name: name,
            description: description,
            exercises: domainExercises,
            category: cat,
            difficulty: diff,
            estimatedDurationSeconds: estimated_duration_seconds,
            estimatedCalories: estimated_calories,
            requiredEquipment: eq.isEmpty ? [.none] : eq,
            aiRecommendationRationale: ai_recommendation_rationale,
            dateCreated: Date()
        )
    }
}

/// Single exercise inside a recommended workout routine.
public struct ExerciseDTO: Decodable {
    public let id: String
    public let name: String
    public let description: String
    public let target_muscles: [String]
    public let equipment: String
    public let difficulty: String
    public let instructions: [String]
    public let sets: Int?
    public let repetitions: Int?
    public let duration_seconds: Double?
    public let rest_interval_seconds: Double?
    public let form_notes: String?
    
    public init(
        id: String,
        name: String,
        description: String,
        target_muscles: [String],
        equipment: String,
        difficulty: String,
        instructions: [String],
        sets: Int? = nil,
        repetitions: Int? = nil,
        duration_seconds: Double? = nil,
        rest_interval_seconds: Double? = nil,
        form_notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.target_muscles = target_muscles
        self.equipment = equipment
        self.difficulty = difficulty
        self.instructions = instructions
        self.sets = sets
        self.repetitions = repetitions
        self.duration_seconds = duration_seconds
        self.rest_interval_seconds = rest_interval_seconds
        self.form_notes = form_notes
    }
    
    public func toDomain() -> Exercise {
        let uuid = UUID(uuidString: id) ?? UUID()
        let muscles = target_muscles.compactMap { MuscleGroup(rawValue: $0) }
        let eq = EquipmentType(rawValue: equipment) ?? .none
        let diff = FitnessDifficulty(rawValue: difficulty) ?? .beginner
        
        return Exercise(
            id: uuid,
            name: name,
            description: description,
            targetMuscles: muscles.isEmpty ? [.fullBody] : muscles,
            equipment: eq,
            difficulty: diff,
            instructions: instructions,
            sets: sets,
            repetitions: repetitions,
            durationSeconds: duration_seconds,
            restIntervalSeconds: rest_interval_seconds,
            formNotes: form_notes
        )
    }
}

// MARK: - Nutrition Recommendation DTOs

/// Outgoing request payload matching POST /api/v1/nutrition/recommendations.
public struct NutritionRecommendationRequestDTO: Encodable, Equatable {
    public let user_name: String
    public let gender: String?
    public let fitness_goal: String
    public let daily_calorie_target: Double
    public let daily_protein_target_grams: Double
    public let daily_carbohydrates_target_grams: Double
    public let daily_fat_target_grams: Double
    public let consumed_calories: Double?
    public let consumed_protein_grams: Double?
    public let consumed_carbohydrates_grams: Double?
    public let consumed_fat_grams: Double?
    public let remaining_calories: Double?
    public let remaining_protein_grams: Double?
    public let remaining_carbohydrates_grams: Double?
    public let remaining_fat_grams: Double?
    public let dietary_preferences: [String]
    public let target_meal_type: String
    public let budget_tier: String
    public let available_ingredients: [String]
    public let request_date: String
    
    public init(from input: NutritionRecommendationInput) {
        let trimmedName = input.userProfile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.user_name = trimmedName.isEmpty ? "FitBuddy User" : String(trimmedName.prefix(100))
        self.gender = input.userProfile.gender?.rawValue
        self.fitness_goal = input.fitnessGoal.rawValue
        
        // Targets
        self.daily_calorie_target = max(500, input.targets.dailyCalorieTarget)
        self.daily_protein_target_grams = max(0, input.targets.proteinGramsTarget)
        self.daily_carbohydrates_target_grams = max(0, input.targets.carbohydratesGramsTarget)
        self.daily_fat_target_grams = max(0, input.targets.fatGramsTarget)
        
        // Consumed and remaining figures from summary
        if let summary = input.currentSummary {
            self.consumed_calories = max(0, summary.consumedCalories)
            self.consumed_protein_grams = max(0, summary.consumedProteinGrams)
            self.consumed_carbohydrates_grams = max(0, summary.consumedCarbohydratesGrams)
            self.consumed_fat_grams = max(0, summary.consumedFatGrams)
            
            self.remaining_calories = max(0, summary.remainingCalories)
            self.remaining_protein_grams = max(0, summary.remainingProteinGrams)
            self.remaining_carbohydrates_grams = max(0, summary.remainingCarbohydratesGrams)
            self.remaining_fat_grams = max(0, summary.remainingFatGrams)
        } else {
            self.consumed_calories = 0
            self.consumed_protein_grams = 0
            self.consumed_carbohydrates_grams = 0
            self.consumed_fat_grams = 0
            
            self.remaining_calories = self.daily_calorie_target
            self.remaining_protein_grams = self.daily_protein_target_grams
            self.remaining_carbohydrates_grams = self.daily_carbohydrates_target_grams
            self.remaining_fat_grams = self.daily_fat_target_grams
        }
        
        self.dietary_preferences = input.dietaryPreferences.map { $0.rawValue }
        self.target_meal_type = input.targetMealType.rawValue
        self.budget_tier = input.budget.rawValue
        self.available_ingredients = Array(input.availableIngredients.prefix(30).map { String($0.prefix(60)) })
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        self.request_date = formatter.string(from: input.date)
    }
}

/// Incoming response payload matching POST /api/v1/nutrition/recommendations.
public struct NutritionRecommendationResponseDTO: Decodable {
    public let suggestions: [FoodSuggestionDTO]
    public let model_used: String?
    public let generated_at: String?
    
    public init(suggestions: [FoodSuggestionDTO], model_used: String? = nil, generated_at: String? = nil) {
        self.suggestions = suggestions
        self.model_used = model_used
        self.generated_at = generated_at
    }
}

/// Single food suggestion DTO.
public struct FoodSuggestionDTO: Decodable {
    public let id: String
    public let food_item: FoodItemDTO
    public let suggested_quantity: Double
    public let target_meal_type: String
    public let estimated_calories: Double
    public let estimated_protein_grams: Double
    public let estimated_carbohydrates_grams: Double
    public let estimated_fat_grams: Double
    public let recommendation_rationale: String
    
    public init(
        id: String,
        food_item: FoodItemDTO,
        suggested_quantity: Double,
        target_meal_type: String,
        estimated_calories: Double,
        estimated_protein_grams: Double,
        estimated_carbohydrates_grams: Double,
        estimated_fat_grams: Double,
        recommendation_rationale: String
    ) {
        self.id = id
        self.food_item = food_item
        self.suggested_quantity = suggested_quantity
        self.target_meal_type = target_meal_type
        self.estimated_calories = estimated_calories
        self.estimated_protein_grams = estimated_protein_grams
        self.estimated_carbohydrates_grams = estimated_carbohydrates_grams
        self.estimated_fat_grams = estimated_fat_grams
        self.recommendation_rationale = recommendation_rationale
    }
    
    public func toDomain() -> FoodSuggestion {
        let uuid = UUID(uuidString: id) ?? UUID()
        let food = food_item.toDomain()
        let meal = MealType(rawValue: target_meal_type) ?? .snack
        
        return FoodSuggestion(
            id: uuid,
            foodItem: food,
            suggestedQuantity: max(0.1, suggested_quantity),
            targetMealType: meal,
            recommendationRationale: recommendation_rationale
        )
    }
}

/// Baseline food item DTO.
public struct FoodItemDTO: Decodable {
    public let id: String
    public let name: String
    public let item_description: String?
    public let serving_size: Double
    public let serving_unit: String
    public let calories: Double
    public let protein_grams: Double
    public let carbohydrates_grams: Double
    public let fat_grams: Double
    public let fibre_grams: Double?
    public let category: String?
    public let data_source: String
    public let icon_symbol: String?
    
    public init(
        id: String,
        name: String,
        item_description: String? = nil,
        serving_size: Double,
        serving_unit: String,
        calories: Double,
        protein_grams: Double,
        carbohydrates_grams: Double,
        fat_grams: Double,
        fibre_grams: Double? = nil,
        category: String? = nil,
        data_source: String = "AI Estimated",
        icon_symbol: String? = nil
    ) {
        self.id = id
        self.name = name
        self.item_description = item_description
        self.serving_size = serving_size
        self.serving_unit = serving_unit
        self.calories = calories
        self.protein_grams = protein_grams
        self.carbohydrates_grams = carbohydrates_grams
        self.fat_grams = fat_grams
        self.fibre_grams = fibre_grams
        self.category = category
        self.data_source = data_source
        self.icon_symbol = icon_symbol
    }
    
    public func toDomain() -> FoodItem {
        let uuid = UUID(uuidString: id) ?? UUID()
        let unit = ServingUnit(rawValue: serving_unit) ?? .grams
        let cat = category.flatMap { FoodCategory(rawValue: $0) }
        let src = NutritionDataSource(rawValue: data_source) ?? .aiEstimated
        
        return FoodItem(
            id: uuid,
            name: name,
            itemDescription: item_description,
            servingSize: serving_size,
            servingUnit: unit,
            calories: calories,
            proteinGrams: protein_grams,
            carbohydratesGrams: carbohydrates_grams,
            fatGrams: fat_grams,
            fibreGrams: fibre_grams,
            category: cat,
            dataSource: src,
            iconSymbol: icon_symbol
        )
    }
}
