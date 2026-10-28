import SwiftUI

/// Root view for FitBuddy coordinating tab navigation, central AppState, and local persistence.
public struct ContentView: View {
    @State private var selectedTab: AppTab = .diet
    @State private var appState: AppState
    @State private var showingProfileSheet: Bool = false
    @State private var showingPetCollectionSheet: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    
    // Injected recommendation services conforming to domain protocols
    private let workoutRecommendationService: WorkoutRecommendationProviding
    private let nutritionRecommendationService: NutritionRecommendationProviding
    
    public init(
        appState: AppState = AppState(),
        workoutRecommendationService: WorkoutRecommendationProviding = MockWorkoutRecommendationService(),
        nutritionRecommendationService: NutritionRecommendationProviding = MockNutritionRecommendationService()
    ) {
        self._appState = State(initialValue: appState)
        self.workoutRecommendationService = workoutRecommendationService
        self.nutritionRecommendationService = nutritionRecommendationService
    }
    
    /// Single source of truth for visible tabs (Cycle tab only visible when gender is Female)
    private var visibleTabs: [AppTab] {
        AppTab.availableTabs(isCycleTrackingEnabled: appState.profileManager.isCycleTrackingEnabled)
    }
    
    public var body: some View {
        Group {
            if !appState.isOnboardingCompleted {
                // First-launch minimal onboarding flow
                OnboardingView(appState: appState)
            } else {
                mainTabShellView
            }
        }
        // Sheet: Decoupled Profile and Settings
        .sheet(isPresented: $showingProfileSheet) {
            ProfileView(appState: appState)
        }
        // Sheet: Decoupled Pet Collection
        .sheet(isPresented: $showingPetCollectionSheet) {
            PetCollectionView(
                petStore: appState.petStore,
                rewardStore: appState.rewardStore,
                onFeedPet: { petId in
                    appState.feedPet(id: petId)
                }
            )
        }
        // Save state immediately whenever app enters background or becomes inactive, and evaluate hunger when active
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                appState.save()
            } else if newPhase == .active {
                appState.refreshPetHunger()
            }
        }
        .onAppear {
            appState.refreshPetHunger()
        }
    }
    
    private var mainTabShellView: some View {
        ZStack(alignment: .bottom) {
            // Main Content Area per Tab
            Group {
                switch selectedTab {
                case .today:
                    HomeView(
                        recommendationService: workoutRecommendationService,
                        userProfile: appState.profileManager.profile,
                        cycleManager: appState.cycleManager,
                        historyStore: appState.workoutHistoryStore,
                        activePet: appState.petStore.activePet,
                        onProfileTapped: { showingProfileSheet = true },
                        onPetTapped: { showingPetCollectionSheet = true },
                        onWorkoutCompleted: { record in
                            appState.recordCompletedWorkout(record)
                        }
                    )
                case .diet:
                    DietView(
                        nutritionService: nutritionRecommendationService,
                        userProfile: appState.profileManager.profile,
                        nutritionStore: appState.nutritionStore,
                        onProfileTapped: { showingProfileSheet = true }
                    )
                case .cycle:
                    if appState.profileManager.isCycleTrackingEnabled {
                        CycleView(cycleManager: appState.cycleManager)
                    } else {
                        // Fallback safeguard: Never display inaccessible Cycle screen
                        HomeView(
                            recommendationService: workoutRecommendationService,
                            userProfile: appState.profileManager.profile,
                            cycleManager: appState.cycleManager,
                            historyStore: appState.workoutHistoryStore,
                            activePet: appState.petStore.activePet,
                            onProfileTapped: { showingProfileSheet = true },
                            onPetTapped: { showingPetCollectionSheet = true },
                            onWorkoutCompleted: { record in
                                appState.recordCompletedWorkout(record)
                            }
                        )
                    }
                case .stats:
                    StatsView(historyStore: appState.workoutHistoryStore)
                case .rewards:
                    RewardsView(
                        historyStore: appState.workoutHistoryStore,
                        rewardStore: appState.rewardStore
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom Pastel Bottom Tab Bar displaying only available tabs
            AppTabBar(selectedTab: $selectedTab, availableTabs: visibleTabs)
        }
        .background(AppColors.background.ignoresSafeArea())
        // Immediately correct selection if current tab becomes unavailable
        .onChange(of: appState.profileManager.isCycleTrackingEnabled) { _, isEnabled in
            if !isEnabled && selectedTab == .cycle {
                selectedTab = .today
            }
            appState.save()
        }
        .onAppear {
            if !appState.profileManager.isCycleTrackingEnabled && selectedTab == .cycle {
                selectedTab = .today
            }
        }
    }
}

#Preview("Default (Fresh Launch)") {
    ContentView(appState: AppState())
}
