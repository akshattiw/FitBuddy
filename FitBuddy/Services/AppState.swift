import SwiftUI

/// Unified observable central app state for FitBuddy.
/// Provides a single source of truth across all 5 tabs and manages local persistence.
@Observable
public final class AppState {
    public let persistenceService: PersistenceServiceProtocol
    
    // Core Managers and Stores
    public var profileManager: UserProfileManager
    public var workoutHistoryStore: WorkoutHistoryStore
    public var nutritionStore: NutritionDataStore
    public var cycleManager: CycleDataManager
    public var rewardStore: RewardStore
    public var petStore: PetCompanionStore
    
    // Onboarding Flag
    public var isOnboardingCompleted: Bool
    
    public init(persistenceService: PersistenceServiceProtocol = LocalFilePersistenceService()) {
        self.persistenceService = persistenceService
        
        // Attempt loading persisted snapshot
        if let snapshot = persistenceService.load() {
            self.profileManager = UserProfileManager(profile: snapshot.profile)
            self.isOnboardingCompleted = snapshot.isOnboardingCompleted
            self.workoutHistoryStore = WorkoutHistoryStore(records: snapshot.workoutHistory)
            self.nutritionStore = NutritionDataStore(targets: snapshot.nutritionTargets, loggedItems: snapshot.foodLogs)
            self.cycleManager = CycleDataManager(data: snapshot.cycleData)
            self.rewardStore = RewardStore(state: snapshot.rewardInventory)
            self.petStore = PetCompanionStore(state: snapshot.petInventory)
        } else {
            // Fresh launch defaults (with realistic baseline starter items for Nutrition)
            self.profileManager = UserProfileManager(profile: UserProfile(gender: nil))
            self.isOnboardingCompleted = false
            self.workoutHistoryStore = WorkoutHistoryStore()
            self.nutritionStore = NutritionDataStore(
                targets: NutritionTargets(dailyCalorieTarget: 2160, proteinGramsTarget: 140, carbohydratesGramsTarget: 200, fatGramsTarget: 65),
                loggedItems: [
                    FoodLog(
                        foodItem: FoodItem(name: "Fresh Apple", servingSize: 1, servingUnit: .piece, calories: 95, proteinGrams: 0.5, carbohydratesGrams: 25, fatGrams: 0.3, category: .fruits, iconSymbol: "🍎"),
                        servingQuantity: 1.0
                    ),
                    FoodLog(
                        foodItem: FoodItem(name: "Boiled Eggs", servingSize: 2, servingUnit: .piece, calories: 140, proteinGrams: 12, carbohydratesGrams: 1, fatGrams: 10, category: .dairy, iconSymbol: "🍳"),
                        servingQuantity: 1.0
                    ),
                    FoodLog(
                        foodItem: FoodItem(name: "Chicken Tikka", servingSize: 150, servingUnit: .grams, calories: 195, proteinGrams: 31, carbohydratesGrams: 3, fatGrams: 6, category: .poultryMeat, iconSymbol: "🍗"),
                        servingQuantity: 1.0
                    ),
                    FoodLog(
                        foodItem: FoodItem(name: "Steamed Rice", servingSize: 1, servingUnit: .cup, calories: 205, proteinGrams: 4, carbohydratesGrams: 45, fatGrams: 0.5, category: .grains, iconSymbol: "🍚"),
                        servingQuantity: 1.0
                    )
                ]
            )
            self.cycleManager = CycleDataManager()
            self.rewardStore = RewardStore()
            self.petStore = PetCompanionStore()
        }
        
        wireChangeListeners()
    }
    
    private func wireChangeListeners() {
        profileManager.onDidChange = { [weak self] in
            self?.save()
        }
        workoutHistoryStore.onDidChange = { [weak self] in
            guard let self = self else { return }
            self.rewardStore.synchronize(with: self.workoutHistoryStore.records)
            self.save()
        }
        nutritionStore.onDidChange = { [weak self] in
            self?.save()
        }
        cycleManager.onDidChange = { [weak self] in
            self?.save()
        }
        rewardStore.onDidChange = { [weak self] in
            self?.save()
        }
        petStore.onDidChange = { [weak self] in
            self?.save()
        }
    }
    
    /// Persists current in-memory state to local storage.
    public func save() {
        let snapshot = AppDataSnapshot(
            profile: profileManager.profile,
            isOnboardingCompleted: isOnboardingCompleted,
            workoutHistory: workoutHistoryStore.records,
            nutritionTargets: nutritionStore.targets,
            foodLogs: nutritionStore.loggedItems,
            cycleData: cycleManager.data,
            rewardInventory: rewardStore.state,
            petInventory: petStore.state,
            lastSavedDate: Date()
        )
        persistenceService.save(snapshot)
    }
    
    /// Selects an active companion pet and persists changes.
    public func selectActivePet(id: String) {
        petStore.selectActivePet(id: id)
        save()
    }
    
    /// Evaluates hunger and death state for all pets at a given reference time.
    /// Persists state changes immediately if any pet transitions status.
    @discardableResult
    public func refreshPetHunger(at referenceDate: Date = Date()) -> Bool {
        let changed = petStore.evaluateHungerAndSurvival(at: referenceDate)
        if changed {
            save()
        }
        return changed
    }
    
    /// Atomically feeds an owned, living pet by deducting 10 XP and increasing level by 1.
    @discardableResult
    public func feedPet(id: String, currentDate: Date = Date()) -> FeedPetResult {
        let result = petStore.feedPet(id: id, rewardStore: rewardStore, currentDate: currentDate)
        if case .success = result {
            save()
        }
        return result
    }
    
    /// Completes initial onboarding and saves state.
    public func completeOnboarding(name: String, gender: UserGender?) {
        profileManager.profile.name = name
        profileManager.profile.gender = gender
        isOnboardingCompleted = true
        save()
    }
    
    /// Records a completed workout, synchronizes rewards/XP, and saves state.
    public func recordCompletedWorkout(_ record: WorkoutRecord) {
        workoutHistoryStore.addRecord(record)
        rewardStore.synchronize(with: workoutHistoryStore.records)
        save()
    }
    
    /// Adds a food log and saves state.
    public func addFoodLog(_ log: FoodLog) {
        nutritionStore.addFoodLog(log)
        save()
    }
    
    /// Updates user gender cleanly, preserving cycle data even if gender becomes non-female.
    public func updateGender(_ gender: UserGender?) {
        profileManager.profile.gender = gender
        save()
    }
}
