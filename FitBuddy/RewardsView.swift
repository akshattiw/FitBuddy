import SwiftUI

/// Main "Rewards" screen for FitBuddy displaying real activity calendar, earned streaks,
/// XP level progress, vouchers inventory, and pass redemption.
/// References `DesignReferences/rewards-screen.jpeg`.
public struct RewardsView: View {
    @Bindable public var historyStore: WorkoutHistoryStore
    @Bindable public var rewardStore: RewardStore
    
    // Monthly calendar navigation state
    @State private var currentDisplayMonth: Date = Date()
    
    // Pass redemption confirmation alert state
    @State private var passToRedeem: RewardPassType? = nil
    @State private var showingRedeemConfirmation: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    private let calendar = Calendar.current
    
    public init(
        historyStore: WorkoutHistoryStore = WorkoutHistoryStore(),
        rewardStore: RewardStore = RewardStore()
    ) {
        self.historyStore = historyStore
        self.rewardStore = rewardStore
    }
    
    // Computed streak stats
    private var streakStats: StreakStats {
        rewardStore.streakStats(records: historyStore.records, calendar: calendar, referenceDate: Date())
    }
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                // MARK: - Header & XP / Level Pill
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                        Text("Rewards")
                            .font(AppTheme.Typography.screenTitle)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("Level \(rewardStore.state.currentLevel) • \(rewardStore.state.totalXP) XP Total")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    // Streak Pill
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(streakStats.currentStreakDays > 0 ? AppColors.peachAccent : AppColors.secondaryText)
                        Text("\(streakStats.currentStreakDays) Day Streak")
                            .font(AppTheme.Typography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primaryText)
                    }
                    .padding(.horizontal, AppTheme.Spacing.medium)
                    .padding(.vertical, 8)
                    .background(AppColors.cardBackground)
                    .clipShape(Capsule())
                    .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
                }
                .padding(.horizontal, AppTheme.Spacing.large)
                .padding(.top, AppTheme.Spacing.small)
                
                // MARK: - XP Progress Bar Card
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    HStack {
                        Text("Level \(rewardStore.state.currentLevel) Progress")
                            .font(AppTheme.Typography.cardTitle)
                            .foregroundColor(AppColors.primaryText)
                        Spacer()
                        Text("\(rewardStore.state.currentLevelXPProgress)/100 XP")
                            .font(AppTheme.Typography.micro)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppColors.divider)
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(AppColors.mint)
                                .frame(width: max(0, min(geo.size.width * CGFloat(Double(rewardStore.state.currentLevelXPProgress) / 100.0), geo.size.width)), height: 8)
                        }
                    }
                    .frame(height: 8)
                    
                    Text("Earn 50 XP per completed workout + 1 XP per minute exercised.")
                        .font(AppTheme.Typography.micro)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(AppTheme.Spacing.large)
                .softCardStyle(colorScheme: colorScheme)
                .padding(.horizontal, AppTheme.Spacing.large)
                
                // MARK: - Monthly Activity Calendar Card
                monthlyActivityCalendarCard
                
                // MARK: - My Vouchers Section (Real Inventory & Redemption)
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    HStack {
                        Text("My Vouchers")
                            .font(AppTheme.Typography.sectionHeading)
                            .foregroundColor(AppColors.primaryText)
                        Spacer()
                        Text("Tap to redeem")
                            .font(AppTheme.Typography.micro)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .padding(.horizontal, AppTheme.Spacing.large)
                    
                    VStack(spacing: AppTheme.Spacing.small) {
                        voucherPill(
                            type: .cheatMeal,
                            availableCount: rewardStore.state.availableCount(for: .cheatMeal),
                            background: AppColors.peach,
                            accent: AppColors.peachAccent
                        )
                        
                        voucherPill(
                            type: .restDay,
                            availableCount: rewardStore.state.availableCount(for: .restDay),
                            background: AppColors.lavender,
                            accent: AppColors.lavenderAccent
                        )
                    }
                    .padding(.horizontal, AppTheme.Spacing.large)
                }
                
                // MARK: - Tasks Section (Real Milestone Progress)
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    Text("Tasks")
                        .font(AppTheme.Typography.sectionHeading)
                        .foregroundColor(AppColors.primaryText)
                        .padding(.horizontal, AppTheme.Spacing.large)
                    
                    VStack(spacing: AppTheme.Spacing.medium) {
                        let cheatCycle = streakStats.currentStreakDays % 3
                        taskProgressBar(
                            title: "Earn Cheat Meal Pass",
                            progressText: "\(cheatCycle)/3 consecutive days",
                            progress: Double(cheatCycle) / 3.0,
                            color: AppColors.softPink
                        )
                        
                        let restCycle = streakStats.currentStreakDays % 6
                        taskProgressBar(
                            title: "Earn Rest Day Pass",
                            progressText: "\(restCycle)/6 consecutive days",
                            progress: Double(restCycle) / 6.0,
                            color: AppColors.skyBlueAccent
                        )
                    }
                    .padding(AppTheme.Spacing.large)
                    .softCardStyle(colorScheme: colorScheme)
                    .padding(.horizontal, AppTheme.Spacing.large)
                }
                
                // MARK: - Spin Wheel Preview Section
                spinWheelSection
                
                // MARK: - Activity & XP History Section
                xpHistorySection
                
                // Clearance for bottom tab bar
                Spacer().frame(height: 80)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .onAppear {
            rewardStore.synchronize(with: historyStore.records, calendar: calendar)
        }
        // Pass Redemption Confirmation Alert
        .alert(
            passToRedeem == .cheatMeal ? "Redeem Cheat Meal Pass?" : "Redeem Rest Day Pass?",
            isPresented: $showingRedeemConfirmation
        ) {
            Button("Cancel", role: .cancel) { passToRedeem = nil }
            Button("Redeem", role: .none) {
                if let pass = passToRedeem {
                    if pass == .restDay {
                        rewardStore.redeem(type: .restDay, targetRestDate: calendar.startOfDay(for: Date()))
                    } else {
                        rewardStore.redeem(type: .cheatMeal)
                    }
                    rewardStore.synchronize(with: historyStore.records, calendar: calendar)
                }
                passToRedeem = nil
            }
        } message: {
            if passToRedeem == .cheatMeal {
                Text("This will consume 1 Cheat Meal Pass. Enjoy your mindful reward! (This does not alter your logged food nutrition totals).")
            } else {
                Text("This will protect your streak for today as a planned rest day. It will not falsely mark today as a workout completed.")
            }
        }
    }
    
    // MARK: - Monthly Activity Calendar Card
    private var monthlyActivityCalendarCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            // Month navigation header
            HStack {
                Text(monthYearString(from: currentDisplayMonth))
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                HStack(spacing: AppTheme.Spacing.large) {
                    Button {
                        if let prev = calendar.date(byAdding: .month, value: -1, to: currentDisplayMonth) {
                            currentDisplayMonth = prev
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    Button {
                        if let next = calendar.date(byAdding: .month, value: 1, to: currentDisplayMonth) {
                            currentDisplayMonth = next
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
            }
            
            // Weekday Headers
            let weekDays = ["M", "T", "W", "T", "F", "S", "S"]
            HStack {
                ForEach(weekDays.indices, id: \.self) { idx in
                    Text(weekDays[idx])
                        .font(AppTheme.Typography.micro)
                        .foregroundColor(AppColors.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Days Grid
            let daysInMonth = calendar.range(of: .day, in: .month, for: currentDisplayMonth)?.count ?? 30
            let monthStreakStats = rewardStore.streakStats(records: historyStore.records, calendar: calendar, referenceDate: currentDisplayMonth)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                // Offset calculation for first weekday of month
                let firstDayOffset = firstWeekdayOffset(for: currentDisplayMonth)
                ForEach(0..<firstDayOffset, id: \.self) { _ in
                    Text("").frame(height: 32)
                }
                
                ForEach(1...daysInMonth, id: \.self) { day in
                    calendarCell(day: day, activeDates: monthStreakStats.activeDatesThisMonth)
                }
            }
        }
        .padding(AppTheme.Spacing.large)
        .softCardStyle(colorScheme: colorScheme)
        .padding(.horizontal, AppTheme.Spacing.large)
    }
    
    // MARK: - Calendar Cell Helper
    @ViewBuilder
    private func calendarCell(day: Int, activeDates: Set<Date>) -> some View {
        let cellDate = makeDateForDay(day) ?? Date()
        let isToday = calendar.isDateInToday(cellDate)
        let isPastOrToday = calendar.startOfDay(for: cellDate) <= calendar.startOfDay(for: Date())
        let isWorkoutDone = activeDates.contains(calendar.startOfDay(for: cellDate))
        let isRestDayRedeemed = rewardStore.state.redeemedRestDayDates.contains(calendar.startOfDay(for: cellDate))
        
        ZStack {
            if isWorkoutDone {
                Circle()
                    .fill(AppColors.mint.opacity(0.3))
                    .frame(width: 30, height: 30)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.mint)
            } else if isRestDayRedeemed {
                Circle()
                    .fill(AppColors.lavenderAccent.opacity(0.4))
                    .frame(width: 30, height: 30)
                Image(systemName: "hourglass")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppColors.lavenderAccent)
            } else if isToday {
                Circle()
                    .stroke(AppColors.mint, lineWidth: 2)
                    .frame(width: 30, height: 30)
                Text("\(day)")
                    .font(AppTheme.Typography.micro)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primaryText)
            } else {
                Text("\(day)")
                    .font(AppTheme.Typography.micro)
                    .foregroundColor(isPastOrToday ? AppColors.secondaryText : AppColors.divider)
            }
        }
        .frame(height: 32)
    }
    
    // MARK: - Voucher Pill Component
    private func voucherPill(type: RewardPassType, availableCount: Int, background: Color, accent: Color) -> some View {
        HStack {
            Text("\(type.rawValue) x\(availableCount) \(type.iconSymbol)")
                .font(AppTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primaryText)
            
            Spacer()
            
            if availableCount > 0 {
                Button {
                    passToRedeem = type
                    showingRedeemConfirmation = true
                } label: {
                    Text("Redeem")
                        .font(AppTheme.Typography.micro)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(accent)
                        .clipShape(Capsule())
                }
            } else {
                Text("Locked")
                    .font(AppTheme.Typography.micro)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.vertical, AppTheme.Spacing.medium)
        .background(background)
        .clipShape(Capsule())
        .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
    }
    
    // MARK: - Task Progress Bar
    private func taskProgressBar(title: String, progressText: String, progress: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppColors.primaryText)
                Spacer()
                Text(progressText)
                    .font(AppTheme.Typography.micro)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.divider)
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, min(geo.size.width * CGFloat(progress), geo.size.width)), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
    
    // MARK: - Spin Wheel Section
    private var spinWheelSection: some View {
        HStack(spacing: AppTheme.Spacing.large) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Spin Wheel")
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundColor(AppColors.primaryText)
                
                let needed = max(0, 14 - streakStats.currentStreakDays)
                Text(needed == 0 ? "Unlocked! 🎉" : "Complete \(streakStats.currentStreakDays)/14 Days\nto unlock 🔒")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                AppColors.softPink,
                                AppColors.peach,
                                AppColors.softYellow,
                                AppColors.mint,
                                AppColors.skyBlue,
                                AppColors.lavender,
                                AppColors.softPink
                            ]),
                            center: .center
                        ),
                        lineWidth: 28
                    )
                    .frame(width: 86, height: 86)
                
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 34, height: 34)
                
                Image(systemName: streakStats.currentStreakDays >= 14 ? "gift.fill" : "lock.fill")
                    .font(.system(size: 15))
                    .foregroundColor(streakStats.currentStreakDays >= 14 ? AppColors.mint : AppColors.secondaryText)
            }
        }
        .padding(AppTheme.Spacing.large)
        .softCardStyle(colorScheme: colorScheme)
        .padding(.horizontal, AppTheme.Spacing.large)
    }
    
    // MARK: - Activity & XP History Section
    private var xpHistorySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack {
                Text("XP History")
                    .font(AppTheme.Typography.sectionHeading)
                    .foregroundColor(AppColors.primaryText)
                Spacer()
                Text("\(rewardStore.state.transactions.count) Activities")
                    .font(AppTheme.Typography.micro)
                    .foregroundColor(AppColors.secondaryText)
            }
            .padding(.horizontal, AppTheme.Spacing.large)
            
            if rewardStore.state.transactions.isEmpty {
                VStack(spacing: AppTheme.Spacing.small) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.secondaryText.opacity(0.6))
                    Text("No XP activity yet. Complete workouts or feed companions to see your history here!")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.large)
                .softCardStyle(colorScheme: colorScheme)
                .padding(.horizontal, AppTheme.Spacing.large)
            } else {
                VStack(spacing: AppTheme.Spacing.small) {
                    ForEach(rewardStore.state.transactions.suffix(10).reversed()) { tx in
                        HStack(spacing: AppTheme.Spacing.medium) {
                            ZStack {
                                Circle()
                                    .fill(tx.amount > 0 ? AppColors.mint.opacity(0.18) : AppColors.peach.opacity(0.4))
                                    .frame(width: 38, height: 38)
                                Image(systemName: tx.amount > 0 ? "figure.run" : "fork.knife")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(tx.amount > 0 ? AppColors.mint : AppColors.peachAccent)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tx.note)
                                    .font(AppTheme.Typography.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.primaryText)
                                Text(tx.type.rawValue)
                                    .font(AppTheme.Typography.micro)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            
                            Spacer()
                            
                            Text(tx.amount > 0 ? "+\(tx.amount) XP" : "\(tx.amount) XP")
                                .font(AppTheme.Typography.caption)
                                .fontWeight(.bold)
                                .foregroundColor(tx.amount > 0 ? AppColors.mint : AppColors.peachAccent)
                        }
                        .padding(AppTheme.Spacing.medium)
                        .softCardStyle(colorScheme: colorScheme)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.large)
            }
        }
    }
    
    // MARK: - Calendar Formatters & Helpers
    private func makeDateForDay(_ day: Int) -> Date? {
        var comps = calendar.dateComponents([.year, .month], from: currentDisplayMonth)
        comps.day = day
        return calendar.date(from: comps)
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func firstWeekdayOffset(for date: Date) -> Int {
        var comps = calendar.dateComponents([.year, .month], from: date)
        comps.day = 1
        guard let firstDay = calendar.date(from: comps) else { return 0 }
        // 1 = Sunday, 2 = Monday in default calendar
        let weekday = calendar.component(.weekday, from: firstDay)
        // Convert to Monday = 0 offset
        return (weekday + 5) % 7
    }
}

#Preview {
    RewardsView()
}
