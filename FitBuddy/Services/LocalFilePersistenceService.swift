import Foundation

/// Unified data container serializing all persistent FitBuddy user state.
/// Designed for local JSON file storage with atomic writes and schema evolution readiness.
public struct AppDataSnapshot: Codable {
    public var profile: UserProfile
    public var isOnboardingCompleted: Bool
    public var workoutHistory: [WorkoutRecord]
    public var nutritionTargets: NutritionTargets
    public var foodLogs: [FoodLog]
    public var cycleData: CycleData
    public var rewardInventory: RewardInventoryState
    public var petInventory: PetInventoryState
    public var lastSavedDate: Date
    
    enum CodingKeys: String, CodingKey {
        case profile
        case isOnboardingCompleted
        case workoutHistory
        case nutritionTargets
        case foodLogs
        case cycleData
        case rewardInventory
        case petInventory
        case lastSavedDate
    }
    
    public init(
        profile: UserProfile = UserProfile(),
        isOnboardingCompleted: Bool = false,
        workoutHistory: [WorkoutRecord] = [],
        nutritionTargets: NutritionTargets = NutritionTargets(),
        foodLogs: [FoodLog] = [],
        cycleData: CycleData = CycleData(),
        rewardInventory: RewardInventoryState = RewardInventoryState(),
        petInventory: PetInventoryState = PetInventoryState(pets: PetCatalog.defaultCatalog, activePetId: "misskalem_cat"),
        lastSavedDate: Date = Date()
    ) {
        self.profile = profile
        self.isOnboardingCompleted = isOnboardingCompleted
        self.workoutHistory = workoutHistory
        self.nutritionTargets = nutritionTargets
        self.foodLogs = foodLogs
        self.cycleData = cycleData
        self.rewardInventory = rewardInventory
        self.petInventory = petInventory
        self.lastSavedDate = lastSavedDate
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.profile = try container.decodeIfPresent(UserProfile.self, forKey: .profile) ?? UserProfile()
        self.isOnboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .isOnboardingCompleted) ?? false
        self.workoutHistory = try container.decodeIfPresent([WorkoutRecord].self, forKey: .workoutHistory) ?? []
        self.nutritionTargets = try container.decodeIfPresent(NutritionTargets.self, forKey: .nutritionTargets) ?? NutritionTargets()
        self.foodLogs = try container.decodeIfPresent([FoodLog].self, forKey: .foodLogs) ?? []
        self.cycleData = try container.decodeIfPresent(CycleData.self, forKey: .cycleData) ?? CycleData()
        self.rewardInventory = try container.decodeIfPresent(RewardInventoryState.self, forKey: .rewardInventory) ?? RewardInventoryState()
        self.petInventory = try container.decodeIfPresent(PetInventoryState.self, forKey: .petInventory) ?? PetInventoryState(pets: PetCatalog.defaultCatalog, activePetId: "misskalem_cat")
        self.lastSavedDate = try container.decodeIfPresent(Date.self, forKey: .lastSavedDate) ?? Date()
    }
}

/// Service protocol for local persistence operations.
public protocol PersistenceServiceProtocol {
    func load() -> AppDataSnapshot?
    func save(_ snapshot: AppDataSnapshot)
}

/// Robust local JSON file persistence implementation utilizing the application's document directory.
/// Performs safe atomic writes to prevent data corruption.
public final class LocalFilePersistenceService: PersistenceServiceProtocol {
    private let fileURL: URL
    private let fileManager = FileManager.default
    
    public init(fileName: String = "fitbuddy_user_data.json") {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let directory = paths.first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.fileURL = directory.appendingPathComponent(fileName)
    }
    
    public func load() -> AppDataSnapshot? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AppDataSnapshot.self, from: data)
        } catch {
            print("[Persistence] Error loading snapshot from \(fileURL.path): \(error.localizedDescription)")
            return nil
        }
    }
    
    public func save(_ snapshot: AppDataSnapshot) {
        do {
            let directory = fileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: [.atomicWrite, .completeFileProtectionUnlessOpen])
            print("[Persistence] Successfully saved snapshot to \(fileURL.path) (\(data.count) bytes)")
        } catch {
            print("[Persistence] Error saving snapshot to \(fileURL.path): \(error.localizedDescription)")
        }
    }
}
