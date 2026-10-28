import Foundation

/// Canonical pet catalog definitions for FitBuddy.
/// Decouples the companion catalog definitions from views and storage.
public enum PetCatalog {
    /// Initial default collection containing the starter cat and locked companions.
    public static var defaultCatalog: [Pet] {
        [
            Pet(
                id: "misskalem_cat",
                name: "Kuro",
                displayName: "Shadow Cat",
                artwork: PetArtwork(kind: .gif, identifier: "misskalem-cat-14387_512"),
                description: "An energetic black cat who loves agility sprints, playful jumping jacks, and midnight stretching.",
                isUnlocked: true,
                isActive: true,
                level: 1,
                unlockRequirement: .default,
                status: .energized,
                experiencePoints: 0,
                lastFedDate: Date(),
                unlockedDate: Date()
            ),
            Pet(
                id: "shiba_inu",
                name: "Mochi",
                displayName: "Sunny Shiba",
                artwork: PetArtwork(kind: .systemSymbol, identifier: "dog.fill", symbolTintHex: "#FF9F43"),
                description: "A loyal and spirited pup who thrives on outdoor cardio sessions and high-energy intervals.",
                isUnlocked: false,
                isActive: false,
                level: 1,
                unlockRequirement: .completeWorkouts(count: 3),
                status: .healthy,
                experiencePoints: 0,
                lastFedDate: nil,
                unlockedDate: nil
            ),
            Pet(
                id: "swift_hare",
                name: "Pippin",
                displayName: "Sprint Hare",
                artwork: PetArtwork(kind: .systemSymbol, identifier: "hare.fill", symbolTintHex: "#5CC49E"),
                description: "A lightning-fast companion that rewards consistency and celebrates quick daily tempo runs.",
                isUnlocked: false,
                isActive: false,
                level: 1,
                unlockRequirement: .maintainStreak(days: 5),
                status: .healthy,
                experiencePoints: 0,
                lastFedDate: nil,
                unlockedDate: nil
            ),
            Pet(
                id: "zen_tortoise",
                name: "Bramble",
                displayName: "Zen Tortoise",
                artwork: PetArtwork(kind: .systemSymbol, identifier: "tortoise.fill", symbolTintHex: "#70A1FF"),
                description: "A wise and grounded guardian celebrating patient recovery sessions, mobility flows, and steady habits.",
                isUnlocked: false,
                isActive: false,
                level: 1,
                unlockRequirement: .earnXP(amount: 250),
                status: .resting,
                experiencePoints: 0,
                lastFedDate: nil,
                unlockedDate: nil
            )
        ]
    }
}
