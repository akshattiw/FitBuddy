import SwiftUI

/// Main "Stats" screen for FitBuddy displaying real workout metrics, muscle engagement map,
/// and weekly progress comparisons.
/// References `DesignReferences/stats-screen.jpeg`.
public struct StatsView: View {
    @Bindable public var historyStore: WorkoutHistoryStore
    
    private let muscleEngagementService = MuscleEngagementService()
    @Environment(\.colorScheme) private var colorScheme
    private let calendar = Calendar.current
    
    public init(historyStore: WorkoutHistoryStore = WorkoutHistoryStore()) {
        self.historyStore = historyStore
    }
    
    // MARK: - Derived Real Metrics
    
    private var thisWeekRecords: [WorkoutRecord] {
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? now
        return historyStore.records(from: startOfWeek, to: endOfWeek)
    }
    
    private var lastWeekRecords: [WorkoutRecord] {
        let now = Date()
        let startOfThisWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let startOfLastWeek = calendar.date(byAdding: .day, value: -7, to: startOfThisWeek) ?? now
        return historyStore.records(from: startOfLastWeek, to: startOfThisWeek)
    }
    
    private var currentEngagement: [MuscleGroup: Double] {
        muscleEngagementService.calculateEngagement(from: historyStore.records)
    }
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                    Text("Stats")
                        .font(AppTheme.Typography.screenTitle)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text("This Week's Activity")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.horizontal, AppTheme.Spacing.large)
                .padding(.top, AppTheme.Spacing.small)
                
                // MARK: - Activity Overview Tiles
                overviewSummaryTiles
                
                // MARK: - Muscle Engagement Section
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    HStack {
                        Text("Muscle Engagement")
                            .font(AppTheme.Typography.cardTitle)
                            .foregroundColor(AppColors.primaryText)
                        
                        Spacer()
                        
                        Text("Active Volume")
                            .font(AppTheme.Typography.micro)
                            .foregroundColor(AppColors.mint)
                    }
                    
                    MuscleMapView(engagement: currentEngagement, engagementService: muscleEngagementService)
                    
                    if historyStore.records.isEmpty {
                        Text("Complete workouts to see muscle engagement load highlights.")
                            .font(AppTheme.Typography.micro)
                            .foregroundColor(AppColors.secondaryText)
                    } else {
                        Text("Highlights reflect actual completed exercise sets over the past 7 days.")
                            .font(AppTheme.Typography.micro)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                .padding(AppTheme.Spacing.large)
                .softCardStyle(colorScheme: colorScheme)
                .padding(.horizontal, AppTheme.Spacing.large)
                
                // MARK: - Weekly Comparison Section
                WeeklyComparisonView(
                    thisWeekRecords: thisWeekRecords,
                    lastWeekRecords: lastWeekRecords
                )
                .padding(.horizontal, AppTheme.Spacing.large)
                
                // MARK: - Recent Completed Workouts List
                recentActivitySection
                
                // Calories estimation disclaimer
                Text("All calorie burn metrics are estimated using routine exertion algorithms. FitBuddy does not claim laboratory measurements.")
                    .font(AppTheme.Typography.micro)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.extraLarge)
                
                // Clearance for bottom tab bar
                Spacer().frame(height: 80)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
    }
    
    // MARK: - Overview Summary Tiles
    private var overviewSummaryTiles: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            statTile(
                title: "Completed",
                value: "\(historyStore.totalWorkoutsCompleted)",
                icon: "figure.walk",
                tint: AppColors.mint
            )
            
            let totalMins = Int(historyStore.totalDurationSeconds / 60)
            statTile(
                title: "Total Time",
                value: "\(totalMins)m",
                icon: "clock.fill",
                tint: AppColors.skyBlueAccent
            )
            
            let totalEstCals = historyStore.records.reduce(0) { $0 + $1.estimatedCaloriesBurned }
            statTile(
                title: "Calories (est.)",
                value: "\(totalEstCals)",
                icon: "flame.fill",
                tint: AppColors.peachAccent
            )
        }
        .padding(.horizontal, AppTheme.Spacing.large)
    }
    
    private func statTile(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(tint)
                Spacer()
            }
            Text(value)
                .font(AppTheme.Typography.metricValue)
                .foregroundColor(AppColors.primaryText)
            Text(title)
                .font(AppTheme.Typography.micro)
                .foregroundColor(AppColors.secondaryText)
        }
        .padding(AppTheme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
        .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
    }
    
    // MARK: - Recent Activity List
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("Recent Activity")
                .font(AppTheme.Typography.sectionHeading)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, AppTheme.Spacing.large)
            
            if historyStore.records.isEmpty {
                VStack(spacing: AppTheme.Spacing.small) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.secondaryText)
                    Text("No Completed Workouts Yet")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppColors.primaryText)
                    Text("When you finish a workout from the Today tab, your duration, exercises, and muscle loads will record here.")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.extraLarge)
                .softCardStyle(colorScheme: colorScheme)
                .padding(.horizontal, AppTheme.Spacing.large)
            } else {
                VStack(spacing: AppTheme.Spacing.small) {
                    ForEach(historyStore.records.prefix(5)) { record in
                        HStack(spacing: AppTheme.Spacing.large) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.mint.opacity(0.18))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(AppColors.mint)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.workoutName)
                                    .font(AppTheme.Typography.cardTitle)
                                    .foregroundColor(AppColors.primaryText)
                                Text("\(record.formattedDuration) • \(record.formattedCaloriesEstimate)")
                                    .font(AppTheme.Typography.micro)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            
                            Spacer()
                            
                            Text(formatDate(record.endDate))
                                .font(AppTheme.Typography.micro)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        .padding(.horizontal, AppTheme.Spacing.medium)
                        .padding(.vertical, AppTheme.Spacing.small)
                        .softCardStyle(colorScheme: colorScheme)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.large)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}

#Preview {
    StatsView()
}
