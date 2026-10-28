import SwiftUI

/// Main "Cycle" screen for FitBuddy displaying cycle overview, calendar days, period logging, and symptom tracking.
/// References `DesignReferences/cycle-screen.jpeg`.
public struct CycleView: View {
    @Bindable public var cycleManager: CycleDataManager
    
    @State private var showingPeriodLogSheet: Bool = false
    @State private var showingSymptomSheet: Bool = false
    @State private var selectedSymptomForLogging: CycleSymptomType? = nil
    @State private var selectedSymptomIntensity: SymptomIntensity = .mild
    
    // Period logging sheet state
    @State private var periodStartDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var periodEndDate: Date = Date()
    
    @Environment(\.colorScheme) private var colorScheme
    private let calendar = Calendar.current
    
    public init(cycleManager: CycleDataManager = CycleDataManager()) {
        self.cycleManager = cycleManager
    }
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                // MARK: - Header
                HStack {
                    Text("Cycle Tracker")
                        .font(AppTheme.Typography.screenTitle)
                        .foregroundColor(AppColors.primaryText)
                    
                    Spacer()
                    
                    Button {
                        periodStartDate = Date()
                        periodEndDate = Date()
                        hasEndDate = false
                        showingPeriodLogSheet = true
                    } label: {
                        HStack(spacing: AppTheme.Spacing.xxSmall) {
                            Text(currentDateFormatted)
                                .font(AppTheme.Typography.cardTitle)
                                .foregroundColor(AppColors.primaryText)
                            Image(systemName: "pencil")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.mint)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppColors.cardBackground)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.large)
                .padding(.top, AppTheme.Spacing.small)
                
                // Privacy / Opt-in notice if tracking disabled
                if !cycleManager.data.isTrackingEnabled {
                    trackingDisabledBanner
                } else {
                    // MARK: - Top Summary Status Cards (Data-driven)
                    topSummaryCardsView
                    
                    // Prediction Notice & Uncertainty Disclaimer
                    predictionDisclaimerView
                    
                    // MARK: - Calendar Section
                    calendarSectionView
                    
                    // MARK: - Symptoms Section
                    symptomsSectionView
                    
                    // MARK: - Privacy & Adaptation Toggle
                    workoutAdaptationToggleCard
                }
                
                // Clearance for bottom tab bar
                Spacer().frame(height: 80)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        // Sheet: Log Period Entry
        .sheet(isPresented: $showingPeriodLogSheet) {
            periodLogSheetView
        }
        // Sheet: Log Symptom Details
        .sheet(item: $selectedSymptomForLogging) { symptom in
            symptomLoggingSheetView(symptom: symptom)
        }
    }
    
    // MARK: - Top Summary Status Cards
    private var topSummaryCardsView: some View {
        let dayOfCycle = computeCurrentDayOfCycle()
        let predictions = cycleManager.predictions
        
        return HStack(spacing: AppTheme.Spacing.small) {
            summaryCard(
                title: "Cycle Day",
                icon: "heart.fill",
                value: dayOfCycle != nil ? "Day \(dayOfCycle!)" : "Day --",
                background: AppColors.softPink
            )
            
            summaryCard(
                title: "Fertile",
                icon: "star.fill",
                value: predictions != nil ? "Estimated" : "Log Period",
                background: AppColors.softYellow
            )
            
            summaryCard(
                title: "Ovulate",
                icon: "sparkles",
                value: ovulationDaysString(prediction: predictions),
                background: AppColors.lavender
            )
        }
        .padding(.horizontal, AppTheme.Spacing.large)
    }
    
    // MARK: - Disclaimer
    private var predictionDisclaimerView: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundColor(AppColors.secondaryText)
            
            Text("Estimates are statistical calculations based on your recorded dates. FitBuddy does not provide medical certainty or birth control guidance.")
                .font(AppTheme.Typography.micro)
                .foregroundColor(AppColors.secondaryText)
        }
        .padding(.horizontal, AppTheme.Spacing.large)
    }
    
    // MARK: - Calendar Section
    private var calendarSectionView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            HStack {
                Text(currentMonthYearFormatted)
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                Button("+ Log Period") {
                    periodStartDate = Date()
                    periodEndDate = Date()
                    hasEndDate = false
                    showingPeriodLogSheet = true
                }
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppColors.mint)
            }
            
            // Weekday headers
            let weekDays = ["M", "T", "W", "T", "F", "S", "S"]
            HStack {
                ForEach(weekDays.indices, id: \.self) { index in
                    Text(weekDays[index])
                        .font(AppTheme.Typography.micro)
                        .foregroundColor(AppColors.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Month Day Grid
            let daysInMonth = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                // Offset to align Friday 1st for current month
                ForEach(0..<4) { _ in
                    Text("").frame(height: 32)
                }
                
                ForEach(1...daysInMonth, id: \.self) { day in
                    calendarDayCell(day: day)
                }
            }
        }
        .padding(AppTheme.Spacing.large)
        .softCardStyle(colorScheme: colorScheme)
        .padding(.horizontal, AppTheme.Spacing.large)
    }
    
    // MARK: - Symptoms Section
    private var symptomsSectionView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            HStack {
                Text("Symptoms")
                    .font(AppTheme.Typography.sectionHeading)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                if !cycleManager.data.loggedSymptoms.isEmpty {
                    Text("\(cycleManager.data.loggedSymptoms.count) logged")
                        .font(AppTheme.Typography.micro)
                        .foregroundColor(AppColors.secondaryText)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.large)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: AppTheme.Spacing.medium) {
                ForEach(CycleSymptomType.allCases) { symptom in
                    let isLogged = cycleManager.data.loggedSymptoms.contains(where: { $0.type == symptom && calendar.isDateInToday($0.date) })
                    
                    Button {
                        selectedSymptomForLogging = symptom
                    } label: {
                        VStack(spacing: AppTheme.Spacing.xxSmall) {
                            ZStack {
                                Circle()
                                    .fill(isLogged ? AppColors.mint.opacity(0.4) : AppColors.secondaryCardBackground)
                                    .frame(width: 54, height: 54)
                                
                                Image(systemName: symptom.systemIcon)
                                    .font(.system(size: 20))
                                    .foregroundColor(isLogged ? AppColors.mint : AppColors.primaryText)
                            }
                            
                            Text(symptom.rawValue)
                                .font(AppTheme.Typography.micro)
                                .foregroundColor(AppColors.primaryText)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.large)
        }
    }
    
    // MARK: - Workout Adaptation Toggle Card
    private var workoutAdaptationToggleCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            Toggle(isOn: Binding(
                get: { cycleManager.data.allowWorkoutAdaptation },
                set: { cycleManager.toggleWorkoutAdaptation(allowed: $0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Adapt Workouts with Cycle")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppColors.primaryText)
                    Text("Allows your workout recommendations to factor in cycle energy and symptoms. Tracking data is never shared externally.")
                        .font(AppTheme.Typography.micro)
                        .foregroundColor(AppColors.secondaryText)
                }
            }
            .tint(AppColors.mint)
        }
        .padding(AppTheme.Spacing.large)
        .softCardStyle(colorScheme: colorScheme)
        .padding(.horizontal, AppTheme.Spacing.large)
    }
    
    // MARK: - Disabled Banner
    private var trackingDisabledBanner: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 32))
                .foregroundColor(AppColors.secondaryText)
            Text("Cycle Tracking Paused")
                .font(AppTheme.Typography.cardTitle)
                .foregroundColor(AppColors.primaryText)
            Text("Cycle tracking is currently disabled. Your logged history is safely preserved.")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
            
            Button("Resume Tracking") {
                cycleManager.toggleTracking(enabled: true)
            }
            .font(AppTheme.Typography.buttonLabel)
            .foregroundColor(.white)
            .padding(.horizontal, AppTheme.Spacing.large)
            .padding(.vertical, 8)
            .background(AppColors.mint)
            .clipShape(Capsule())
        }
        .padding(AppTheme.Spacing.extraLarge)
        .softCardStyle(colorScheme: colorScheme)
        .padding(.horizontal, AppTheme.Spacing.large)
    }
    
    // MARK: - Period Log Sheet
    private var periodLogSheetView: some View {
        NavigationStack {
            Form {
                Section("Period Start Date") {
                    DatePicker("Start Date", selection: $periodStartDate, displayedComponents: [.date])
                }
                
                Section("Period End Date") {
                    Toggle("Has Ended", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End Date", selection: $periodEndDate, in: periodStartDate..., displayedComponents: [.date])
                    }
                }
                
                if !cycleManager.data.periodEntries.isEmpty {
                    Section("Recorded Periods") {
                        ForEach(cycleManager.data.periodEntries) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("From \(formatDate(entry.startDate))")
                                        .font(AppTheme.Typography.caption)
                                    if let end = entry.endDate {
                                        Text("To \(formatDate(end))")
                                            .font(AppTheme.Typography.micro)
                                            .foregroundColor(AppColors.secondaryText)
                                    } else {
                                        Text("Ongoing")
                                            .font(AppTheme.Typography.micro)
                                            .foregroundColor(AppColors.mint)
                                    }
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    cycleManager.deletePeriod(id: entry.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppColors.peachAccent)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Log Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingPeriodLogSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        cycleManager.logPeriod(startDate: periodStartDate, endDate: hasEndDate ? periodEndDate : nil)
                        showingPeriodLogSheet = false
                    }
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.mint)
                }
            }
        }
    }
    
    // MARK: - Symptom Logging Sheet
    private func symptomLoggingSheetView(symptom: CycleSymptomType) -> some View {
        NavigationStack {
            Form {
                Section("Symptom Details") {
                    HStack {
                        Image(systemName: symptom.systemIcon)
                            .foregroundColor(AppColors.mint)
                        Text(symptom.rawValue)
                            .font(AppTheme.Typography.cardTitle)
                    }
                    
                    Picker("Intensity", selection: $selectedSymptomIntensity) {
                        ForEach(SymptomIntensity.allCases) { intensity in
                            Text(intensity.rawValue).tag(intensity)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("History for \(symptom.rawValue)") {
                    let history = cycleManager.data.loggedSymptoms.filter { $0.type == symptom }
                    if history.isEmpty {
                        Text("No previous logs for this symptom.")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppColors.secondaryText)
                    } else {
                        ForEach(history) { log in
                            HStack {
                                Text(formatDate(log.date))
                                    .font(AppTheme.Typography.caption)
                                Spacer()
                                Text(log.intensity.rawValue)
                                    .font(AppTheme.Typography.micro)
                                    .foregroundColor(AppColors.secondaryText)
                                Button(role: .destructive) {
                                    cycleManager.deleteSymptom(id: log.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppColors.peachAccent)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Log \(symptom.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { selectedSymptomForLogging = nil }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Record") {
                        cycleManager.logSymptom(type: symptom, intensity: selectedSymptomIntensity, date: Date())
                        selectedSymptomForLogging = nil
                    }
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.mint)
                }
            }
        }
    }
    
    // MARK: - Helpers
    private func summaryCard(title: String, icon: String, value: String, background: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(AppTheme.Typography.micro)
                    .foregroundColor(AppColors.secondaryText)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.primaryText.opacity(0.7))
            }
            
            Text(value)
                .font(AppTheme.Typography.cardTitle)
                .foregroundColor(AppColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(AppTheme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous))
        .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
    }
    
    @ViewBuilder
    private func calendarDayCell(day: Int) -> some View {
        let isToday = day == calendar.component(.day, from: Date())
        
        // Check if date falls in recorded period
        let cellDate = makeDateForDay(day)
        let isLoggedPeriod = cellDate != nil && cycleManager.data.periodEntries.contains(where: { $0.contains(date: cellDate!, calendar: calendar) })
        
        // Check if falls in prediction window
        let isPredictedFertile = cellDate != nil && (cycleManager.predictions.map { pred in
            cellDate! >= pred.estimatedFertileWindowStart && cellDate! <= pred.estimatedFertileWindowEnd
        } ?? false)
        
        Text("\(day)")
            .font(AppTheme.Typography.caption)
            .fontWeight(isToday ? .bold : .regular)
            .foregroundColor(AppColors.primaryText)
            .frame(width: 32, height: 32)
            .background(
                Group {
                    if isToday {
                        Circle().stroke(AppColors.mint, lineWidth: 2)
                    } else if isLoggedPeriod {
                        Circle().fill(AppColors.softPink)
                    } else if isPredictedFertile {
                        Circle().fill(AppColors.softYellow)
                    }
                }
            )
    }
    
    private func computeCurrentDayOfCycle() -> Int? {
        guard let latest = cycleManager.data.periodEntries.sorted(by: { $0.startDate < $1.startDate }).last else {
            return nil
        }
        let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: latest.startDate), to: calendar.startOfDay(for: Date())).day ?? 0
        return max(1, diff + 1)
    }
    
    private func ovulationDaysString(prediction: CyclePrediction?) -> String {
        guard let pred = prediction else { return "--" }
        let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: pred.estimatedOvulationDate)).day ?? 0
        if diff > 0 {
            return "in \(diff) Days"
        } else if diff == 0 {
            return "Today"
        } else {
            return "Passed"
        }
    }
    
    private func makeDateForDay(_ day: Int) -> Date? {
        var comps = calendar.dateComponents([.year, .month], from: Date())
        comps.day = day
        return calendar.date(from: comps)
    }
    
    private var currentDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: Date())
    }
    
    private var currentMonthYearFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    CycleView()
}
