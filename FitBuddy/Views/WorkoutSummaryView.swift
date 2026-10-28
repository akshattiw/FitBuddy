import SwiftUI

/// Workout completion summary screen showing actual elapsed duration, exercises finished,
/// and estimated calories burned (clearly labeled as an estimate).
public struct WorkoutSummaryView: View {
    public let record: WorkoutRecord
    public let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(record: WorkoutRecord, onDismiss: @escaping () -> Void) {
        self.record = record
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppTheme.Spacing.large) {
                    // Celebration Banner
                    VStack(spacing: AppTheme.Spacing.small) {
                        ZStack {
                            Circle()
                                .fill(AppColors.mint.opacity(0.2))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 42))
                                .foregroundColor(AppColors.mint)
                        }
                        .padding(.top, AppTheme.Spacing.large)
                        
                        Text("Great Job!")
                            .font(AppTheme.Typography.screenTitle)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("You finished \(record.workoutName)")
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    // Session Performance Metrics Card
                    VStack(spacing: AppTheme.Spacing.medium) {
                        HStack {
                            Text("Session Summary")
                                .font(AppTheme.Typography.cardTitle)
                                .foregroundColor(AppColors.primaryText)
                            Spacer()
                            Text(record.category.rawValue)
                                .font(AppTheme.Typography.micro)
                                .foregroundColor(AppColors.mint)
                        }
                        
                        Divider().background(AppColors.divider)
                        
                        HStack(spacing: AppTheme.Spacing.large) {
                            metricTile(
                                icon: "clock.fill",
                                title: "Actual Time",
                                value: record.formattedDuration,
                                tint: AppColors.skyBlueAccent
                            )
                            
                            metricTile(
                                icon: "flame.fill",
                                title: "Calories (est.)",
                                value: record.formattedCaloriesEstimate,
                                tint: AppColors.peachAccent
                            )
                            
                            metricTile(
                                icon: "figure.walk",
                                title: "Completed",
                                value: "\(record.completedExercises.count)",
                                tint: AppColors.lavenderAccent
                            )
                        }
                    }
                    .padding(AppTheme.Spacing.large)
                    .softCardStyle(colorScheme: colorScheme)
                    .padding(.horizontal, AppTheme.Spacing.large)
                    
                    // Completed Exercises List
                    if !record.completedExercises.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                            Text("Completed Exercises")
                                .font(AppTheme.Typography.sectionHeading)
                                .foregroundColor(AppColors.primaryText)
                                .padding(.horizontal, AppTheme.Spacing.large)
                            
                            VStack(spacing: AppTheme.Spacing.small) {
                                ForEach(record.completedExercises) { item in
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.mint)
                                        
                                        Text(item.exerciseName)
                                            .font(AppTheme.Typography.caption)
                                            .foregroundColor(AppColors.primaryText)
                                        
                                        Spacer()
                                        
                                        if let reps = item.repsCompleted {
                                            Text("\(item.setsCompleted)s × \(reps)r")
                                                .font(AppTheme.Typography.micro)
                                                .foregroundColor(AppColors.secondaryText)
                                        } else if let duration = item.durationSeconds {
                                            Text("\(Int(duration))s")
                                                .font(AppTheme.Typography.micro)
                                                .foregroundColor(AppColors.secondaryText)
                                        }
                                    }
                                    .padding(AppTheme.Spacing.medium)
                                    .softCardStyle(colorScheme: colorScheme)
                                }
                            }
                            .padding(.horizontal, AppTheme.Spacing.large)
                        }
                    }
                    
                    // Note on estimate vs measured
                    Text("Calories are an estimate based on routine load and active duration. FitBuddy does not claim laboratory measurements.")
                        .font(AppTheme.Typography.micro)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.extraLarge)
                    
                    // Done Button
                    Button {
                        onDismiss()
                    } label: {
                        Text("DONE")
                            .font(AppTheme.Typography.buttonLabel)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AppColors.mint)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
                            .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
                    }
                    .padding(.horizontal, AppTheme.Spacing.large)
                    .padding(.top, AppTheme.Spacing.small)
                    
                    Spacer().frame(height: 40)
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func metricTile(icon: String, title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(tint)
            
            Text(value)
                .font(AppTheme.Typography.cardTitle)
                .foregroundColor(AppColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(AppTheme.Typography.micro)
                .foregroundColor(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.small)
        .background(AppColors.secondaryCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
    }
}
