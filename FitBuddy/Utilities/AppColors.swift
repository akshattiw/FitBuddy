import SwiftUI

/// Centralized color palette for FitBuddy, faithfully matching the soft pastel aesthetic
/// in `DesignReferences/` with full adaptive support for both Light and Dark modes.
public enum AppColors {
    // MARK: - Pastel Accent Tones
    
    /// Soft, soothing mint green for primary actions (Start, Add, Selected highlights).
    public static let mint = Color(
        "Mint",
        light: Color(red: 0.36, green: 0.77, blue: 0.62), // #5CC49E
        dark: Color(red: 0.42, green: 0.83, blue: 0.68)
    )
    
    /// Calming sky blue for morning workout cards, water/hydration, and stats progress.
    public static let skyBlue = Color(
        "SkyBlue",
        light: Color(red: 0.82, green: 0.91, blue: 0.99), // #D1E8FD
        dark: Color(red: 0.22, green: 0.35, blue: 0.48)
    )
    
    /// Soft peach tone for strength workout cards, snacks, and vouchers.
    public static let peach = Color(
        "Peach",
        light: Color(red: 1.00, green: 0.90, blue: 0.83), // #FFE6D4
        dark: Color(red: 0.48, green: 0.34, blue: 0.27)
    )
    
    /// Pale lavender for yoga workouts, rest passes, and cycle notes.
    public static let lavender = Color(
        "Lavender",
        light: Color(red: 0.93, green: 0.89, blue: 0.98), // #EDE3FA
        dark: Color(red: 0.36, green: 0.30, blue: 0.48)
    )
    
    /// Soft pink for cycle tracking, cramps symptom, and active cycle tab pill.
    public static let softPink = Color(
        "SoftPink",
        light: Color(red: 1.00, green: 0.84, blue: 0.87), // #FFD6DE
        dark: Color(red: 0.48, green: 0.26, blue: 0.32)
    )
    
    /// Soft warm yellow for fertile window highlights and mood tracking.
    public static let softYellow = Color(
        "SoftYellow",
        light: Color(red: 1.00, green: 0.95, blue: 0.75), // #FFF2BF
        dark: Color(red: 0.45, green: 0.40, blue: 0.20)
    )

    // MARK: - Backgrounds & Surfaces
    
    /// Main app canvas background. Soft off-white in light mode; deep slate-charcoal in dark mode.
    public static let background = Color(
        "Background",
        light: Color(red: 0.98, green: 0.98, blue: 0.98),
        dark: Color(red: 0.08, green: 0.09, blue: 0.11)
    )
    
    /// Primary card/sheet background surface. Clean white in light mode; subtle elevated dark gray in dark mode.
    public static let cardBackground = Color(
        "CardBackground",
        light: Color.white,
        dark: Color(red: 0.14, green: 0.15, blue: 0.18)
    )
    
    /// Secondary card surface for nested tiles and sub-elements.
    public static let secondaryCardBackground = Color(
        "SecondaryCardBackground",
        light: Color(red: 0.95, green: 0.96, blue: 0.97),
        dark: Color(red: 0.19, green: 0.20, blue: 0.24)
    )

    // MARK: - Typography & Iconography
    
    /// Primary high-contrast text color for titles, headings, and high-emphasis numbers.
    public static let primaryText = Color(
        "PrimaryText",
        light: Color(red: 0.10, green: 0.11, blue: 0.13),
        dark: Color(red: 0.96, green: 0.96, blue: 0.97)
    )
    
    /// Secondary muted text color for subtitles, timestamps, and metric units.
    public static let secondaryText = Color(
        "SecondaryText",
        light: Color(red: 0.50, green: 0.53, blue: 0.58),
        dark: Color(red: 0.65, green: 0.68, blue: 0.73)
    )
    
    /// Subtle divider and border line color.
    public static let divider = Color(
        "Divider",
        light: Color(red: 0.90, green: 0.91, blue: 0.93),
        dark: Color(red: 0.22, green: 0.24, blue: 0.28)
    )

    // MARK: - Component-Specific Accents
    
    /// Darker interactive tint derived from sky blue (for circular pill buttons and glyphs).
    public static let skyBlueAccent = Color(
        "SkyBlueAccent",
        light: Color(red: 0.65, green: 0.80, blue: 0.95),
        dark: Color(red: 0.35, green: 0.55, blue: 0.75)
    )
    
    /// Darker interactive tint derived from peach (for pill buttons).
    public static let peachAccent = Color(
        "PeachAccent",
        light: Color(red: 0.98, green: 0.78, blue: 0.68),
        dark: Color(red: 0.68, green: 0.48, blue: 0.38)
    )
    
    /// Darker interactive tint derived from lavender (for pill buttons).
    public static let lavenderAccent = Color(
        "LavenderAccent",
        light: Color(red: 0.85, green: 0.77, blue: 0.95),
        dark: Color(red: 0.55, green: 0.45, blue: 0.68)
    )
}

// MARK: - Adaptive Color Helper

private extension Color {
    init(_ name: String, light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        self.init(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        }))
        #endif
    }
}
