import SwiftUI

/// Workout detail sheet displaying full routine breakdown, exercises, rest intervals, and estimated metrics.
public struct WorkoutDetailView: View {
    public let workout: Workout
    public let onStartWorkout: () -> Void
    public let onStartExercise: ((Int) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    public init(
        workout: Workout,
        onStartWorkout: @escaping () -> Void,
        onStartExercise: ((Int) -> Void)? = nil
    ) {
        self.workout = workout
        self.onStartWorkout = onStartWorkout
        self.onStartExercise = onStartExercise
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    // Header Overview Card
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        HStack {
                            Text(workout.category.rawValue)
                                .font(AppTheme.Typography.micro)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.mint)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AppColors.mint.opacity(0.18))
                                .clipShape(Capsule())
                            
                            Spacer()
                            
                            Text(workout.difficulty.rawValue)
                                .font(AppTheme.Typography.micro)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        Text(workout.name)
                            .font(AppTheme.Typography.screenTitle)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text(workout.description)
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppColors.secondaryText)
                        
                        if let rationale = workout.aiRecommendationRationale, !rationale.isEmpty {
                            let isOfflineFallback = rationale.hasPrefix("[Offline Fallback]")
                            HStack(alignment: .top, spacing: AppTheme.Spacing.small) {
                                Image(systemName: isOfflineFallback ? "wifi.slash" : "sparkles")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(isOfflineFallback ? AppColors.secondaryText : AppColors.mint)
                                    .padding(.top, 2)
                                
                                Text(rationale)
                                    .font(AppTheme.Typography.micro)
                                    .foregroundColor(isOfflineFallback ? AppColors.secondaryText : AppColors.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(AppTheme.Spacing.small)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(isOfflineFallback ? AppColors.secondaryCardBackground : AppColors.mint.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous))
                        }
                        
                        Divider().background(AppColors.divider)
                        
                        // Estimated stats row
                        HStack(spacing: AppTheme.Spacing.extraLarge) {
                            statItem(title: "Duration (est.)", value: workout.formattedDuration, icon: "clock")
                            statItem(title: "Calories (est.)", value: workout.formattedCaloriesEstimate, icon: "flame")
                            statItem(title: "Exercises", value: "\(workout.exercises.count)", icon: "figure.walk")
                        }
                    }
                    .padding(AppTheme.Spacing.large)
                    .softCardStyle(colorScheme: colorScheme)
                    .padding(.horizontal, AppTheme.Spacing.large)
                    
                    // Equipment Needed
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                        Text("Equipment Needed")
                            .font(AppTheme.Typography.sectionHeading)
                            .foregroundColor(AppColors.primaryText)
                        
                        HStack(spacing: AppTheme.Spacing.small) {
                            ForEach(workout.requiredEquipment) { eq in
                                Text(eq.rawValue)
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
                    
                    // Exercise List Breakdown
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        Text("Exercises (\(workout.exercises.count))")
                            .font(AppTheme.Typography.sectionHeading)
                            .foregroundColor(AppColors.primaryText)
                        
                        VStack(spacing: AppTheme.Spacing.medium) {
                            ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                                exerciseRow(index: index + 1, exercise: exercise)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.large)
                    
                    // Large CTA to begin active session
                    Button {
                        onStartWorkout()
                    } label: {
                        Text("START SESSION")
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
                    
                    Spacer().frame(height: 40)
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
    
    // MARK: - Helpers
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
    
    private func exerciseRow(index: Int, exercise: Exercise) -> some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
            ZStack {
                Circle()
                    .fill(AppColors.mint.opacity(0.18))
                    .frame(width: 32, height: 32)
                Text("\(index)")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.mint)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundColor(AppColors.primaryText)
                
                Text(exercise.description)
                    .font(AppTheme.Typography.micro)
                    .foregroundColor(AppColors.secondaryText)
                
                // Reps / Duration / Rest tags
                HStack(spacing: AppTheme.Spacing.small) {
                    if let sets = exercise.sets, let reps = exercise.repetitions {
                        Text("\(sets) sets × \(reps) reps")
                            .font(AppTheme.Typography.micro)
                            .foregroundColor(AppColors.primaryText)
                    } else if let duration = exercise.durationSeconds {
                        Text("\(Int(duration))s duration")
                            .font(AppTheme.Typography.micro)
                            .foregroundColor(AppColors.primaryText)
                    }
                    
                    if let rest = exercise.restIntervalSeconds, rest > 0 {
                        Text("• Rest: \(Int(rest))s")
                            .font(AppTheme.Typography.micro)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                .padding(.top, 2)
            }
            
            Spacer()
            
            // Play button to start session directly from this exercise
            if let onStartExercise = onStartExercise {
                Button {
                    onStartExercise(index - 1)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(AppColors.mint)
                        .clipShape(Circle())
                        .shadow(color: AppColors.mint.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppTheme.Spacing.medium)
        .softCardStyle(colorScheme: colorScheme)
    }
}
