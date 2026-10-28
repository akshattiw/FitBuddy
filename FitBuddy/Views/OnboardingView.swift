import SwiftUI

/// Clean, minimal first-launch onboarding view for FitBuddy.
/// Collects user name and explicit gender choice, persisting them into `AppState`.
public struct OnboardingView: View {
    @Bindable public var appState: AppState
    
    @State private var name: String = ""
    @State private var selectedGender: UserGender? = nil
    @Environment(\.colorScheme) private var colorScheme
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    public var body: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            Spacer()
            
            // Mascot & Welcome Banner
            VStack(spacing: AppTheme.Spacing.small) {
                ZStack {
                    Circle()
                        .fill(AppColors.mint.opacity(0.2))
                        .frame(width: 90, height: 90)
                    
                    Text("🫧")
                        .font(.system(size: 46))
                }
                
                Text("Welcome to FitBuddy")
                    .font(AppTheme.Typography.screenTitle)
                    .foregroundColor(AppColors.primaryText)
                
                Text("Your personalized fitness, nutrition, and wellness companion.")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.large)
            }
            
            Spacer()
            
            // Name Input Card
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Text("What should we call you?")
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundColor(AppColors.primaryText)
                
                TextField("Your Name", text: $name)
                    .font(AppTheme.Typography.body)
                    .padding(AppTheme.Spacing.medium)
                    .background(AppColors.secondaryCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            }
            .padding(AppTheme.Spacing.large)
            .softCardStyle(colorScheme: colorScheme)
            .padding(.horizontal, AppTheme.Spacing.large)
            
            // Gender Selection Card (Governs 4 vs. 5 tab experience)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Text("Select your profile gender")
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundColor(AppColors.primaryText)
                
                Text("Used for body metrics and enables menstrual cycle tracking if female. You can change this anytime.")
                    .font(AppTheme.Typography.micro)
                    .foregroundColor(AppColors.secondaryText)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.small) {
                    ForEach(UserGender.allCases) { gender in
                        let isSelected = selectedGender == gender
                        Button {
                            selectedGender = gender
                        } label: {
                            Text(gender.rawValue)
                                .font(AppTheme.Typography.caption)
                                .fontWeight(isSelected ? .bold : .medium)
                                .foregroundColor(isSelected ? .white : AppColors.primaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(isSelected ? AppColors.mint : AppColors.secondaryCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(AppTheme.Spacing.large)
            .softCardStyle(colorScheme: colorScheme)
            .padding(.horizontal, AppTheme.Spacing.large)
            
            Spacer()
            
            // Get Started CTA
            Button {
                appState.completeOnboarding(name: name.isEmpty ? "Friend" : name, gender: selectedGender)
            } label: {
                Text("GET STARTED")
                    .font(AppTheme.Typography.buttonLabel)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppColors.mint)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
                    .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
            }
            .padding(.horizontal, AppTheme.Spacing.large)
            .padding(.bottom, AppTheme.Spacing.large)
        }
        .background(AppColors.background.ignoresSafeArea())
    }
}
