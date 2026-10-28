import SwiftUI

/// Reusable artwork rendering component for pet companions.
/// Seamlessly handles animated GIF assets and native system symbol illustrations.
public struct PetArtworkView: View {
    public let artwork: PetArtwork
    public let isLocked: Bool
    public let isDeceased: Bool
    public let size: CGFloat
    
    public init(
        artwork: PetArtwork,
        isLocked: Bool = false,
        isDeceased: Bool = false,
        size: CGFloat = 56
    ) {
        self.artwork = artwork
        self.isLocked = isLocked
        self.isDeceased = isDeceased
        self.size = size
    }
    
    private var symbolTint: Color {
        if let hex = artwork.symbolTintHex {
            return Color(hex: hex)
        }
        return AppColors.mint
    }
    
    public var body: some View {
        ZStack {
            switch artwork.kind {
            case .gif:
                AnimatedGIFView(name: artwork.identifier)
                    .frame(width: size * 0.85, height: size * 0.95)
                    .opacity(isLocked ? 0.35 : (isDeceased ? 0.45 : 1.0))
                    .grayscale(isLocked ? 0.8 : (isDeceased ? 1.0 : 0.0))
                
            case .systemSymbol:
                Image(systemName: artwork.identifier)
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundColor(isLocked ? AppColors.secondaryText.opacity(0.4) : (isDeceased ? AppColors.secondaryText.opacity(0.5) : symbolTint))
                    .frame(width: size, height: size)
                    .grayscale(isDeceased ? 1.0 : 0.0)
            }
            
            if isLocked {
                Circle()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: size * 0.4, height: size * 0.4)
                    .overlay(
                        Image(systemName: "lock.fill")
                            .font(.system(size: size * 0.22, weight: .bold))
                            .foregroundColor(.white)
                    )
            } else if isDeceased {
                Circle()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: size * 0.42, height: size * 0.42)
                    .overlay(
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: size * 0.22, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Color Hex Initializer Helper

private extension Color {
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch cleanHex.count {
        case 6: // RGB (24-bit)
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // ARGB (32-bit)
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, int >> 24)
        default:
            (r, g, b, a) = (128, 128, 128, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
