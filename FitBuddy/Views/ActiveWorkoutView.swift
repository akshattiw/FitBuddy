import SwiftUI

/// Active workout screen letting user start, pause, resume, navigate exercises, and finish or cancel.
public struct ActiveWorkoutView: View {
    @Bindable public var tracker: WorkoutSessionTracker
    public let onFinish: (WorkoutRecord) -> Void
    public let onCancel: () -> Void
    
    @State private var showingCancelAlert: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    public init(
        tracker: WorkoutSessionTracker,
        onFinish: @escaping (WorkoutRecord) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.tracker = tracker
        self.onFinish = onFinish
        self.onCancel = onCancel
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.large) {
                // Top Progress Bar
                VStack(spacing: 6) {
                    HStack {
                        Text("Exercise \(tracker.currentExerciseIndex + 1) of \(max(1, tracker.workout.exercises.count))")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        Spacer()
                        
                        Text(tracker.formattedElapsedTime)
                            .font(AppTheme.Typography.metricValue)
                            .foregroundColor(AppColors.primaryText)
                    }
                    
                    ProgressView(value: tracker.progressRatio)
                        .tint(AppColors.mint)
                }
                .padding(.horizontal, AppTheme.Spacing.large)
                .padding(.top, AppTheme.Spacing.small)
                
                // Current Exercise Card
                if let exercise = tracker.currentExercise {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                        HStack {
                            Text(exercise.name)
                                .font(AppTheme.Typography.screenTitle)
                                .foregroundColor(AppColors.primaryText)
                            
                            Spacer()
                            
                            if tracker.completedExerciseIds.contains(exercise.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppColors.mint)
                            }
                        }
                        
                        Text(exercise.description)
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppColors.secondaryText)
                        
                        // Performance targets
                        HStack(spacing: AppTheme.Spacing.large) {
                            if let sets = exercise.sets, let reps = exercise.repetitions {
                                statBadge(title: "Sets", value: "\(sets)")
                                statBadge(title: "Reps", value: "\(reps)")
                            } else if let duration = exercise.durationSeconds {
                                statBadge(title: "Duration", value: "\(Int(duration))s")
                            }
                            
                            if let rest = exercise.restIntervalSeconds, rest > 0 {
                                statBadge(title: "Rest", value: "\(Int(rest))s")
                            }
                        }
                        
                        // Instructions
                        if !exercise.instructions.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Instructions")
                                    .font(AppTheme.Typography.cardTitle)
                                    .foregroundColor(AppColors.primaryText)
                                
                                ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { idx, step in
                                    Text("\(idx + 1). \(step)")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                }
                            }
                            .padding(.top, AppTheme.Spacing.small)
                        }
                        
                        Spacer()
                    }
                    .padding(AppTheme.Spacing.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .softCardStyle(colorScheme: colorScheme)
                    .padding(.horizontal, AppTheme.Spacing.large)
                } else {
                    Spacer()
                    Text("No exercises in this workout.")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppColors.secondaryText)
                    Spacer()
                }
                
                // Active Controls (Play/Pause, Prev/Next, Complete Exercise)
                VStack(spacing: AppTheme.Spacing.medium) {
                    HStack(spacing: AppTheme.Spacing.large) {
                        // Previous Exercise
                        Button {
                            tracker.previousExercise()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 20))
                                .foregroundColor(tracker.isFirstExercise ? AppColors.divider : AppColors.primaryText)
                                .frame(width: 50, height: 50)
                                .background(AppColors.secondaryCardBackground)
                                .clipShape(Circle())
                        }
                        .disabled(tracker.isFirstExercise)
                        
                        // Play / Pause Toggle
                        Button {
                            tracker.togglePlayPause()
                        } label: {
                            Image(systemName: isSessionActive ? "pause.fill" : "play.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 64, height: 64)
                                .background(AppColors.mint)
                                .clipShape(Circle())
                                .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
                        }
                        
                        // Next Exercise
                        Button {
                            tracker.nextExercise()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 20))
                                .foregroundColor(tracker.isLastExercise ? AppColors.divider : AppColors.primaryText)
                                .frame(width: 50, height: 50)
                                .background(AppColors.secondaryCardBackground)
                                .clipShape(Circle())
                        }
                        .disabled(tracker.isLastExercise)
                    }
                    
                    // Mark Exercise Done / Next
                    Button {
                        tracker.markCurrentExerciseCompleted()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Mark Exercise Done")
                        }
                        .font(AppTheme.Typography.buttonLabel)
                        .foregroundColor(AppColors.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(AppColors.secondaryCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
                    }
                    
                    // Finish Workout Session Button
                    Button {
                        let record = tracker.finishSession()
                        onFinish(record)
                    } label: {
                        Text("FINISH WORKOUT")
                            .font(AppTheme.Typography.buttonLabel)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AppColors.mint)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
                            .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.large)
                .padding(.bottom, AppTheme.Spacing.large)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(tracker.workout.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showingCancelAlert = true
                    }
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppColors.peachAccent)
                }
            }
            .alert("Exit Workout?", isPresented: $showingCancelAlert) {
                Button("Exit", role: .destructive) {
                    tracker.cancelSession()
                    onCancel()
                }
                Button("Resume", role: .cancel) {}
            } message: {
                Text("Your session will be cancelled and no completed workout will be recorded.")
            }
            .onAppear {
                tracker.startSession()
            }
        }
    }
    
    private var isSessionActive: Bool {
        if case .active = tracker.state { return true }
        return false
    }
    
    private func statBadge(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppTheme.Typography.metricValue)
                .foregroundColor(AppColors.primaryText)
            Text(title)
                .font(AppTheme.Typography.micro)
                .foregroundColor(AppColors.secondaryText)
        }
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.vertical, AppTheme.Spacing.small)
        .background(AppColors.secondaryCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
    }
}
