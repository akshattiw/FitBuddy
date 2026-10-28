import SwiftUI

/// Main "Today" screen for FitBuddy displaying daily mood, buddy status, and recommended workouts.
/// References `DesignReferences/today-screen.jpeg`.
///
/// Obtains personalized workout recommendations through any conforming `WorkoutRecommendationProviding`
/// service injected via dependency injection, with full loading, error, and empty states.
public struct HomeView: View {
    // MARK: - Injected Dependencies
    private let recommendationService: WorkoutRecommendationProviding
    private let userProfile: UserProfile
    private let cycleManager: CycleDataManager?
    private let historyStore: WorkoutHistoryStore?
    private let activePet: Pet?
    public let onProfileTapped: (() -> Void)?
    public let onPetTapped: (() -> Void)?
    public let onWorkoutCompleted: ((WorkoutRecord) -> Void)?
    
    // MARK: - Interactive Filter States
    @State private var selectedMood: DailyMood = .happy
    @State private var selectedEquipmentFilter: EquipmentSelection = .allEquipment
    
    // MARK: - Async Recommendation State Machine
    @State private var recommendedWorkouts: [Workout] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    // MARK: - Workout Flow Navigation States
    @State private var selectedDetailWorkout: Workout?
    @State private var selectedExerciseDetail: ExerciseDetailHolder?
    @State private var activeTracker: WorkoutSessionTracker?
    @State private var completedRecord: WorkoutRecord?
    
    @Environment(\.colorScheme) private var colorScheme
    
    /// Flattened individual exercise items linked to their parent workout and index
    private var individualExerciseItems: [ExerciseItemViewModel] {
        var items: [ExerciseItemViewModel] = []
        for workout in recommendedWorkouts {
            for (index, exercise) in workout.exercises.enumerated() {
                items.append(
                    ExerciseItemViewModel(
                        parentWorkout: workout,
                        exerciseIndex: index,
                        exercise: exercise
                    )
                )
            }
        }
        return items
    }
    
    public init(
        recommendationService: WorkoutRecommendationProviding = MockWorkoutRecommendationService(),
        userProfile: UserProfile = UserProfile(),
        cycleManager: CycleDataManager? = nil,
        historyStore: WorkoutHistoryStore? = nil,
        activePet: Pet? = nil,
        onProfileTapped: (() -> Void)? = nil,
        onPetTapped: (() -> Void)? = nil,
        onWorkoutCompleted: ((WorkoutRecord) -> Void)? = nil
    ) {
        self.recommendationService = recommendationService
        self.userProfile = userProfile
        self.cycleManager = cycleManager
        self.historyStore = historyStore
        self.activePet = activePet
        self.onProfileTapped = onProfileTapped
        self.onPetTapped = onPetTapped
        self.onWorkoutCompleted = onWorkoutCompleted
    }
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                // MARK: - Header (Mood selector & Profile placeholder)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                        // Mood selector pill
                        Menu {
                            ForEach(DailyMood.allCases) { mood in
                                Button(mood.rawValue) {
                                    if selectedMood != mood {
                                        selectedMood = mood
                                        loadRecommendations()
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: AppTheme.Spacing.xxSmall) {
                                Text(selectedMood.rawValue)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppColors.primaryText)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            .padding(.horizontal, AppTheme.Spacing.medium)
                            .padding(.vertical, 6)
                            .background(AppColors.cardBackground)
                            .clipShape(Capsule())
                            .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
                        }
                        
                        Text("Today")
                            .font(AppTheme.Typography.screenTitle)
                            .foregroundColor(AppColors.primaryText)
                            .padding(.top, AppTheme.Spacing.xxSmall)
                        
                        Text("Friday, Oct 23")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    // Mascot & Profile Placeholder Stack
                    VStack(alignment: .trailing, spacing: AppTheme.Spacing.small) {
                        // Profile Avatar button (decoupled from home, presents ProfileView)
                        Button {
                            onProfileTapped?()
                        } label: {
                            Circle()
                                .fill(AppColors.mint.opacity(0.2))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppColors.primaryText.opacity(0.6))
                                )
                        }
                        .buttonStyle(.plain)
                        
                        // Animated Pet Companion Button
                        Button {
                            onPetTapped?()
                        } label: {
                            let isDead = activePet?.status == .deceased
                            ZStack {
                                Circle()
                                    .fill(isDead ? AppColors.secondaryCardBackground : AppColors.softPink.opacity(0.6))
                                    .frame(width: 64, height: 64)

                                if let pet = activePet {
                                    PetArtworkView(
                                        artwork: pet.artwork,
                                        isDeceased: !pet.status.isAlive,
                                        size: 56
                                    )
                                } else {
                                    AnimatedGIFView(name: "misskalem-cat-14387_512")
                                        .frame(width: 48, height: 56)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            activePet.map { pet in
                                "\(pet.displayName), Level \(pet.level). \(pet.status.isAlive ? "Alive, \(pet.status.displayLabel)" : "Passed away"). Tap to open Pet Collection."
                            } ?? "Open Pet Collection"
                        )
                        .accessibilityHint("Opens the Pet Collection companion screen")
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.large)
                .padding(.top, AppTheme.Spacing.small)
                
                // MARK: - Workout Section Header & Equipment Filter
                HStack {
                    Text("Exercises")
                        .font(AppTheme.Typography.sectionHeading)
                        .foregroundColor(AppColors.primaryText)
                    
                    Spacer()
                    
                    Menu {
                        ForEach(EquipmentSelection.allCases) { equipment in
                            Button(equipment.rawValue) {
                                if selectedEquipmentFilter != equipment {
                                    selectedEquipmentFilter = equipment
                                    loadRecommendations()
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 12))
                            Text(selectedEquipmentFilter.rawValue)
                                .font(AppTheme.Typography.micro)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, AppTheme.Spacing.medium)
                        .padding(.vertical, 6)
                        .background(AppColors.cardBackground)
                        .clipShape(Capsule())
                        .foregroundColor(AppColors.primaryText)
                        .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.large)
                
                // MARK: - Individual Exercises Content State
                VStack(spacing: AppTheme.Spacing.medium) {
                    if isLoading {
                        loadingStateView
                    } else if let error = errorMessage {
                        errorStateView(error: error)
                    } else if individualExerciseItems.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(individualExerciseItems) { item in
                            exerciseCard(item: item)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.large)
                
                // MARK: - Big Start Action Button
                if let firstWorkout = recommendedWorkouts.first, !isLoading, errorMessage == nil, !individualExerciseItems.isEmpty {
                    Button {
                        startActiveSession(for: firstWorkout, startingExerciseIndex: 0)
                    } label: {
                        Text("START")
                            .font(AppTheme.Typography.buttonLabel)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AppColors.mint)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large, style: .continuous))
                            .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
                    }
                    .padding(.horizontal, AppTheme.Spacing.large)
                    .padding(.top, AppTheme.Spacing.small)
                }
                
                // Bottom spacing for tab bar clearance
                Spacer()
                    .frame(height: 80)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .task {
            loadRecommendations()
        }
        // Sheet: Pre-Exercise & Live AI Workout Screen (Phase 2)
        .sheet(item: $selectedExerciseDetail) { detailHolder in
            PreExerciseView(
                workout: detailHolder.item.parentWorkout,
                initialExerciseIndex: detailHolder.item.exerciseIndex,
                onFinishWorkout: { record in
                    selectedExerciseDetail = nil
                    if let onWorkoutCompleted = onWorkoutCompleted {
                        onWorkoutCompleted(record)
                    } else {
                        historyStore?.addRecord(record)
                    }
                    completedRecord = record
                }
            )
        }
        // Sheet: Workout Detail View
        .sheet(item: $selectedDetailWorkout) { workout in
            WorkoutDetailView(
                workout: workout,
                onStartWorkout: {
                    selectedDetailWorkout = nil
                    startActiveSession(for: workout)
                },
                onStartExercise: { exerciseIndex in
                    selectedDetailWorkout = nil
                    startActiveSession(for: workout, startingExerciseIndex: exerciseIndex)
                }
            )
        }
        // Fullscreen: Active Workout Tracker
        .fullScreenCover(item: Binding<WorkoutSessionTrackerHolder?>(
            get: { activeTracker.map { WorkoutSessionTrackerHolder(tracker: $0) } },
            set: { activeTracker = $0?.tracker }
        )) { holder in
            ActiveWorkoutView(
                tracker: holder.tracker,
                onFinish: { record in
                    activeTracker = nil
                    if let onWorkoutCompleted = onWorkoutCompleted {
                        onWorkoutCompleted(record)
                    } else {
                        historyStore?.addRecord(record)
                    }
                    completedRecord = record
                },
                onCancel: {
                    activeTracker = nil
                }
            )
        }
        // Sheet: Workout Summary
        .sheet(item: $completedRecord) { record in
            WorkoutSummaryView(record: record) {
                completedRecord = nil
            }
        }
    }
    
    // MARK: - Loading, Error & Empty States
    
    private var loadingStateView: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColors.mint)
            Text("Personalizing daily routines...")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xxLarge)
    }
    
    private func errorStateView(error: String) -> some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(AppColors.peachAccent)
            
            Text("Unable to load workouts")
                .font(AppTheme.Typography.cardTitle)
                .foregroundColor(AppColors.primaryText)
            
            Text(error)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
            
            Button {
                loadRecommendations()
            } label: {
                Text("Retry")
                    .font(AppTheme.Typography.buttonLabel)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppTheme.Spacing.extraLarge)
                    .padding(.vertical, AppTheme.Spacing.small)
                    .background(AppColors.mint)
                    .clipShape(Capsule())
            }
            .padding(.top, AppTheme.Spacing.small)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.large)
        .softCardStyle(colorScheme: colorScheme)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            Image(systemName: "figure.walk")
                .font(.system(size: 32))
                .foregroundColor(AppColors.secondaryText)
            
            Text("No matching exercises found")
                .font(AppTheme.Typography.cardTitle)
                .foregroundColor(AppColors.primaryText)
            
            Text("Try choosing another equipment filter or adjusting your mood.")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.large)
        .softCardStyle(colorScheme: colorScheme)
    }
    
    // MARK: - Individual Exercise Card Component
    private func exerciseCard(item: ExerciseItemViewModel) -> some View {
        let visualTheme = visualTheme(for: item.parentWorkout.category, exercise: item.exercise)
        
        return HStack(spacing: AppTheme.Spacing.medium) {
            // Tappable main card area opening detailed exercise instruction sheet
            Button {
                selectedExerciseDetail = ExerciseDetailHolder(item: item)
            } label: {
                HStack(spacing: AppTheme.Spacing.medium) {
                    // Pose / Activity Illustration Icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.45))
                            .frame(width: 52, height: 52)
                        
                        Image(systemName: visualTheme.systemImage)
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.primaryText)
                    }
                    .padding(.leading, 2)
                    
                    // Exercise Information
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.exercise.name)
                            .font(AppTheme.Typography.cardTitle)
                            .foregroundColor(AppColors.primaryText)
                            .lineLimit(1)
                        
                        Text(exerciseMetricsText(for: item.exercise))
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        // Subtle parent category tag
                        Text(item.parentWorkout.name)
                            .font(AppTheme.Typography.micro)
                            .foregroundColor(visualTheme.accentColor)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            // Dedicated Play Button starting directly from this exercise
            Button {
                startActiveSession(for: item.parentWorkout, startingExerciseIndex: item.exerciseIndex)
            } label: {
                ZStack {
                    Circle()
                        .fill(visualTheme.accentColor)
                        .frame(width: 38, height: 38)
                        .shadow(color: visualTheme.accentColor.opacity(0.35), radius: 5, x: 0, y: 3)
                    
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: 1)
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, AppTheme.Spacing.small)
        }
        .padding(.vertical, AppTheme.Spacing.medium)
        .padding(.horizontal, AppTheme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(visualTheme.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
        .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
    }
    
    // MARK: - Metric string helper for Exercise
    private func exerciseMetricsText(for exercise: Exercise) -> String {
        if let sets = exercise.sets, let reps = exercise.repetitions {
            return "\(sets) sets × \(reps) reps"
        } else if let duration = exercise.durationSeconds {
            let mins = Int(duration) / 60
            let secs = Int(duration) % 60
            if mins > 0 && secs == 0 {
                return "\(mins) min duration"
            } else if mins > 0 {
                return "\(mins)m \(secs)s duration"
            } else {
                return "\(Int(duration))s duration"
            }
        }
        return "Bodyweight Routine"
    }
    
    private var currentDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
    
    // MARK: - Active Session Launcher
    private func startActiveSession(for workout: Workout, startingExerciseIndex: Int = 0) {
        let tracker = WorkoutSessionTracker(workout: workout, startingExerciseIndex: startingExerciseIndex)
        self.activeTracker = tracker
    }
    
    // MARK: - Recommendation Fetching
    private func loadRecommendations() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        let cyclePhase = cycleManager?.data.currentPhase()
        let cycleSymptoms = cycleManager?.data.recentSymptomNames() ?? []
        
        let input = WorkoutRecommendationInput(
            userProfile: userProfile,
            fitnessGoal: .generalFitness,
            dailyMood: selectedMood,
            availableEquipment: selectedEquipmentFilter.equipmentTypes,
            availableTimeSeconds: 1500, // 25 minutes budget
            cyclePhase: cyclePhase,
            cycleSymptoms: cycleSymptoms
        )
        
        Task {
            do {
                let workouts = try await recommendationService.recommendWorkouts(for: input)
                await MainActor.run {
                    self.recommendedWorkouts = workouts
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Visual Styling Helper
    private func visualTheme(for category: WorkoutCategory, exercise: Exercise? = nil) -> (cardColor: Color, accentColor: Color, systemImage: String) {
        let systemImage: String
        if let primaryMuscle = exercise?.targetMuscles.first {
            switch primaryMuscle {
            case .chest, .triceps:
                systemImage = "figure.strengthtraining.traditional"
            case .back, .biceps:
                systemImage = "figure.strengthtraining.functional"
            case .core:
                systemImage = "figure.core.training"
            case .quads, .hamstrings, .calves, .glutes:
                systemImage = "figure.walk"
            case .shoulders, .fullBody:
                systemImage = "figure.cross.training"
            }
        } else {
            switch category {
            case .stretch:
                systemImage = "figure.walk"
            case .strength:
                systemImage = "figure.strengthtraining.traditional"
            case .yoga:
                systemImage = "figure.mind.and.body"
            case .cardio:
                systemImage = "figure.run"
            case .recovery:
                systemImage = "figure.cooldown"
            }
        }
        
        switch category {
        case .stretch:
            return (AppColors.skyBlue, AppColors.skyBlueAccent, systemImage)
        case .strength:
            return (AppColors.peach, AppColors.peachAccent, systemImage)
        case .yoga:
            return (AppColors.lavender, AppColors.lavenderAccent, systemImage)
        case .cardio:
            return (AppColors.softPink, AppColors.peachAccent, systemImage)
        case .recovery:
            return (AppColors.softYellow, AppColors.mint, systemImage)
        }
    }
}

// MARK: - Helper View Model for Flattened Exercises
public struct ExerciseItemViewModel: Identifiable {
    public var id: UUID { exercise.id }
    public let parentWorkout: Workout
    public let exerciseIndex: Int
    public let exercise: Exercise
}

// MARK: - Helper wrapper for Identifiable Sheet presentation
public struct ExerciseDetailHolder: Identifiable {
    public var id: UUID { item.id }
    public let item: ExerciseItemViewModel
}

// MARK: - Individual Exercise Detail Sheet
public struct ExerciseDetailSheet: View {
    public let item: ExerciseItemViewModel
    public let onStartExercise: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    // Header Card
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        HStack {
                            Text(item.parentWorkout.category.rawValue)
                                .font(AppTheme.Typography.micro)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.mint)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AppColors.mint.opacity(0.18))
                                .clipShape(Capsule())
                            
                            Spacer()
                            
                            Text(item.exercise.difficulty.rawValue)
                                .font(AppTheme.Typography.micro)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        Text(item.exercise.name)
                            .font(AppTheme.Typography.screenTitle)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text(item.exercise.description)
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppColors.secondaryText)
                        
                        Divider().background(AppColors.divider)
                        
                        // Performance targets
                        HStack(spacing: AppTheme.Spacing.large) {
                            if let sets = item.exercise.sets, let reps = item.exercise.repetitions {
                                statItem(title: "Sets", value: "\(sets)", icon: "repeat")
                                statItem(title: "Reps", value: "\(reps)", icon: "number")
                            } else if let duration = item.exercise.durationSeconds {
                                statItem(title: "Duration", value: "\(Int(duration))s", icon: "clock")
                            }
                            
                            if let rest = item.exercise.restIntervalSeconds, rest > 0 {
                                statItem(title: "Rest", value: "\(Int(rest))s", icon: "pause.circle")
                            }
                        }
                    }
                    .padding(AppTheme.Spacing.large)
                    .softCardStyle(colorScheme: colorScheme)
                    .padding(.horizontal, AppTheme.Spacing.large)
                    
                    // Targeted Muscles & Equipment
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                        Text("Targeted Muscles")
                            .font(AppTheme.Typography.sectionHeading)
                            .foregroundColor(AppColors.primaryText)
                        
                        HStack(spacing: AppTheme.Spacing.small) {
                            ForEach(item.exercise.targetMuscles) { muscle in
                                Text(muscle.rawValue)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppColors.primaryText)
                                    .padding(.horizontal, AppTheme.Spacing.medium)
                                    .padding(.vertical, 6)
                                    .background(AppColors.secondaryCardBackground)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.large)
                    
                    // Instructions
                    if !item.exercise.instructions.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                            Text("Instructions")
                                .font(AppTheme.Typography.sectionHeading)
                                .foregroundColor(AppColors.primaryText)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(item.exercise.instructions.enumerated()), id: \.offset) { idx, step in
                                    HStack(alignment: .top, spacing: AppTheme.Spacing.small) {
                                        Text("\(idx + 1).")
                                            .font(AppTheme.Typography.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppColors.mint)
                                        Text(step)
                                            .font(AppTheme.Typography.caption)
                                            .foregroundColor(AppColors.secondaryText)
                                    }
                                }
                            }
                            .padding(AppTheme.Spacing.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .softCardStyle(colorScheme: colorScheme)
                        }
                        .padding(.horizontal, AppTheme.Spacing.large)
                    }
                    
                    // Start Session from this Exercise Button
                    Button {
                        onStartExercise()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("START EXERCISE")
                                .font(AppTheme.Typography.buttonLabel)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppColors.mint)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large, style: .continuous))
                        .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
                    }
                    .padding(.horizontal, AppTheme.Spacing.large)
                    .padding(.top, AppTheme.Spacing.small)
                    
                    Spacer().frame(height: 30)
                }
                .padding(.top, AppTheme.Spacing.large)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppColors.mint)
                }
            }
        }
    }
    
    private func statItem(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(AppTheme.Typography.micro)
            }
            .foregroundColor(AppColors.secondaryText)
            
            Text(value)
                .font(AppTheme.Typography.cardTitle)
                .foregroundColor(AppColors.primaryText)
        }
    }
}

// MARK: - Helper wrapper for fullScreenCover Identifiable requirement
private struct WorkoutSessionTrackerHolder: Identifiable {
    let id = UUID()
    let tracker: WorkoutSessionTracker
}

// MARK: - Equipment Selection Helper
private enum EquipmentSelection: String, CaseIterable, Identifiable {
    case allEquipment = "All Equipment"
    case bodyweightOnly = "Bodyweight Only"
    case dumbbells = "Dumbbells"
    case resistanceBands = "Resistance Bands"
    
    var id: String { rawValue }
    
    var equipmentTypes: [EquipmentType] {
        switch self {
        case .allEquipment:
            return EquipmentType.allCases
        case .bodyweightOnly:
            return [.none]
        case .dumbbells:
            return [.none, .dumbbells]
        case .resistanceBands:
            return [.none, .resistanceBands]
        }
    }
}

#Preview {
    HomeView()
}
