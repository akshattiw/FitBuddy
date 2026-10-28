import SwiftUI

/// Main "Diet" screen for FitBuddy displaying daily summary, macro rings, actual intake logs,
/// and tailored food suggestions via `NutritionRecommendationProviding`.
/// References `DesignReferences/diet-screen.jpeg`.
public struct DietView: View {
    // MARK: - Injected Dependencies
    private let nutritionService: NutritionRecommendationProviding
    private let userProfile: UserProfile
    @Bindable public var nutritionStore: NutritionDataStore
    public let onProfileTapped: (() -> Void)?
    
    // MARK: - Nutrition Recommendation State Machine
    @State private var recommendedSuggestions: [FoodSuggestion] = []
    @State private var isLoadingRecommendations: Bool = false
    @State private var recommendationError: String? = nil
    
    @State private var showingAddFoodSheet: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    public init(
        nutritionService: NutritionRecommendationProviding = MockNutritionRecommendationService(),
        userProfile: UserProfile = UserProfile(),
        nutritionStore: NutritionDataStore = NutritionDataStore(),
        onProfileTapped: (() -> Void)? = nil
    ) {
        self.nutritionService = nutritionService
        self.userProfile = userProfile
        self.nutritionStore = nutritionStore
        self.onProfileTapped = onProfileTapped
    }
    
    // Current deterministic daily nutrition summary
    private var currentSummary: NutritionSummary {
        nutritionStore.summary(for: Date())
    }
    
    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    // MARK: - Header
                    HStack {
                        Text("Diet")
                            .font(AppTheme.Typography.screenTitle)
                            .foregroundColor(AppColors.primaryText)
                        
                        Spacer()
                        
                        Button {
                            onProfileTapped?()
                        } label: {
                            Circle()
                                .fill(AppColors.softPink.opacity(0.3))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "person.crop.circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppColors.primaryText)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, AppTheme.Spacing.large)
                    .padding(.top, AppTheme.Spacing.small)
                    
                    // MARK: - Daily Summary & Macros Card (Computed Deterministically)
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        HStack {
                            Text("Daily Summary")
                                .font(AppTheme.Typography.cardTitle)
                                .foregroundColor(AppColors.primaryText)
                            Spacer()
                            Text("Macros")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        HStack(spacing: AppTheme.Spacing.extraLarge) {
                            // Multi-color ring progress gauge
                            ZStack {
                                Circle()
                                    .stroke(AppColors.divider, lineWidth: 10)
                                    .frame(width: 100, height: 100)
                                
                                Circle()
                                    .trim(from: 0.0, to: CGFloat(min(1.0, currentSummary.calorieProgressRatio)))
                                    .stroke(
                                        AngularGradient(
                                            gradient: Gradient(colors: [AppColors.softPink, AppColors.peach, AppColors.mint, AppColors.skyBlueAccent]),
                                            center: .center
                                        ),
                                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 100, height: 100)
                                
                                VStack(spacing: 2) {
                                    Text("\(Int(currentSummary.remainingCalories))")
                                        .font(AppTheme.Typography.metricValue)
                                        .foregroundColor(AppColors.primaryText)
                                    Text("kcal left")
                                        .font(AppTheme.Typography.micro)
                                        .foregroundColor(AppColors.secondaryText)
                                }
                            }
                            .padding(.vertical, AppTheme.Spacing.small)
                            
                            // Macro breakdown progress bars
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                                macroRow(
                                    label: "Protein",
                                    current: "\(Int(currentSummary.consumedProteinGrams))g",
                                    target: "\(Int(nutritionStore.targets.proteinGramsTarget))g",
                                    progress: currentSummary.proteinProgressRatio,
                                    color: AppColors.peachAccent
                                )
                                macroRow(
                                    label: "Carbs",
                                    current: "\(Int(currentSummary.consumedCarbohydratesGrams))g",
                                    target: "\(Int(nutritionStore.targets.carbohydratesGramsTarget))g",
                                    progress: currentSummary.carbsProgressRatio,
                                    color: AppColors.skyBlueAccent
                                )
                                macroRow(
                                    label: "Fat",
                                    current: "\(Int(currentSummary.consumedFatGrams))g",
                                    target: "\(Int(nutritionStore.targets.fatGramsTarget))g",
                                    progress: currentSummary.fatProgressRatio,
                                    color: AppColors.softYellow
                                )
                            }
                        }
                    }
                    .padding(AppTheme.Spacing.large)
                    .softCardStyle(colorScheme: colorScheme)
                    .padding(.horizontal, AppTheme.Spacing.large)
                    
                    // Actual intake notice
                    Text("Totals reflect actual logged food items. Daily target: \(Int(nutritionStore.targets.dailyCalorieTarget)) kcal.")
                        .font(AppTheme.Typography.micro)
                        .foregroundColor(AppColors.secondaryText)
                        .padding(.horizontal, AppTheme.Spacing.large)
                    
                    // MARK: - Recommended Foods Section (Protocol Driven)
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                        HStack {
                            Text("Suggested Foods")
                                .font(AppTheme.Typography.sectionHeading)
                                .foregroundColor(AppColors.primaryText)
                            
                            Spacer()
                            
                            Text("For Remaining Macros")
                                .font(AppTheme.Typography.micro)
                                .foregroundColor(AppColors.mint)
                        }
                        .padding(.horizontal, AppTheme.Spacing.large)
                        
                        if isLoadingRecommendations {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .tint(AppColors.mint)
                                Text("Finding healthy suggestions...")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppColors.secondaryText)
                                Spacer()
                            }
                            .padding(.vertical, AppTheme.Spacing.medium)
                        } else if let error = recommendationError {
                            HStack {
                                Text(error)
                                    .font(AppTheme.Typography.micro)
                                    .foregroundColor(AppColors.peachAccent)
                                Spacer()
                                Button("Retry") { loadRecommendations() }
                                    .font(AppTheme.Typography.micro)
                                    .foregroundColor(AppColors.mint)
                            }
                            .padding(.horizontal, AppTheme.Spacing.large)
                        } else if recommendedSuggestions.isEmpty {
                            Text("No suggestions available right now.")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .padding(.horizontal, AppTheme.Spacing.large)
                        } else {
                            // Horizontal carousel of suggestions (keeping them separate from logged foods)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppTheme.Spacing.medium) {
                                    ForEach(recommendedSuggestions) { suggestion in
                                        suggestionCard(suggestion: suggestion)
                                    }
                                }
                                .padding(.horizontal, AppTheme.Spacing.large)
                                .padding(.vertical, AppTheme.Spacing.xxSmall)
                            }
                        }
                    }
                    .padding(.top, AppTheme.Spacing.xxSmall)
                    
                    // MARK: - Log Today's Intake Section
                    HStack {
                        Text("Log Today's Intake")
                            .font(AppTheme.Typography.sectionHeading)
                            .foregroundColor(AppColors.primaryText)
                        
                        Spacer()
                        
                        Text("\(nutritionStore.loggedItems.count) items logged")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .padding(.horizontal, AppTheme.Spacing.large)
                    
                    // Food Items List (Actual Logged Entries)
                    VStack(spacing: AppTheme.Spacing.small) {
                        if nutritionStore.loggedItems.isEmpty {
                            Text("No food items logged for today.")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .padding(AppTheme.Spacing.large)
                        } else {
                            ForEach(nutritionStore.loggedItems) { log in
                                SwipeableFoodLogRow(log: log, colorScheme: colorScheme) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        nutritionStore.deleteFoodLog(id: log.id)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.large)
                    
                    // Clearance for bottom tab bar and floating action button
                    Spacer().frame(height: 100)
                }
            }
            
            // MARK: - Floating Plus Button (Bottom-Right)
            Button {
                showingAddFoodSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(AppColors.mint)
                    .clipShape(Circle())
                    .shadow(color: AppColors.mint.opacity(0.4), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.trailing, AppTheme.Spacing.large)
            .padding(.bottom, 80) // positioned comfortably above bottom tab bar
        }
        .sheet(isPresented: $showingAddFoodSheet) {
            FoodSearchView(nutritionStore: nutritionStore)
        }
        .background(AppColors.background.ignoresSafeArea())
        .task {
            loadRecommendations()
        }
    }
    
    // MARK: - Suggestion Card Helper
    private func suggestionCard(suggestion: FoodSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(suggestion.foodItem.iconSymbol ?? "🥗")
                    .font(.system(size: 24))
                Spacer()
                Text("\(Int(suggestion.estimatedCalories)) kcal (est.)")
                    .font(AppTheme.Typography.micro)
                    .foregroundColor(AppColors.mint)
            }
            
            Text(suggestion.foodItem.name)
                .font(AppTheme.Typography.cardTitle)
                .foregroundColor(AppColors.primaryText)
                .lineLimit(1)
            
            Text(suggestion.formattedSuggestedServing)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppColors.secondaryText)
            
            Text(suggestion.recommendationRationale)
                .font(AppTheme.Typography.micro)
                .foregroundColor(AppColors.secondaryText)
                .lineLimit(2)
                .padding(.top, 2)
        }
        .padding(AppTheme.Spacing.medium)
        .frame(width: 220)
        .softCardStyle(colorScheme: colorScheme)
    }
    
    // MARK: - Macro Row Helper
    private func macroRow(label: String, current: String, target: String, progress: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppColors.primaryText)
                Spacer()
                Text("\(current) / \(target)")
                    .font(AppTheme.Typography.micro)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.divider)
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, min(geo.size.width * CGFloat(progress), geo.size.width)), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
    
    // MARK: - Recommendation Fetching
    private func loadRecommendations() {
        guard !isLoadingRecommendations else { return }
        isLoadingRecommendations = true
        recommendationError = nil
        
        let input = NutritionRecommendationInput(
            userProfile: userProfile,
            fitnessGoal: .generalFitness,
            targets: nutritionStore.targets,
            currentSummary: currentSummary,
            dietaryPreferences: [.omnivore],
            targetMealType: .snack
        )
        
        Task {
            do {
                let suggestions = try await nutritionService.recommendFoods(for: input)
                await MainActor.run {
                    self.recommendedSuggestions = suggestions
                    self.isLoadingRecommendations = false
                }
            } catch {
                await MainActor.run {
                    self.recommendationError = error.localizedDescription
                    self.isLoadingRecommendations = false
                }
            }
        }
    }
}

// MARK: - Swipeable Food Log Row
private struct SwipeableFoodLogRow: View {
    let log: FoodLog
    let colorScheme: ColorScheme
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isDeleting: Bool = false
    
    private let buttonWidth: CGFloat = 80
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete action button revealed behind the card
            HStack {
                Spacer()
                Button(role: .destructive) {
                    performDelete()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20))
                        Text("Delete")
                            .font(AppTheme.Typography.micro)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(width: buttonWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red.opacity(0.88))
                    .cornerRadius(AppTheme.CornerRadius.card)
                }
                .buttonStyle(.plain)
            }
            
            // Primary Food Log Card
            HStack(spacing: AppTheme.Spacing.large) {
                Text(log.snapshot.iconSymbol ?? "🍽️")
                    .font(.system(size: 26))
                    .frame(width: 44, height: 44)
                    .background(AppColors.secondaryCardBackground)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(log.snapshot.foodName)
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text("\(Int(log.totalCalories)) kcal • \(Int(log.totalProteinGrams))g protein")
                        .font(AppTheme.Typography.micro)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.vertical, AppTheme.Spacing.small)
            .background(AppColors.cardBackground)
            .cornerRadius(AppTheme.CornerRadius.card)
            .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 15, coordinateSpace: .local)
                    .onChanged { value in
                        // Only allow swiping to the left
                        if value.translation.width < 0 {
                            offset = value.translation.width
                        } else if offset < 0 {
                            // Can swipe back to close
                            offset = min(0, -buttonWidth + value.translation.width)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            // If swiped hard or past trigger threshold, delete or reveal delete button
                            if value.translation.width < -150 || value.predictedEndTranslation.width < -200 {
                                performDelete()
                            } else if value.translation.width < -buttonWidth / 2 {
                                offset = -buttonWidth
                            } else {
                                offset = 0
                            }
                        }
                    }
            )
        }
        .contentShape(Rectangle())
    }
    
    private func performDelete() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            offset = -UIScreen.main.bounds.width
            isDeleting = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDelete()
        }
    }
}

#Preview {
    DietView()
}
