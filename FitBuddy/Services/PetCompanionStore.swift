import SwiftUI

/// Observable store managing pet companions collection, active selection, and persistence sync.
/// Decouples pet ownership state from view hierarchies per AGENTS.md clean architecture rules.
@Observable
public final class PetCompanionStore {
    public var state: PetInventoryState
    public var onDidChange: (() -> Void)?
    
    public init(
        state: PetInventoryState = PetInventoryState(pets: PetCatalog.defaultCatalog, activePetId: "misskalem_cat"),
        referenceDate: Date = Date()
    ) {
        self.state = state
        // Reconcile on initialization to ensure catalog synchronization and starter pet unlock
        reconcileWithCatalog()
        evaluateHungerAndSurvival(at: referenceDate)
    }
    
    /// The currently selected active companion.
    public var activePet: Pet? {
        state.activePet
    }
    
    /// List of companions currently unlocked and owned by the user.
    public var ownedPets: [Pet] {
        state.ownedPets
    }
    
    /// List of locked companions waiting to be unlocked.
    public var lockedPets: [Pet] {
        state.lockedPets
    }
    
    /// Finds a pet by its unique identifier.
    public func pet(withId id: String) -> Pet? {
        state.pets.first(where: { $0.id == id })
    }
    
    /// Concurrency lock preventing double-spend from rapid repeated taps.
    public private(set) var isFeedingInProgress: Bool = false
    
    /// Evaluates hunger and survival across all owned pets based on elapsed time since `lastFedDate`.
    /// Transitions pets to `.deceased` if they have exceeded the 72-hour starvation threshold.
    /// Missing timestamps on older data are initialized safely to the reference date to avoid killing legacy pets.
    /// Persisted death is strictly irreversible.
    @discardableResult
    public func evaluateHungerAndSurvival(at referenceDate: Date = Date()) -> Bool {
        var changed = false
        for i in state.pets.indices {
            // Only owned pets are subject to hunger and starvation tracking
            guard state.pets[i].isUnlocked else { continue }
            
            // If already deceased, death state is strictly preserved
            if state.pets[i].status == .deceased {
                continue
            }
            
            // Handle legacy data or newly initialized pet with nil lastFedDate safely
            guard let lastFed = state.pets[i].lastFedDate else {
                state.pets[i].lastFedDate = referenceDate
                state.pets[i].status = .healthy
                changed = true
                continue
            }
            
            let elapsed = referenceDate.timeIntervalSince(lastFed)
            if elapsed >= PetCompanionConstants.starvationDuration {
                state.pets[i].status = .deceased
                changed = true
            } else if elapsed >= 48 * 3600 {
                if state.pets[i].status != .starving {
                    state.pets[i].status = .starving
                    changed = true
                }
            } else if elapsed >= 24 * 3600 {
                if state.pets[i].status != .hungry {
                    state.pets[i].status = .hungry
                    changed = true
                }
            } else {
                if state.pets[i].status == .hungry || state.pets[i].status == .starving {
                    state.pets[i].status = .healthy
                    changed = true
                }
            }
        }
        
        if changed {
            onDidChange?()
        }
        return changed
    }
    
    /// Selects an owned companion as the active pet.
    /// Tapping a locked pet returns false and leaves the active pet unchanged.
    @discardableResult
    public func selectActivePet(id: String) -> Bool {
        guard let index = state.pets.firstIndex(where: { $0.id == id }) else {
            return false
        }
        guard state.pets[index].isUnlocked else {
            return false
        }
        
        // Update active flags
        for i in state.pets.indices {
            state.pets[i].isActive = (state.pets[i].id == id)
        }
        state.activePetId = id
        onDidChange?()
        return true
    }
    
    /// Feeds an owned, living pet companion by deducting XP from the authoritative RewardStore balance.
    /// Atomically deducts 10 XP, increments the pet's level by 1, and records the last fed timestamp.
    /// Prevents rapid repeated taps from spending XP multiple times accidentally.
    /// Rejects feeding if pet is dead, locked, or not found, without deducting any XP.
    @discardableResult
    public func feedPet(id: String, rewardStore: RewardStore, currentDate: Date = Date()) -> FeedPetResult {
        guard !isFeedingInProgress else {
            return .alreadyProcessing
        }
        isFeedingInProgress = true
        defer { isFeedingInProgress = false }
        
        // Refresh hunger status first to ensure pet hasn't crossed deadline at this moment
        evaluateHungerAndSurvival(at: currentDate)
        
        guard let index = state.pets.firstIndex(where: { $0.id == id }) else {
            return .petNotFound
        }
        
        let pet = state.pets[index]
        guard pet.isUnlocked else {
            return .petLocked
        }
        
        guard pet.status.isAlive else {
            return .petNotAlive
        }
        
        let cost = PetCompanionConstants.feedingXPCost
        guard rewardStore.state.totalXP >= cost else {
            return .insufficientXP(currentXP: rewardStore.state.totalXP, requiredXP: cost)
        }
        
        guard rewardStore.spendXP(amount: cost, timestamp: currentDate, note: "Fed \(pet.displayName)") else {
            return .insufficientXP(currentXP: rewardStore.state.totalXP, requiredXP: cost)
        }
        
        state.pets[index].level += 1
        state.pets[index].lastFedDate = currentDate
        state.pets[index].status = .energized
        
        let newLevel = state.pets[index].level
        let petName = state.pets[index].displayName
        
        onDidChange?()
        return .success(newLevel: newLevel, petName: petName)
    }
    
    /// Reconciles stored pet state against canonical catalog while preserving user progress and levels.
    public func reconcileWithCatalog(_ catalog: [Pet] = PetCatalog.defaultCatalog) {
        var mergedPets = state.pets
        var changed = false
        
        // 1. If stored state was empty, populate from catalog
        if mergedPets.isEmpty {
            mergedPets = catalog
            changed = true
        } else {
            // Merge each catalog pet
            for catalogPet in catalog {
                if let index = mergedPets.firstIndex(where: { $0.id == catalogPet.id }) {
                    // Update descriptive metadata while preserving user progress
                    mergedPets[index].displayName = catalogPet.displayName
                    mergedPets[index].description = catalogPet.description
                    mergedPets[index].artwork = catalogPet.artwork
                    mergedPets[index].unlockRequirement = catalogPet.unlockRequirement
                } else {
                    // Newly added catalog pet
                    mergedPets.append(catalogPet)
                    changed = true
                }
            }
        }
        
        // 2. Ensure starter cat is always unlocked
        if let starterIndex = mergedPets.firstIndex(where: { $0.id == "misskalem_cat" }) {
            if !mergedPets[starterIndex].isUnlocked {
                mergedPets[starterIndex].isUnlocked = true
                changed = true
            }
        }
        
        // 3. Ensure a valid active pet is selected from owned pets
        let activeExists = mergedPets.contains(where: { $0.id == state.activePetId && $0.isUnlocked })
        if !activeExists {
            let fallbackId = mergedPets.first(where: { $0.isUnlocked })?.id ?? "misskalem_cat"
            state.activePetId = fallbackId
            changed = true
        }
        
        for i in mergedPets.indices {
            mergedPets[i].isActive = (mergedPets[i].id == state.activePetId)
        }
        
        state.pets = mergedPets
        if changed {
            onDidChange?()
        }
    }
}
