import SwiftUI

/// Tab identifier for the primary tabs in FitBuddy.
public enum AppTab: String, CaseIterable, Identifiable {
    case today = "Today"
    case diet = "Diet"
    case cycle = "Cycle"
    case stats = "Stats"
    case rewards = "Rewards"
    
    public var id: String { rawValue }
    
    /// SF Symbol for each tab
    public var iconName: String {
        switch self {
        case .today:
            return "calendar"
        case .diet:
            return "fork.knife"
        case .cycle:
            return "drop.fill"
        case .stats:
            return "chart.bar.xaxis"
        case .rewards:
            return "gift.fill"
        }
    }
    
    /// Distinct pastel highlight color when tab is active (derived from DesignReferences/)
    public var activeColor: Color {
        switch self {
        case .today:
            return AppColors.mint
        case .diet:
            return AppColors.mint
        case .cycle:
            return AppColors.softPink
        case .stats:
            return AppColors.skyBlueAccent
        case .rewards:
            return AppColors.peachAccent
        }
    }
    
    /// Returns the filtered list of available tabs based on cycle tracking eligibility.
    public static func availableTabs(isCycleTrackingEnabled: Bool) -> [AppTab] {
        if isCycleTrackingEnabled {
            return [.today, .diet, .cycle, .stats, .rewards]
        } else {
            return [.today, .diet, .stats, .rewards]
        }
    }
}

/// Reusable custom bottom tab bar for FitBuddy matching the DesignReferences pastel aesthetic.
public struct AppTabBar: View {
    @Binding public var selectedTab: AppTab
    public let availableTabs: [AppTab]
    @Environment(\.colorScheme) private var colorScheme
    
    public init(selectedTab: Binding<AppTab>, availableTabs: [AppTab] = AppTab.allCases) {
        self._selectedTab = selectedTab
        self.availableTabs = availableTabs
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(availableTabs) { tab in
                let isSelected = selectedTab == tab
                
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: AppTheme.Spacing.xxSmall) {
                        ZStack {
                            // Subtle pastel capsule background when active (as seen on Cycle and Today in designs)
                            if isSelected {
                                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous)
                                    .fill(tab.activeColor.opacity(0.22))
                                    .frame(width: 44, height: 32)
                                    .transition(.scale.combined(with: .opacity))
                            }
                            
                            Image(systemName: tab.iconName)
                                .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? tab.activeColor : AppColors.secondaryText)
                                .frame(height: 24)
                        }
                        .frame(height: 32)
                        
                        Text(tab.rawValue)
                            .font(AppTheme.Typography.micro)
                            .fontWeight(isSelected ? .semibold : .medium)
                            .foregroundColor(isSelected ? AppColors.primaryText : AppColors.secondaryText)
                        
                        // Active indicator dot
                        Circle()
                            .fill(isSelected ? tab.activeColor : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.small)
        .padding(.top, AppTheme.Spacing.small)
        .padding(.bottom, AppTheme.Spacing.xxSmall)
        .background(
            AppColors.cardBackground
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Divider()
                .background(AppColors.divider)
        }
        .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
    }
}

#Preview {
    VStack {
        Spacer()
        AppTabBar(selectedTab: .constant(.today))
    }
    .background(AppColors.background)
}
