# FitBuddy — Agent Guidelines & Permanent Architecture Rules

FitBuddy is a native iOS fitness and health companion built with SwiftUI in Xcode. All AI agents and developers working on this codebase must strictly observe the following rules.

---

## Permanent Engineering Rules

1. **Native SwiftUI & Frameworks First**  
   Use native SwiftUI alongside Apple's first-party frameworks (e.g., `SwiftData` / `CoreData`, `HealthKit`, `Charts`, `Combine`, `Observation`). Avoid heavy third-party UI dependencies unless explicitly requested.

2. **Modular View Hierarchy per Tab**  
   Keep each main tab (`Today`, `Diet`, `Cycle`, `Stats`, `Rewards`) and their respective subpages, sheets, and flows in separate Swift files. Do not lump disparate tab logic into monolith files.

3. **Decouple Profile & Settings from Home**  
   Keep user profile, avatar customization, and settings screens in distinct, standalone files and modules separate from `HomeView.swift` / `TodayView.swift`.

4. **Adhere to `DesignReferences/` Aesthetics**  
   Faithfully replicate the visual style evident in `DesignReferences/`:
   - Soft pastel card backgrounds (subtle peach, pale lavender, warm blue, mint green).
   - High rounded corners (`cornerRadius: 16–24`).
   - Clean iconography, friendly mascots/illustrations, subtle shadows, and spacious padding.
   - Clean custom bottom tab bar with custom active pill/dot indicators.

5. **Clean Architecture Directory Separation**  
   Maintain strict structural separation across:
   - `Models/`: Domain entities and data structures.
   - `Views/`: Tab views, subviews, and detail flows organized by feature.
   - `Components/`: Shared, reusable UI widgets (cards, progress rings, pill buttons, headers).
   - `Services/`: Protocol definitions, mock providers, and network or platform service implementations.
   - `Utilities/`: Helpers, formatting extensions, color palette constants, and style definitions.

6. **Incremental Construction Only**  
   Build the app incrementally in focused, testable tasks. **Never** attempt to scaffold or implement the entire app in one go.

7. **Inspect Before Modifying**  
   Always inspect existing files, previews, and dependencies before making edits. **Never** overwrite or discard unrelated working code.

8. **Single Source of Truth (No Duplicate Models)**  
   Never create duplicate models, contradictory schemas, or incompatible interfaces across features.

9. **Protocol-Driven Recommendations (AI Extensibility)**  
   Keep all workout, recovery, and nutrition recommendations strictly behind protocols (e.g., `WorkoutRecommendationServiceProtocol`, `NutritionAdvisorServiceProtocol`). The UI must bind solely to protocols or ViewModels consuming these protocols, enabling mock services to be replaced by real AI backends without touching SwiftUI view code.

10. **Strict Mock vs. Real Separation**  
    Maintain clean, isolated mock and production implementations for workout routines, dietary meal generation, and recommendations.

11. **Keep Core Systems Independent of AI**  
    Daily workout tracking, calorie/macro calculation, cycle symptom logging, reward passes, streak logic, and local data persistence must function completely independently of external AI services or network connectivity.

12. **Zero Permanent API Keys in iOS Client**  
    **Never** hardcode a permanent Groq or any other third-party AI API key in the iOS client codebase. Production keys must be fetched securely via proxy/keychain or user-configured debug input.

13. **Honest Build & Validation Reporting**  
    Verify builds honestly. Never suppress, hide, or fail to report compilation or runtime errors.

14. **Always Update `BUILD_STATUS.md`**  
    Update [BUILD_STATUS.md](file:///Users/kiet29/Documents/kuch%20to%20hai/kuch%20to%20hai/BUILD_STATUS.md) upon the conclusion of every single implementation task to reflect latest state, models, and next goals.

15. **No False Completion Claims**  
    Never claim a feature or interface is complete if it is merely a stub, shell, or placeholder. Always disclose current limitations clearly.
