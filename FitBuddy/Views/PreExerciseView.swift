import SwiftUI
import Combine

// MARK: - Workout Mode State
public enum WorkoutModeState: Equatable {
    case preview
    case active
    case paused
    case completed
}

// MARK: - Pre-Exercise & Live AI Workout View (Phase 2)
/// Unified one-screen two-state workout interface.
/// Seamlessly transitions from static exercise demonstration (State A) to live camera feed
/// with on-device pose tracking, push-up posture evaluation, real-time repetition counting,
/// and responsive workout statistics (State B).
public struct PreExerciseView: View {
    public let workout: Workout
    @State public var currentExerciseIndex: Int
    public let onFinishWorkout: ((WorkoutRecord) -> Void)?
    
    // Mode & Lifecycle State
    @State private var workoutMode: WorkoutModeState = .preview
    @State private var elapsedActiveSeconds: TimeInterval = 0
    @State private var sessionStartDate: Date? = nil
    @State private var completedReps: Int = 0
    
    // Computer Vision & Pose Tracking
    @StateObject private var cameraManager = CameraCaptureManager.shared
    private let poseDetector = PoseDetector()
    @State private var activeAnalyzer: ExerciseAnalyzer
    @State private var currentLandmarks: [PoseLandmark] = []
    @State private var currentFeedback: ExerciseFeedback = .neutral
    @State private var showingFinishConfirmation: Bool = false
    
    // Timer subscription
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState: AppState?
    
    public init(
        workout: Workout,
        initialExerciseIndex: Int = 0,
        onStartExercise: ((Int) -> Void)? = nil,
        onFinishWorkout: ((WorkoutRecord) -> Void)? = nil
    ) {
        self.workout = workout
        let validatedIndex = (initialExerciseIndex >= 0 && initialExerciseIndex < workout.exercises.count)
            ? initialExerciseIndex
            : 0
        self._currentExerciseIndex = State(initialValue: validatedIndex)
        self.onFinishWorkout = onFinishWorkout
        
        let initialExercise = workout.exercises.indices.contains(validatedIndex)
            ? workout.exercises[validatedIndex]
            : workout.exercises.first ?? Exercise(name: "Exercise", description: "", targetMuscles: [])
        self._activeAnalyzer = State(initialValue: ExerciseAnalyzerFactory.analyzer(for: initialExercise))
    }
    
    public init(
        exerciseItem: ExerciseItemViewModel,
        onStartExercise: @escaping () -> Void
    ) {
        self.init(
            workout: exerciseItem.parentWorkout,
            initialExerciseIndex: exerciseItem.exerciseIndex,
            onStartExercise: { _ in onStartExercise() },
            onFinishWorkout: nil
        )
    }
    
    private var currentExercise: Exercise {
        if currentExerciseIndex >= 0 && currentExerciseIndex < workout.exercises.count {
            return workout.exercises[currentExerciseIndex]
        }
        return workout.exercises.first ?? Exercise(name: "Exercise", description: "", targetMuscles: [])
    }
    
    private var isPushUpExercise: Bool {
        let name = currentExercise.name.lowercased()
        return name.contains("push-up") || name.contains("pushup") || currentExercise.id.uuidString == "push_up"
    }
    
    private var isFirstExercise: Bool {
        currentExerciseIndex == 0
    }
    
    private var isLastExercise: Bool {
        currentExerciseIndex >= max(0, workout.exercises.count - 1)
    }
    
    // MARK: - Calculated Live Statistics
    
    private var estimatedCalories: Double {
        // Base rate ~5.3 kcal/min of active workout + 0.45 kcal per verified repetition
        let timeKcal = (elapsedActiveSeconds / 60.0) * 5.3
        let repKcal = Double(completedReps) * 0.45
        return timeKcal + repKcal
    }
    
    private var completionPercentage: Int {
        if let reps = currentExercise.repetitions, reps > 0 {
            let totalTarget = (currentExercise.sets ?? 1) * reps
            return min(100, Int((Double(completedReps) / Double(max(1, totalTarget))) * 100))
        } else if let duration = currentExercise.durationSeconds, duration > 0 {
            return min(100, Int((elapsedActiveSeconds / duration) * 100))
        }
        return min(100, completedReps * 10)
    }
    
    private var timerDisplayValue: String {
        switch workoutMode {
        case .preview:
            if let duration = currentExercise.durationSeconds {
                let m = Int(duration) / 60
                let s = Int(duration) % 60
                return String(format: "%02d:%02d", m, s)
            }
            return "00:00"
        case .active, .paused, .completed:
            if let duration = currentExercise.durationSeconds {
                let remaining = max(0, Int(duration - elapsedActiveSeconds))
                let m = remaining / 60
                let s = remaining % 60
                return String(format: "%02d:%02d", m, s)
            } else {
                let elapsed = Int(elapsedActiveSeconds)
                let m = elapsed / 60
                let s = elapsed % 60
                return String(format: "%02d:%02d", m, s)
            }
        }
    }
    
    private var timerTitle: String {
        if currentExercise.durationSeconds != nil {
            return workoutMode == .preview ? "Target Duration" : "Remaining Time"
        }
        return workoutMode == .preview ? "Timer" : "Elapsed Time"
    }
    
    // MARK: - View Body
    
    public var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            // Allocate ~38-42% of available height to demonstration/camera media
            let demoHeight = max(200, min(300, availableHeight * 0.38))
            
            VStack(spacing: 0) {
                // Top Header Bar
                topHeaderBar
                    .padding(.horizontal, AppTheme.Spacing.large)
                    .padding(.top, AppTheme.Spacing.medium)
                    .padding(.bottom, AppTheme.Spacing.small)
                
                // Upper Media Container: Horizontal Sliding Transition between Demo and Camera
                ZStack {
                    if workoutMode == .preview {
                        ExerciseDemonstrationArea(
                            exercise: currentExercise,
                            category: workout.category,
                            height: demoHeight
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    } else {
                        LiveCameraPoseContainerView(
                            cameraManager: cameraManager,
                            landmarks: currentLandmarks,
                            feedback: currentFeedback,
                            isPaused: workoutMode == .paused,
                            isUnsupported: !isPushUpExercise
                        )
                        .frame(height: demoHeight)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
                .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
                .padding(.horizontal, AppTheme.Spacing.large)
                
                // Lower Region: Anchored Exercise Prescription, Live Stats, and Controls
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    // Exercise Prescription Header
                    ExercisePrescriptionHeader(
                        exercise: currentExercise,
                        category: workout.category,
                        exerciseIndex: currentExerciseIndex,
                        totalExercises: max(1, workout.exercises.count)
                    )
                    
                    // Unified Live Statistics Dashboard (4-Card Grid + Progress Bar)
                    liveStatsSection
                    
                    Spacer(minLength: 4)
                    
                    // Controls Bar (Previous, Play/Pause/Resume CTA, Next)
                    controlsBar
                        .padding(.bottom, AppTheme.Spacing.small)
                }
                .padding(.horizontal, AppTheme.Spacing.large)
                .padding(.top, AppTheme.Spacing.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(AppColors.background.ignoresSafeArea())
        .onAppear {
            configureCameraPipeline()
        }
        .onDisappear {
            teardownCameraPipeline()
        }
        .onReceive(timer) { _ in
            if workoutMode == .active {
                elapsedActiveSeconds += 1
                
                // For timed exercise, auto-complete when duration reached
                if let duration = currentExercise.durationSeconds, elapsedActiveSeconds >= duration {
                    completeCurrentExercise()
                }
            }
        }
        .alert("Finish Workout?", isPresented: $showingFinishConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Finish & Save", role: .destructive) {
                finishAndSaveWorkout()
            }
        } message: {
            Text("Are you sure you want to complete this workout and save your progress?")
        }
    }
    
    // MARK: - Header Bar
    
    private var topHeaderBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                if workoutMode == .active {
                    Circle()
                        .fill(AppColors.mint)
                        .frame(width: 8, height: 8)
                }
                
                Text(workout.name)
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if workoutMode == .active || workoutMode == .paused {
                Button {
                    showingFinishConfirmation = true
                } label: {
                    Text("Finish")
                        .font(AppTheme.Typography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.mint)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColors.mint.opacity(0.15))
                        .clipShape(Capsule())
                }
            } else {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppColors.secondaryText)
                        .frame(width: 32, height: 32)
                        .background(AppColors.secondaryCardBackground)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Close")
            }
        }
    }
    
    // MARK: - Live Stats Section
    
    private var liveStatsSection: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            // Horizontal Progress Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(workoutMode == .preview ? "Progress" : "Exercise Progress")
                        .font(AppTheme.Typography.micro)
                        .foregroundColor(AppColors.secondaryText)
                    
                    Spacer()
                    
                    Text("\(completionPercentage)%")
                        .font(AppTheme.Typography.micro)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                }
                
                GeometryReader { barGeo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.secondaryCardBackground)
                            .frame(height: 7)
                        
                        Capsule()
                            .fill(AppColors.mint)
                            .frame(
                                width: max(0, min(barGeo.size.width, barGeo.size.width * CGFloat(completionPercentage) / 100.0)),
                                height: 7
                            )
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: completionPercentage)
                    }
                }
                .frame(height: 7)
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.vertical, AppTheme.Spacing.small)
            .softCardStyle(colorScheme: colorScheme)
            
            // 4-Card Statistics Grid
            HStack(spacing: AppTheme.Spacing.small) {
                // Card 1: Timer / Remaining Time
                statCard(
                    title: timerTitle,
                    value: timerDisplayValue,
                    icon: "stopwatch"
                )
                
                // Card 2: Calories Burnt
                statCard(
                    title: "Calories",
                    value: "\(Int(estimatedCalories)) kcal",
                    icon: "flame"
                )
            }
            
            HStack(spacing: AppTheme.Spacing.small) {
                // Card 3: Valid Repetitions Completed
                statCard(
                    title: "Reps Done",
                    value: "\(completedReps) reps",
                    icon: "number"
                )
                
                // Card 4: Percentage Completed
                statCard(
                    title: "Completed",
                    value: "\(completionPercentage)%",
                    icon: "percent"
                )
            }
        }
    }
    
    private func statCard(title: String, value: String, icon: String) -> some View {
        HStack(spacing: AppTheme.Spacing.small) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.mint)
                .frame(width: 28, height: 28)
                .background(AppColors.mint.opacity(0.12))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(AppTheme.Typography.metricValue)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(title)
                    .font(AppTheme.Typography.micro)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .softCardStyle(colorScheme: colorScheme)
    }
    
    // MARK: - Controls Bar
    
    private var controlsBar: some View {
        HStack(spacing: AppTheme.Spacing.extraLarge) {
            Spacer()
            
            // Previous Exercise Button
            Button {
                navigateToPreviousExercise()
            } label: {
                ZStack {
                    Circle()
                        .fill(AppColors.secondaryCardBackground)
                        .frame(width: 48, height: 48)
                        .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
                    
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isFirstExercise ? AppColors.secondaryText.opacity(0.35) : AppColors.primaryText)
                }
            }
            .disabled(isFirstExercise)
            .accessibilityLabel("Previous Exercise")
            
            // Central Primary Play / Pause / Resume Button
            Button {
                toggleWorkoutState()
            } label: {
                ZStack {
                    Circle()
                        .fill(AppColors.mint)
                        .frame(width: 66, height: 66)
                        .shadow(color: AppColors.mint.opacity(0.4), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: centralButtonIcon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: centralButtonIcon == "play.fill" ? 2 : 0)
                }
            }
            .accessibilityLabel(centralButtonAccessibilityLabel)
            
            // Next Exercise Button
            Button {
                navigateToNextExercise()
            } label: {
                ZStack {
                    Circle()
                        .fill(AppColors.secondaryCardBackground)
                        .frame(width: 48, height: 48)
                        .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
                    
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isLastExercise ? AppColors.secondaryText.opacity(0.35) : AppColors.primaryText)
                }
            }
            .disabled(isLastExercise)
            .accessibilityLabel("Next Exercise")
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var centralButtonIcon: String {
        switch workoutMode {
        case .preview, .paused:
            return "play.fill"
        case .active:
            return "pause.fill"
        case .completed:
            return "checkmark"
        }
    }
    
    private var centralButtonAccessibilityLabel: String {
        switch workoutMode {
        case .preview: return "Start Exercise"
        case .active: return "Pause Workout"
        case .paused: return "Resume Workout"
        case .completed: return "Workout Finished"
        }
    }
    
    // MARK: - State Machine & Actions
    
    private func toggleWorkoutState() {
        switch workoutMode {
        case .preview:
            startLiveWorkout()
        case .active:
            pauseLiveWorkout()
        case .paused:
            resumeLiveWorkout()
        case .completed:
            finishAndSaveWorkout()
        }
    }
    
    private func startLiveWorkout() {
        if sessionStartDate == nil {
            sessionStartDate = Date()
        }
        
        // Start camera stream
        cameraManager.startSession()
        activeAnalyzer.setPaused(false)
        
        // Horizontal sliding transition
        withAnimation(.easeInOut(duration: 0.42)) {
            workoutMode = .active
        }
    }
    
    private func pauseLiveWorkout() {
        activeAnalyzer.setPaused(true)
        withAnimation(.easeInOut(duration: 0.25)) {
            workoutMode = .paused
        }
    }
    
    private func resumeLiveWorkout() {
        activeAnalyzer.setPaused(false)
        withAnimation(.easeInOut(duration: 0.25)) {
            workoutMode = .active
        }
    }
    
    private func completeCurrentExercise() {
        if !isLastExercise {
            navigateToNextExercise()
        } else {
            finishAndSaveWorkout()
        }
    }
    
    private func navigateToPreviousExercise() {
        guard currentExerciseIndex > 0 else { return }
        switchExercise(to: currentExerciseIndex - 1)
    }
    
    private func navigateToNextExercise() {
        guard currentExerciseIndex < workout.exercises.count - 1 else { return }
        switchExercise(to: currentExerciseIndex + 1)
    }
    
    private func switchExercise(to newIndex: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentExerciseIndex = newIndex
            completedReps = 0
            currentFeedback = .neutral
            activeAnalyzer = ExerciseAnalyzerFactory.analyzer(for: workout.exercises[newIndex])
            activeAnalyzer.setPaused(workoutMode == .paused)
        }
    }
    
    private func finishAndSaveWorkout() {
        cameraManager.stopSession()
        
        let record = WorkoutRecord(
            workoutId: workout.id,
            workoutName: workout.name,
            category: workout.category,
            startDate: sessionStartDate ?? Date(),
            endDate: Date(),
            actualDurationSeconds: max(1, elapsedActiveSeconds),
            estimatedCaloriesBurned: max(1, Int(estimatedCalories)),
            completedExercises: [
                CompletedExerciseRecord(
                    exerciseId: currentExercise.id,
                    exerciseName: currentExercise.name,
                    setsCompleted: 1,
                    repsCompleted: completedReps,
                    durationSeconds: elapsedActiveSeconds,
                    targetedMuscles: currentExercise.targetMuscles
                )
            ]
        )
        
        // Save to central app state if available
        appState?.recordCompletedWorkout(record)
        onFinishWorkout?(record)
        
        dismiss()
    }
    
    // MARK: - Camera & Vision Processing Pipeline
    
    private func configureCameraPipeline() {
        cameraManager.onFrameCaptured = { sampleBuffer, orientation in
            poseDetector.process(sampleBuffer: sampleBuffer, orientation: orientation) { frame in
                guard let frame = frame else { return }
                
                // Update landmark points for UI rendering
                let landmarks = Array(frame)
                DispatchQueue.main.async {
                    self.currentLandmarks = landmarks
                }
                
                // If active, run exercise analysis on the frame
                if self.workoutMode == .active {
                    let result = self.activeAnalyzer.process(frame: frame)
                    
                    DispatchQueue.main.async {
                        self.currentFeedback = result.feedback
                        
                        if result.isRepetitionComplete || result.completedRepetitions > self.completedReps {
                            self.completedReps = max(self.completedReps + 1, result.completedRepetitions)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            
                            // Check if target repetitions reached for set
                            if let targetReps = self.currentExercise.repetitions, self.completedReps >= targetReps {
                                self.completeCurrentExercise()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func teardownCameraPipeline() {
        cameraManager.onFrameCaptured = nil
        cameraManager.stopSession()
    }
}

// MARK: - PoseFrame Collection Conformance for Easy Landmark Extraction
extension PoseFrame: Sequence {
    public func makeIterator() -> IndexingIterator<[PoseLandmark]> {
        let allIDs = PoseLandmarkID.allCases
        let points = allIDs.compactMap { self[$0] }
        return points.makeIterator()
    }
}

// MARK: - Component A: Exercise Demonstration Area
/// Upper region component designed to hold static demonstration assets in Phase 1,
/// isolated to enable sliding transition to live camera capture with pose tracking in Phase 2.
public struct ExerciseDemonstrationArea: View {
    public let exercise: Exercise
    public let category: WorkoutCategory
    public let height: CGFloat
    
    @Environment(\.colorScheme) private var colorScheme
    
    public var body: some View {
        ZStack {
            // Container Surface
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                .fill(containerBackground)
            
            // Image / Demonstration Content
            if let illustrationName = exercise.illustrationName,
               let uiImage = UIImage(named: illustrationName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .padding(AppTheme.Spacing.medium)
                    .accessibilityLabel("\(exercise.name) demonstration")
            } else if let uiImage = UIImage(named: exercise.name) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .padding(AppTheme.Spacing.medium)
                    .accessibilityLabel("\(exercise.name) demonstration")
            } else {
                // Graceful, intentional vector fallback
                exerciseVectorFallback
            }
            
            // Subtle badge tag indicating demonstration view
            VStack {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 10, weight: .bold))
                        Text("DEMONSTRATION")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.5)
                    }
                    .foregroundColor(AppColors.primaryText.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    
                    Spacer()
                }
                .padding(AppTheme.Spacing.small + 2)
                
                Spacer()
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
    }
    
    private var containerBackground: Color {
        switch category {
        case .stretch:
            return AppColors.skyBlue.opacity(colorScheme == .dark ? 0.25 : 0.45)
        case .strength:
            return AppColors.peach.opacity(colorScheme == .dark ? 0.25 : 0.45)
        case .yoga:
            return AppColors.lavender.opacity(colorScheme == .dark ? 0.25 : 0.45)
        case .cardio:
            return AppColors.softPink.opacity(colorScheme == .dark ? 0.25 : 0.45)
        case .recovery:
            return AppColors.softYellow.opacity(colorScheme == .dark ? 0.25 : 0.45)
        }
    }
    
    private var exerciseVectorFallback: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.6))
                    .frame(width: 86, height: 86)
                
                Image(systemName: iconForExercise(exercise, category: category))
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(accentForCategory(category))
            }
            
            Text("Form Guide & Technique")
                .font(AppTheme.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.secondaryText)
        }
        .padding(AppTheme.Spacing.large)
    }
    
    private func iconForExercise(_ exercise: Exercise, category: WorkoutCategory) -> String {
        let name = exercise.name.lowercased()
        if name.contains("push-up") || name.contains("pushup") {
            return "figure.strengthtraining.traditional"
        } else if name.contains("squat") {
            return "figure.strengthtraining.functional"
        } else if name.contains("plank") || name.contains("crunch") || name.contains("core") {
            return "figure.core.training"
        } else if name.contains("cat-cow") || name.contains("dog") || name.contains("child") {
            return "figure.yoga"
        } else if name.contains("reach") || name.contains("stretch") {
            return "figure.flexibility"
        } else if name.contains("row") || name.contains("press") {
            return "figure.strengthtraining.traditional"
        } else if name.contains("jump") || name.contains("jack") {
            return "figure.jumprope"
        }
        
        switch category {
        case .stretch: return "figure.flexibility"
        case .strength: return "figure.strengthtraining.traditional"
        case .yoga: return "figure.yoga"
        case .cardio: return "figure.run"
        case .recovery: return "figure.cooldown"
        }
    }
    
    private func accentForCategory(_ category: WorkoutCategory) -> Color {
        switch category {
        case .stretch: return AppColors.skyBlueAccent
        case .strength: return AppColors.peachAccent
        case .yoga: return AppColors.lavenderAccent
        case .cardio: return AppColors.peachAccent
        case .recovery: return AppColors.mint
        }
    }
}

// MARK: - Component B: Exercise Prescription Header
public struct ExercisePrescriptionHeader: View {
    public let exercise: Exercise
    public let category: WorkoutCategory
    public let exerciseIndex: Int
    public let totalExercises: Int
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Badges row
            HStack(spacing: AppTheme.Spacing.small) {
                Text("EXERCISE \(exerciseIndex + 1) OF \(totalExercises)")
                    .font(AppTheme.Typography.micro)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.mint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.mint.opacity(0.16))
                    .clipShape(Capsule())
                
                Text(exercise.difficulty.rawValue)
                    .font(AppTheme.Typography.micro)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.secondaryText)
                
                Spacer()
            }
            
            // Exercise Name
            Text(exercise.name)
                .font(AppTheme.Typography.screenTitle)
                .foregroundColor(AppColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            
            // Prescription Info (Sets x Reps or Duration, with Rest)
            HStack(spacing: 6) {
                if let sets = exercise.sets, let reps = exercise.repetitions {
                    Text("\(sets) sets × \(reps) reps")
                        .font(AppTheme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText)
                } else if let duration = exercise.durationSeconds {
                    Text("\(Int(duration))s duration")
                        .font(AppTheme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText)
                }
                
                if let rest = exercise.restIntervalSeconds, rest > 0 {
                    Text("•")
                        .foregroundColor(AppColors.secondaryText)
                    Text("\(Int(rest))s rest")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                if let firstMuscle = exercise.targetMuscles.first {
                    Text("•")
                        .foregroundColor(AppColors.secondaryText)
                    Text(firstMuscle.rawValue)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
            }
        }
    }
}
