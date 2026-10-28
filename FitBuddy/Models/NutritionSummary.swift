import Foundation

/// Target goals for daily calorie and macronutrient intake.
public struct NutritionTargets: Codable, Equatable {
    public var dailyCalorieTarget: Double
    public var proteinGramsTarget: Double
    public var carbohydratesGramsTarget: Double
    public var fatGramsTarget: Double
    
    public init(
        dailyCalorieTarget: Double = 2000,
        proteinGramsTarget: Double = 140,
        carbohydratesGramsTarget: Double = 200,
        fatGramsTarget: Double = 65
    ) {
        self.dailyCalorieTarget = max(0, dailyCalorieTarget)
        self.proteinGramsTarget = max(0, proteinGramsTarget)
        self.carbohydratesGramsTarget = max(0, carbohydratesGramsTarget)
        self.fatGramsTarget = max(0, fatGramsTarget)
    }
}

/// Calculation-friendly structure summarizing daily targets vs. actual consumption computed from `[FoodLog]`.
public struct NutritionSummary: Codable, Equatable {
    /// Date of the summary
    public let date: Date
    
    /// User's set daily nutritional targets
    public let targets: NutritionTargets
    
    /// Total calories consumed in kcal (sum of food log entries)
    public let consumedCalories: Double
    
    /// Total protein consumed in grams (sum of food log entries)
    public let consumedProteinGrams: Double
    
    /// Total carbohydrates consumed in grams (sum of food log entries)
    public let consumedCarbohydratesGrams: Double
    
    /// Total fat consumed in grams (sum of food log entries)
    public let consumedFatGrams: Double
    
    /// Total dietary fibre consumed in grams
    public let consumedFibreGrams: Double
    
    public init(
        date: Date = Date(),
        targets: NutritionTargets,
        consumedCalories: Double,
        consumedProteinGrams: Double,
        consumedCarbohydratesGrams: Double,
        consumedFatGrams: Double,
        consumedFibreGrams: Double = 0
    ) {
        self.date = date
        self.targets = targets
        self.consumedCalories = consumedCalories
        self.consumedProteinGrams = consumedProteinGrams
        self.consumedCarbohydratesGrams = consumedCarbohydratesGrams
        self.consumedFatGrams = consumedFatGrams
        self.consumedFibreGrams = consumedFibreGrams
    }
    
    /// Deterministic factory method that aggregates actual consumption strictly from an array of food logs for a given date.
    public static func calculate(
        for date: Date = Date(),
        logs: [FoodLog],
        targets: NutritionTargets = NutritionTargets(),
        calendar: Calendar = .current
    ) -> NutritionSummary {
        // Filter food logs recorded on the requested day
        let dayLogs = logs.filter { calendar.isDate($0.loggedAt, inSameDayAs: date) }
        
        let totalCals = dayLogs.reduce(0.0) { $0 + $1.totalCalories }
        let totalProtein = dayLogs.reduce(0.0) { $0 + $1.totalProteinGrams }
        let totalCarbs = dayLogs.reduce(0.0) { $0 + $1.totalCarbohydratesGrams }
        let totalFat = dayLogs.reduce(0.0) { $0 + $1.totalFatGrams }
        let totalFibre = dayLogs.reduce(0.0) { $0 + ($1.totalFibreGrams ?? 0.0) }
        
        return NutritionSummary(
            date: date,
            targets: targets,
            consumedCalories: totalCals,
            consumedProteinGrams: totalProtein,
            consumedCarbohydratesGrams: totalCarbs,
            consumedFatGrams: totalFat,
            consumedFibreGrams: totalFibre
        )
    }
    
    // MARK: - Remaining & Completion Metrics
    
    /// Remaining calories to reach target (returns 0 if target exceeded)
    public var remainingCalories: Double {
        max(0, targets.dailyCalorieTarget - consumedCalories)
    }
    
    /// Remaining protein in grams to reach target (returns 0 if target reached)
    public var remainingProteinGrams: Double {
        max(0, targets.proteinGramsTarget - consumedProteinGrams)
    }
    
    /// Remaining carbohydrates in grams to reach target (returns 0 if target reached)
    public var remainingCarbohydratesGrams: Double {
        max(0, targets.carbohydratesGramsTarget - consumedCarbohydratesGrams)
    }
    
    /// Remaining fat in grams to reach target (returns 0 if target reached)
    public var remainingFatGrams: Double {
        max(0, targets.fatGramsTarget - consumedFatGrams)
    }
    
    /// Progress ratio for calories (0.0 to 1.0+)
    public var calorieProgressRatio: Double {
        guard targets.dailyCalorieTarget > 0 else { return 0 }
        return consumedCalories / targets.dailyCalorieTarget
    }
    
    /// Progress ratio for protein (0.0 to 1.0+)
    public var proteinProgressRatio: Double {
        guard targets.proteinGramsTarget > 0 else { return 0 }
        return consumedProteinGrams / targets.proteinGramsTarget
    }
    
    /// Progress ratio for carbohydrates (0.0 to 1.0+)
    public var carbsProgressRatio: Double {
        guard targets.carbohydratesGramsTarget > 0 else { return 0 }
        return consumedCarbohydratesGrams / targets.carbohydratesGramsTarget
    }
    
    /// Progress ratio for fat (0.0 to 1.0+)
    public var fatProgressRatio: Double {
        guard targets.fatGramsTarget > 0 else { return 0 }
        return consumedFatGrams / targets.fatGramsTarget
    }
}
