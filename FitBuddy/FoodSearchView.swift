import SwiftUI

/// Sheet view allowing users to search a comprehensive food catalog, customize servings,
/// and log food items directly into their daily intake.
public struct FoodSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @Bindable var nutritionStore: NutritionDataStore
    
    @State private var searchText: String = ""
    @State private var selectedCategory: FoodCategory? = nil
    @State private var selectedFoodItem: FoodItem? = nil
    @State private var servingMultiplier: Double = 1.0
    @State private var showAddedToast: Bool = false
    @State private var addedFoodName: String = ""
    
    // Food Catalog: Indian staples + common fruits & vegetables
    private var allFoods: [FoodItem] {
        var items = MockNutritionRecommendationService.indianFoodCatalog
        
        // Add additional common everyday foods if not already included
        let extraFoods: [FoodItem] = [
            FoodItem(
                id: UUID(uuidString: "e1111111-1111-1111-1111-111111111111")!,
                name: "Fresh Apple",
                itemDescription: "Crisp and juicy sweet red apple packed with natural fiber and vitamin C.",
                servingSize: 1,
                servingUnit: .piece,
                calories: 95,
                proteinGrams: 0.5,
                carbohydratesGrams: 25,
                fatGrams: 0.3,
                fibreGrams: 4.4,
                category: .fruits,
                dataSource: .verifiedDatabase,
                iconSymbol: "🍎"
            ),
            FoodItem(
                id: UUID(uuidString: "e2222222-2222-2222-2222-222222222222")!,
                name: "Banana",
                itemDescription: "Natural potassium booster and quick energy source.",
                servingSize: 1,
                servingUnit: .piece,
                calories: 105,
                proteinGrams: 1.3,
                carbohydratesGrams: 27,
                fatGrams: 0.3,
                fibreGrams: 3.1,
                category: .fruits,
                dataSource: .verifiedDatabase,
                iconSymbol: "🍌"
            ),
            FoodItem(
                id: UUID(uuidString: "e3333333-3333-3333-3333-333333333333")!,
                name: "Oatmeal with Milk",
                itemDescription: "Warm rolled oats prepared in semi-skimmed milk.",
                servingSize: 1,
                servingUnit: .cup,
                calories: 160,
                proteinGrams: 6,
                carbohydratesGrams: 28,
                fatGrams: 3,
                fibreGrams: 4,
                category: .grains,
                dataSource: .verifiedDatabase,
                iconSymbol: "🥣"
            ),
            FoodItem(
                id: UUID(uuidString: "e4444444-4444-4444-4444-444444444444")!,
                name: "Almonds (Badaam)",
                itemDescription: "Raw California almonds full of vitamin E, healthy fats, and magnesium.",
                servingSize: 10,
                servingUnit: .piece,
                calories: 70,
                proteinGrams: 2.5,
                carbohydratesGrams: 2.5,
                fatGrams: 6,
                fibreGrams: 1.5,
                category: .legumesNuts,
                dataSource: .verifiedDatabase,
                iconSymbol: "🥜"
            ),
            FoodItem(
                id: UUID(uuidString: "e5555555-5555-5555-5555-555555555555")!,
                name: "Masala Chai (with milk & sugar)",
                itemDescription: "Traditional spiced Indian tea with milk and light sugar.",
                servingSize: 1,
                servingUnit: .cup,
                calories: 90,
                proteinGrams: 2.5,
                carbohydratesGrams: 12,
                fatGrams: 3,
                fibreGrams: 0,
                category: .beverages,
                dataSource: .verifiedDatabase,
                iconSymbol: "☕️"
            ),
            FoodItem(
                id: UUID(uuidString: "e6666666-6666-6666-6666-666666666666")!,
                name: "Idli with Sambar",
                itemDescription: "Steamed fermented rice & lentil cakes paired with vegetable lentil sambar.",
                servingSize: 2,
                servingUnit: .piece,
                calories: 150,
                proteinGrams: 5,
                carbohydratesGrams: 30,
                fatGrams: 1,
                fibreGrams: 3,
                category: .preparedMeals,
                dataSource: .verifiedDatabase,
                iconSymbol: "🥞"
            ),
            FoodItem(
                id: UUID(uuidString: "e7777777-7777-7777-7777-777777777777")!,
                name: "Green Salad (Cucumber, Tomato, Onion)",
                itemDescription: "Fresh raw vegetable kachumber salad seasoned with rock salt and lemon.",
                servingSize: 1,
                servingUnit: .cup,
                calories: 45,
                proteinGrams: 1.5,
                carbohydratesGrams: 9,
                fatGrams: 0.2,
                fibreGrams: 2.5,
                category: .vegetables,
                dataSource: .verifiedDatabase,
                iconSymbol: "🥗"
            ),
            FoodItem(
                id: UUID(uuidString: "e8888888-8888-8888-8888-888888888888")!,
                name: "Whey Protein Shake",
                itemDescription: "1 scoop whey isolate mixed with water.",
                servingSize: 1,
                servingUnit: .cup,
                calories: 120,
                proteinGrams: 24,
                carbohydratesGrams: 2,
                fatGrams: 1.5,
                fibreGrams: 0,
                category: .beverages,
                dataSource: .verifiedDatabase,
                iconSymbol: "🥤"
            )
        ]
        
        for extra in extraFoods {
            if !items.contains(where: { $0.name.lowercased() == extra.name.lowercased() }) {
                items.append(extra)
            }
        }
        
        return items
    }
    
    // Filtered food list based on search text and optional category
    private var filteredFoods: [FoodItem] {
        allFoods.filter { item in
            let matchesCategory = (selectedCategory == nil) || (item.category == selectedCategory)
            guard matchesCategory else { return false }
            
            if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                return true
            }
            let query = searchText.lowercased()
            return item.name.lowercased().contains(query) ||
                   (item.itemDescription?.lowercased().contains(query) ?? false) ||
                   (item.category?.rawValue.lowercased().contains(query) ?? false)
        }
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Search Input Bar
                HStack(spacing: AppTheme.Spacing.small) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.secondaryText)
                        .font(.system(size: 16, weight: .medium))
                    
                    TextField("Search food (e.g., Apple, Dal, Eggs, Paneer)...", text: $searchText)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppColors.primaryText)
                        .autocorrectionDisabled(true)
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.secondaryText)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.vertical, 12)
                .background(AppColors.secondaryCardBackground)
                .cornerRadius(AppTheme.CornerRadius.medium)
                .padding(.horizontal, AppTheme.Spacing.large)
                .padding(.top, AppTheme.Spacing.small)
                
                // MARK: - Category Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.small) {
                        filterChip(title: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        
                        ForEach(FoodCategory.allCases) { category in
                            filterChip(title: category.rawValue, isSelected: selectedCategory == category) {
                                if selectedCategory == category {
                                    selectedCategory = nil
                                } else {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.large)
                    .padding(.vertical, AppTheme.Spacing.small)
                }
                
                Divider()
                    .background(AppColors.divider)
                    .padding(.top, AppTheme.Spacing.xxSmall)
                
                // MARK: - Food Results List
                if filteredFoods.isEmpty {
                    VStack(spacing: AppTheme.Spacing.medium) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(AppColors.secondaryText.opacity(0.6))
                        Text("No matching food items found")
                            .font(AppTheme.Typography.cardTitle)
                            .foregroundColor(AppColors.primaryText)
                        Text("Try searching with a different name or clear category filter.")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Spacing.large)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredFoods) { food in
                            foodRow(food)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Log Food Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppColors.mint)
                }
            }
            // Detail Sheet to configure serving & confirm logging
            .sheet(item: $selectedFoodItem) { food in
                logDetailSheet(for: food)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            // Toast banner when food is logged
            .overlay(alignment: .bottom) {
                if showAddedToast {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.mint)
                        Text("Added \(addedFoodName) to your intake!")
                            .font(AppTheme.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.primaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppTheme.CornerRadius.large)
                    .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
    
    // MARK: - Category Filter Chip
    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(AppTheme.Typography.micro)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? .white : AppColors.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? AppColors.mint
                        : AppColors.secondaryCardBackground
                )
                .cornerRadius(AppTheme.CornerRadius.pill)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Food Item Row
    private func foodRow(_ food: FoodItem) -> some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Text(food.iconSymbol ?? "🍽️")
                .font(.system(size: 28))
                .frame(width: 48, height: 48)
                .background(AppColors.secondaryCardBackground)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 3) {
                Text(food.name)
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundColor(AppColors.primaryText)
                
                Text("\(Int(food.calories)) kcal • \(food.formattedServing)")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppColors.secondaryText)
                
                HStack(spacing: 8) {
                    Text("P: \(Int(food.proteinGrams))g")
                        .foregroundColor(AppColors.peachAccent)
                    Text("C: \(Int(food.carbohydratesGrams))g")
                        .foregroundColor(AppColors.skyBlueAccent)
                    Text("F: \(Int(food.fatGrams))g")
                        .foregroundColor(AppColors.softYellow)
                }
                .font(AppTheme.Typography.micro)
            }
            
            Spacer()
            
            Button {
                servingMultiplier = 1.0
                selectedFoodItem = food
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(AppColors.mint)
            }
            .buttonStyle(.plain)
        }
        .padding(AppTheme.Spacing.medium)
        .softCardStyle(colorScheme: colorScheme)
    }
    
    // MARK: - Food Logging Confirmation Sheet
    private func logDetailSheet(for food: FoodItem) -> some View {
        let computedCalories = food.calories * servingMultiplier
        let computedProtein = food.proteinGrams * servingMultiplier
        let computedCarbs = food.carbohydratesGrams * servingMultiplier
        let computedFat = food.fatGrams * servingMultiplier
        
        return VStack(spacing: AppTheme.Spacing.large) {
            HStack(spacing: AppTheme.Spacing.medium) {
                Text(food.iconSymbol ?? "🍽️")
                    .font(.system(size: 36))
                    .frame(width: 54, height: 54)
                    .background(AppColors.secondaryCardBackground)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(food.name)
                        .font(AppTheme.Typography.sectionHeading)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text("Serving base: \(food.formattedServing)")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
            }
            
            // Serving Stepper / Multiplier
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Number of Servings")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppColors.primaryText)
                    Text(multiplierDisplay(multiplier: servingMultiplier, baseUnit: food.formattedServing))
                        .font(AppTheme.Typography.micro)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button {
                        if servingMultiplier > 0.5 {
                            servingMultiplier -= 0.5
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(servingMultiplier > 0.5 ? AppColors.mint : AppColors.secondaryText.opacity(0.3))
                    }
                    .disabled(servingMultiplier <= 0.5)
                    
                    Text(String(format: "%.1f", servingMultiplier))
                        .font(AppTheme.Typography.sectionHeading)
                        .foregroundColor(AppColors.primaryText)
                        .frame(minWidth: 36)
                    
                    Button {
                        if servingMultiplier < 10.0 {
                            servingMultiplier += 0.5
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.mint)
                    }
                }
            }
            .padding(AppTheme.Spacing.medium)
            .softCardStyle(colorScheme: colorScheme)
            
            // Nutrients Added Preview
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Nutrients to be Logged")
                    .font(AppTheme.Typography.micro)
                    .foregroundColor(AppColors.secondaryText)
                
                HStack(spacing: AppTheme.Spacing.medium) {
                    nutrientPill(title: "Calories", value: "\(Int(computedCalories)) kcal", color: AppColors.mint)
                    nutrientPill(title: "Protein", value: "\(Int(computedProtein))g", color: AppColors.peachAccent)
                    nutrientPill(title: "Carbs", value: "\(Int(computedCarbs))g", color: AppColors.skyBlueAccent)
                    nutrientPill(title: "Fat", value: "\(Int(computedFat))g", color: AppColors.softYellow)
                }
            }
            
            Spacer()
            
            // Confirm Log Button
            Button {
                logFoodItem(food, multiplier: servingMultiplier)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                    Text("Add to Today's Intake")
                }
                .font(AppTheme.Typography.buttonLabel)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppColors.mint)
                .cornerRadius(AppTheme.CornerRadius.medium)
            }
            .buttonStyle(.plain)
        }
        .padding(AppTheme.Spacing.large)
        .background(AppColors.background.ignoresSafeArea())
    }
    
    private func nutrientPill(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppTheme.Typography.cardTitle)
                .foregroundColor(color)
            Text(title)
                .font(AppTheme.Typography.micro)
                .foregroundColor(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AppColors.secondaryCardBackground)
        .cornerRadius(AppTheme.CornerRadius.small)
    }
    
    private func multiplierDisplay(multiplier: Double, baseUnit: String) -> String {
        if multiplier == 1.0 {
            return "1 × (\(baseUnit))"
        } else {
            return "\(String(format: "%.1f", multiplier)) × (\(baseUnit))"
        }
    }
    
    private func logFoodItem(_ food: FoodItem, multiplier: Double) {
        let log = FoodLog(foodItem: food, servingQuantity: multiplier, loggedAt: Date())
        nutritionStore.addFoodLog(log)
        
        let foodName = food.name
        selectedFoodItem = nil
        
        addedFoodName = foodName
        withAnimation(.spring()) {
            showAddedToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut) {
                showAddedToast = false
            }
        }
    }
}
