import SwiftUI

/// Weekly workout performance comparison component.
/// Computes this week vs. last week metrics using actual completed `WorkoutRecord` entries.
public struct WeeklyComparisonView: View {
    public let thisWeekRecords: [WorkoutRecord]
    public let lastWeekRecords: [WorkoutRecord]
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(thisWeekRecords: [WorkoutRecord], lastWeekRecords: [WorkoutRecord]) {
        self.thisWeekRecords = thisWeekRecords
        self.lastWeekRecords = lastWeekRecords
    }
    
    // Aggregated metrics
    private var thisWeekCount: Int { thisWeekRecords.count }
    private var lastWeekCount: Int { lastWeekRecords.count }
    
    private var thisWeekDurationMinutes: Int {
        Int(thisWeekRecords.reduce(0) { $0 + $1.actualDurationSeconds } / 60)
    }
    private var lastWeekDurationMinutes: Int {
        Int(lastWeekRecords.reduce(0) { $0 + $1.actualDurationSeconds } / 60)
    }
    
    private var thisWeekEstimatedCalories: Int {
        thisWeekRecords.reduce(0) { $0 + $1.estimatedCaloriesBurned }
    }
    private var lastWeekEstimatedCalories: Int {
        lastWeekRecords.reduce(0) { $0 + $1.estimatedCaloriesBurned }
    }
    
    // Calculated change indicator
    private var percentageChangeText: (text: String, isPositive: Bool?) {
        guard lastWeekDurationMinutes > 0 else {
            if thisWeekDurationMinutes > 0 {
                return ("+100%", true)
            } else {
                return ("0%", nil)
            }
        }
        let diff = Double(thisWeekDurationMinutes - lastWeekDurationMinutes)
        let percent = Int((diff / Double(lastWeekDurationMinutes)) * 100)
        if percent > 0 {
            return ("+\(percent)%", true)
        } else if percent < 0 {
            return ("\(percent)%", false)
        } else {
            return ("0%", nil)
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            HStack {
                Text("Weekly Comparison")
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                let change = percentageChangeText
                Text(change.text)
                    .font(AppTheme.Typography.micro)
                    .fontWeight(.bold)
                    .foregroundColor(change.isPositive == true ? AppColors.mint : (change.isPositive == false ? AppColors.peachAccent : AppColors.secondaryText))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (change.isPositive == true ? AppColors.mint : (change.isPositive == false ? AppColors.peachAccent : AppColors.secondaryText))
                            .opacity(0.18)
                    )
                    .clipShape(Capsule())
            }
            
            // Side-by-side comparison grid
            HStack(spacing: AppTheme.Spacing.large) {
                comparisonBlock(
                    title: "This Week",
                    sessions: "\(thisWeekCount) sessions",
                    duration: "\(thisWeekDurationMinutes) mins",
                    calories: "\(thisWeekEstimatedCalories) kcal (est.)",
                    isCurrent: true
                )
                
                comparisonBlock(
                    title: "Last Week",
                    sessions: "\(lastWeekCount) sessions",
                    duration: "\(lastWeekDurationMinutes) mins",
                    calories: "\(lastWeekEstimatedCalories) kcal (est.)",
                    isCurrent: false
                )
            }
            
            if lastWeekCount == 0 && thisWeekCount == 0 {
                Text("Complete workouts this week to begin building your progress comparison.")
                    .font(AppTheme.Typography.micro)
                    .foregroundColor(AppColors.secondaryText)
            } else if lastWeekCount == 0 {
                Text("More completed workouts across consecutive weeks are needed for historical comparison.")
                    .font(AppTheme.Typography.micro)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .padding(AppTheme.Spacing.large)
        .softCardStyle(colorScheme: colorScheme)
    }
    
    private func comparisonBlock(title: String, sessions: String, duration: String, calories: String, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(isCurrent ? AppColors.mint : AppColors.secondaryText)
            
            Divider().background(AppColors.divider)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(sessions)
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundColor(AppColors.primaryText)
                
                Text(duration)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppColors.secondaryText)
                
                Text(calories)
                    .font(AppTheme.Typography.micro)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.medium)
        .background(AppColors.secondaryCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
    }
}
