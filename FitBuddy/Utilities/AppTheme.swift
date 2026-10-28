import SwiftUI

/// Centralized design system definitions for FitBuddy, consolidating typography,
/// spacing, corner radius, and shadow styling across all views and components.
public enum AppTheme {
    
    // MARK: - Spacing Tokens
    
    public enum Spacing {
        /// 4pt — Micro padding (inner badge offsets, indicator gaps)
        public static let xxSmall: CGFloat = 4
        /// 8pt — Small gap (tight label stacks, icon-to-text gaps)
        public static let small: CGFloat = 8
        /// 12pt — Medium-compact gap (tag grids, calendar cells)
        public static let medium: CGFloat = 12
        /// 16pt — Standard gap (standard card internal padding, item spacing)
        public static let large: CGFloat = 16
        /// 24pt — Extra-large gap (screen horizontal margins, section breaks)
        public static let extraLarge: CGFloat = 24
        /// 32pt — Double extra-large gap (major section separation)
        public static let xxLarge: CGFloat = 32
    }
    
    // MARK: - Corner Radii
    
    public enum CornerRadius {
        /// 8pt — Small elements (checkboxes, tags, sub-pills)
        public static let small: CGFloat = 8
        /// 14pt — Medium elements (inputs, inner metric blocks)
        public static let medium: CGFloat = 14
        /// 20pt — Standard cards & prominent buttons (as seen across DesignReferences)
        public static let card: CGFloat = 20
        /// 26pt — Large interactive elements (primary CTA 'Start' button, modals)
        public static let large: CGFloat = 26
        /// 999pt — Full pill / circular capsules
        public static let pill: CGFloat = 999
    }
    
    // MARK: - Shadows
    
    public enum Shadows {
        /// Subtle elevation for pastel cards and floating surfaces
        public static func softCard(colorScheme: ColorScheme) -> ShadowStyle {
            if colorScheme == .dark {
                return ShadowStyle(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
            } else {
                return ShadowStyle(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
            }
        }
        
        /// Elevated floating elements (such as bottom tab bar and floating action buttons)
        public static func elevated(colorScheme: ColorScheme) -> ShadowStyle {
            if colorScheme == .dark {
                return ShadowStyle(color: Color.black.opacity(0.50), radius: 14, x: 0, y: 6)
            } else {
                return ShadowStyle(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 6)
            }
        }
    }
    
    // MARK: - Typography
    
    public enum Typography {
        /// Large screen title (e.g. "Today", "Diet", "Cycle Tracker") — 30pt Bold Rounded
        public static let screenTitle: Font = .system(size: 30, weight: .bold, design: .rounded)
        
        /// Section heading (e.g. "Workout", "Log Today's Intake", "Symptoms") — 20pt Bold Rounded
        public static let sectionHeading: Font = .system(size: 20, weight: .bold, design: .rounded)
        
        /// Card title (e.g. "Morning Stretch", "Full Body Strength") — 17pt Semi-bold Rounded
        public static let cardTitle: Font = .system(size: 17, weight: .semibold, design: .rounded)
        
        /// Primary CTA and button labels (e.g. "START", "Add Selected Items") — 16pt Bold Rounded
        public static let buttonLabel: Font = .system(size: 16, weight: .bold, design: .rounded)
        
        /// Standard body text for description and entries — 15pt Regular
        public static let body: Font = .system(size: 15, weight: .regular, design: .default)
        
        /// Prominent metric values (e.g. "1,245", "Day 12") — 22pt Bold Rounded
        public static let metricValue: Font = .system(size: 22, weight: .bold, design: .rounded)
        
        /// Caption & secondary details (e.g. "15 mins • 80 kcal", "Friday, Oct 23") — 13pt Medium Rounded
        public static let caption: Font = .system(size: 13, weight: .medium, design: .rounded)
        
        /// Micro labels (e.g. "kcal left", tab bar labels, calendar week days) — 11pt Medium
        public static let micro: Font = .system(size: 11, weight: .medium, design: .default)
    }
}

// MARK: - Shadow Data Structure & View Modifier

public struct ShadowStyle: Equatable {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat
    
    public init(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}

public extension View {
    /// Applies a configured `ShadowStyle` to any SwiftUI view.
    func appShadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
    
    /// Convenience modifier to apply standard soft card styling using AppColors and AppTheme.
    func softCardStyle(
        backgroundColor: Color = AppColors.cardBackground,
        cornerRadius: CGFloat = AppTheme.CornerRadius.card,
        colorScheme: ColorScheme
    ) -> some View {
        self
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .appShadow(AppTheme.Shadows.softCard(colorScheme: colorScheme))
    }
}
