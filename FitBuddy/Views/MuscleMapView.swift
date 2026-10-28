import SwiftUI

/// High-fidelity anatomical human body vector models (Front & Back) with individual muscle highlights.
/// Faithfully reproduces the aesthetic seen in `DesignReferences/stats-screen.jpeg` (Image 2) and GainFrame (Image 3).
public struct MuscleMapView: View {
    public let engagement: [MuscleGroup: Double]
    public let engagementService: MuscleEngagementService
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(
        engagement: [MuscleGroup: Double],
        engagementService: MuscleEngagementService = MuscleEngagementService()
    ) {
        self.engagement = engagement
        self.engagementService = engagementService
    }
    
    public var body: some View {
        HStack(spacing: AppTheme.Spacing.large) {
            // MARK: - Front Silhouette Card
            VStack(spacing: AppTheme.Spacing.small) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                        .fill(AppColors.secondaryCardBackground.opacity(0.8))
                    
                    FrontBodyAnatomicalView(
                        engagement: engagement,
                        engagementService: engagementService
                    )
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                }
                .frame(height: 220)
                
                Text("Front")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            
            // MARK: - Back Silhouette Card
            VStack(spacing: AppTheme.Spacing.small) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                        .fill(AppColors.secondaryCardBackground.opacity(0.8))
                    
                    BackBodyAnatomicalView(
                        engagement: engagement,
                        engagementService: engagementService
                    )
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                }
                .frame(height: 220)
                
                Text("Back")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.secondaryText)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Front Anatomical Human Body View
public struct FrontBodyAnatomicalView: View {
    public let engagement: [MuscleGroup: Double]
    public let engagementService: MuscleEngagementService
    
    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // 1. Base Wireframe Body Outline
                FrontBodySilhouetteShape()
                    .stroke(
                        AppColors.divider.opacity(0.85),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
                    )
                
                // Subtle anatomical guide lines (sternum, clavicle, knees)
                FrontAnatomicalGuideLines()
                    .stroke(
                        AppColors.divider.opacity(0.45),
                        style: StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round)
                    )
                
                // 2. Active Muscle Highlight Layers
                // Chest / Pectorals
                let chestScore = engagement[.chest] ?? 0.0
                FrontChestShape()
                    .fill(muscleColor(for: chestScore, baseTone: AppColors.peachAccent))
                    .overlay(
                        FrontChestShape()
                            .stroke(muscleStroke(for: chestScore, baseTone: AppColors.peachAccent), lineWidth: 0.75)
                    )
                
                // Shoulders / Deltoids
                let shoulderScore = engagement[.shoulders] ?? 0.0
                FrontShouldersShape()
                    .fill(muscleColor(for: shoulderScore, baseTone: AppColors.peachAccent))
                    .overlay(
                        FrontShouldersShape()
                            .stroke(muscleStroke(for: shoulderScore, baseTone: AppColors.peachAccent), lineWidth: 0.75)
                    )
                
                // Biceps
                let bicepScore = engagement[.biceps] ?? 0.0
                FrontBicepsShape()
                    .fill(muscleColor(for: bicepScore, baseTone: AppColors.peachAccent))
                    .overlay(
                        FrontBicepsShape()
                            .stroke(muscleStroke(for: bicepScore, baseTone: AppColors.peachAccent), lineWidth: 0.75)
                    )
                
                // Core / Abdominals & Obliques
                let coreScore = engagement[.core] ?? 0.0
                FrontCoreShape()
                    .fill(muscleColor(for: coreScore, baseTone: AppColors.mint))
                    .overlay(
                        FrontCoreShape()
                            .stroke(muscleStroke(for: coreScore, baseTone: AppColors.mint), lineWidth: 0.75)
                    )
                
                // Quads / Quadriceps
                let quadsScore = engagement[.quads] ?? 0.0
                FrontQuadsShape()
                    .fill(muscleColor(for: quadsScore, baseTone: AppColors.peachAccent))
                    .overlay(
                        FrontQuadsShape()
                            .stroke(muscleStroke(for: quadsScore, baseTone: AppColors.peachAccent), lineWidth: 0.75)
                    )
                
                // Calves / Lower leg front
                let calvesScore = engagement[.calves] ?? 0.0
                FrontCalvesShape()
                    .fill(muscleColor(for: calvesScore, baseTone: AppColors.skyBlueAccent))
                    .overlay(
                        FrontCalvesShape()
                            .stroke(muscleStroke(for: calvesScore, baseTone: AppColors.skyBlueAccent), lineWidth: 0.75)
                    )
            }
            .frame(width: w, height: h)
        }
    }
    
    private func muscleColor(for score: Double, baseTone: Color) -> Color {
        let intensity = engagementService.intensity(for: score)
        switch intensity {
        case .high:
            return baseTone.opacity(0.85)
        case .moderate:
            return baseTone.opacity(0.55)
        case .light:
            return baseTone.opacity(0.28)
        case .none:
            return Color.clear
        }
    }
    
    private func muscleStroke(for score: Double, baseTone: Color) -> Color {
        let intensity = engagementService.intensity(for: score)
        switch intensity {
        case .high:
            return baseTone
        case .moderate:
            return baseTone.opacity(0.8)
        case .light:
            return baseTone.opacity(0.4)
        case .none:
            return Color.clear
        }
    }
}

// MARK: - Back Anatomical Human Body View
public struct BackBodyAnatomicalView: View {
    public let engagement: [MuscleGroup: Double]
    public let engagementService: MuscleEngagementService
    
    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // 1. Base Wireframe Body Outline
                BackBodySilhouetteShape()
                    .stroke(
                        AppColors.divider.opacity(0.85),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
                    )
                
                // Subtle anatomical spine & shoulder blade guide lines
                BackAnatomicalGuideLines()
                    .stroke(
                        AppColors.divider.opacity(0.45),
                        style: StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round)
                    )
                
                // 2. Active Muscle Highlight Layers
                // Trapezius & Upper Back
                let backScore = engagement[.back] ?? 0.0
                BackTrapsShape()
                    .fill(muscleColor(for: backScore, baseTone: AppColors.peachAccent))
                    .overlay(
                        BackTrapsShape()
                            .stroke(muscleStroke(for: backScore, baseTone: AppColors.peachAccent), lineWidth: 0.75)
                    )
                
                // Lats (Latissimus Dorsi)
                BackLatsShape()
                    .fill(muscleColor(for: backScore, baseTone: AppColors.mint))
                    .overlay(
                        BackLatsShape()
                            .stroke(muscleStroke(for: backScore, baseTone: AppColors.mint), lineWidth: 0.75)
                    )
                
                // Posterior Deltoids
                let shoulderScore = engagement[.shoulders] ?? 0.0
                BackRearDeltsShape()
                    .fill(muscleColor(for: shoulderScore, baseTone: AppColors.peachAccent))
                    .overlay(
                        BackRearDeltsShape()
                            .stroke(muscleStroke(for: shoulderScore, baseTone: AppColors.peachAccent), lineWidth: 0.75)
                    )
                
                // Triceps
                let tricepScore = engagement[.triceps] ?? 0.0
                BackTricepsShape()
                    .fill(muscleColor(for: tricepScore, baseTone: AppColors.peachAccent))
                    .overlay(
                        BackTricepsShape()
                            .stroke(muscleStroke(for: tricepScore, baseTone: AppColors.peachAccent), lineWidth: 0.75)
                    )
                
                // Glutes
                let glutesScore = engagement[.glutes] ?? 0.0
                BackGlutesShape()
                    .fill(muscleColor(for: glutesScore, baseTone: AppColors.lavenderAccent))
                    .overlay(
                        BackGlutesShape()
                            .stroke(muscleStroke(for: glutesScore, baseTone: AppColors.lavenderAccent), lineWidth: 0.75)
                    )
                
                // Hamstrings
                let hamstringsScore = engagement[.hamstrings] ?? 0.0
                BackHamstringsShape()
                    .fill(muscleColor(for: hamstringsScore, baseTone: AppColors.peachAccent))
                    .overlay(
                        BackHamstringsShape()
                            .stroke(muscleStroke(for: hamstringsScore, baseTone: AppColors.peachAccent), lineWidth: 0.75)
                    )
                
                // Calves (Gastrocnemius & Soleus)
                let calvesScore = engagement[.calves] ?? 0.0
                BackCalvesShape()
                    .fill(muscleColor(for: calvesScore, baseTone: AppColors.skyBlueAccent))
                    .overlay(
                        BackCalvesShape()
                            .stroke(muscleStroke(for: calvesScore, baseTone: AppColors.skyBlueAccent), lineWidth: 0.75)
                    )
            }
            .frame(width: w, height: h)
        }
    }
    
    private func muscleColor(for score: Double, baseTone: Color) -> Color {
        let intensity = engagementService.intensity(for: score)
        switch intensity {
        case .high:
            return baseTone.opacity(0.85)
        case .moderate:
            return baseTone.opacity(0.55)
        case .light:
            return baseTone.opacity(0.28)
        case .none:
            return Color.clear
        }
    }
    
    private func muscleStroke(for score: Double, baseTone: Color) -> Color {
        let intensity = engagementService.intensity(for: score)
        switch intensity {
        case .high:
            return baseTone
        case .moderate:
            return baseTone.opacity(0.8)
        case .light:
            return baseTone.opacity(0.4)
        case .none:
            return Color.clear
        }
    }
}

// MARK: - Anatomical Wireframe Outlines & Guides

public struct FrontBodySilhouetteShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Head
        let headRect = CGRect(x: w * 0.44, y: h * 0.02, width: w * 0.12, height: h * 0.10)
        path.addEllipse(in: headRect)
        
        // Body outline (Right side from neck down, then Left side back up)
        path.move(to: CGPoint(x: w * 0.46, y: h * 0.12)) // Neck left
        path.addLine(to: CGPoint(x: w * 0.46, y: h * 0.14))
        path.addQuadCurve(to: CGPoint(x: w * 0.32, y: h * 0.17), control: CGPoint(x: w * 0.38, y: h * 0.15)) // Left trap/shoulder
        path.addQuadCurve(to: CGPoint(x: w * 0.28, y: h * 0.25), control: CGPoint(x: w * 0.27, y: h * 0.20)) // Left delt
        path.addQuadCurve(to: CGPoint(x: w * 0.24, y: h * 0.38), control: CGPoint(x: w * 0.25, y: h * 0.31)) // Left upper arm / bicep
        path.addQuadCurve(to: CGPoint(x: w * 0.20, y: h * 0.48), control: CGPoint(x: w * 0.22, y: h * 0.43)) // Left forearm
        path.addQuadCurve(to: CGPoint(x: w * 0.18, y: h * 0.54), control: CGPoint(x: w * 0.18, y: h * 0.51)) // Left hand
        path.addQuadCurve(to: CGPoint(x: w * 0.23, y: h * 0.48), control: CGPoint(x: w * 0.21, y: h * 0.52)) // Inner left wrist
        path.addQuadCurve(to: CGPoint(x: w * 0.28, y: h * 0.36), control: CGPoint(x: w * 0.26, y: h * 0.42)) // Inner forearm
        path.addQuadCurve(to: CGPoint(x: w * 0.34, y: h * 0.28), control: CGPoint(x: w * 0.32, y: h * 0.32)) // Armpit left
        path.addQuadCurve(to: CGPoint(x: w * 0.36, y: h * 0.42), control: CGPoint(x: w * 0.34, y: h * 0.35)) // Waist left
        path.addQuadCurve(to: CGPoint(x: w * 0.34, y: h * 0.52), control: CGPoint(x: w * 0.33, y: h * 0.47)) // Hip left
        
        // Left Leg
        path.addQuadCurve(to: CGPoint(x: w * 0.35, y: h * 0.70), control: CGPoint(x: w * 0.33, y: h * 0.61)) // Outer thigh
        path.addQuadCurve(to: CGPoint(x: w * 0.36, y: h * 0.75), control: CGPoint(x: w * 0.35, y: h * 0.72)) // Knee outer
        path.addQuadCurve(to: CGPoint(x: w * 0.38, y: h * 0.92), control: CGPoint(x: w * 0.34, y: h * 0.83)) // Outer calf
        path.addQuadCurve(to: CGPoint(x: w * 0.39, y: h * 0.98), control: CGPoint(x: w * 0.37, y: h * 0.96)) // Left foot
        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.98))
        path.addQuadCurve(to: CGPoint(x: w * 0.44, y: h * 0.91), control: CGPoint(x: w * 0.45, y: h * 0.95)) // Inner ankle
        path.addQuadCurve(to: CGPoint(x: w * 0.43, y: h * 0.75), control: CGPoint(x: w * 0.46, y: h * 0.83)) // Inner calf / knee
        path.addQuadCurve(to: CGPoint(x: w * 0.48, y: h * 0.55), control: CGPoint(x: w * 0.45, y: h * 0.65)) // Inner thigh to crotch
        
        // Right Leg
        path.addQuadCurve(to: CGPoint(x: w * 0.57, y: h * 0.75), control: CGPoint(x: w * 0.55, y: h * 0.65)) // Crotch to inner knee
        path.addQuadCurve(to: CGPoint(x: w * 0.56, y: h * 0.91), control: CGPoint(x: w * 0.54, y: h * 0.83)) // Inner right calf
        path.addQuadCurve(to: CGPoint(x: w * 0.56, y: h * 0.98), control: CGPoint(x: w * 0.55, y: h * 0.95))
        path.addLine(to: CGPoint(x: w * 0.61, y: h * 0.98)) // Right foot
        path.addQuadCurve(to: CGPoint(x: w * 0.62, y: h * 0.92), control: CGPoint(x: w * 0.63, y: h * 0.96))
        path.addQuadCurve(to: CGPoint(x: w * 0.64, y: h * 0.75), control: CGPoint(x: w * 0.66, y: h * 0.83)) // Outer right calf
        path.addQuadCurve(to: CGPoint(x: w * 0.65, y: h * 0.70), control: CGPoint(x: w * 0.65, y: h * 0.72)) // Right knee outer
        path.addQuadCurve(to: CGPoint(x: w * 0.66, y: h * 0.52), control: CGPoint(x: w * 0.67, y: h * 0.61)) // Right outer thigh
        path.addQuadCurve(to: CGPoint(x: w * 0.64, y: h * 0.42), control: CGPoint(x: w * 0.67, y: h * 0.47)) // Right hip
        path.addQuadCurve(to: CGPoint(x: w * 0.66, y: h * 0.28), control: CGPoint(x: w * 0.66, y: h * 0.35)) // Right waist to armpit
        
        // Right Arm
        path.addQuadCurve(to: CGPoint(x: w * 0.72, y: h * 0.36), control: CGPoint(x: w * 0.68, y: h * 0.32)) // Inner right bicep
        path.addQuadCurve(to: CGPoint(x: w * 0.77, y: h * 0.48), control: CGPoint(x: w * 0.74, y: h * 0.42)) // Inner forearm
        path.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.54), control: CGPoint(x: w * 0.79, y: h * 0.52)) // Right hand
        path.addQuadCurve(to: CGPoint(x: w * 0.80, y: h * 0.48), control: CGPoint(x: w * 0.82, y: h * 0.51))
        path.addQuadCurve(to: CGPoint(x: w * 0.76, y: h * 0.38), control: CGPoint(x: w * 0.78, y: h * 0.43))
        path.addQuadCurve(to: CGPoint(x: w * 0.72, y: h * 0.25), control: CGPoint(x: w * 0.75, y: h * 0.31)) // Right outer arm
        path.addQuadCurve(to: CGPoint(x: w * 0.68, y: h * 0.17), control: CGPoint(x: w * 0.73, y: h * 0.20)) // Right delt
        path.addQuadCurve(to: CGPoint(x: w * 0.54, y: h * 0.14), control: CGPoint(x: w * 0.62, y: h * 0.15)) // Right trap
        path.addLine(to: CGPoint(x: w * 0.54, y: h * 0.12)) // Right neck
        
        return path
    }
}

public struct FrontAnatomicalGuideLines: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Clavicle lines
        path.move(to: CGPoint(x: w * 0.46, y: h * 0.16))
        path.addQuadCurve(to: CGPoint(x: w * 0.34, y: h * 0.17), control: CGPoint(x: w * 0.40, y: h * 0.165))
        path.move(to: CGPoint(x: w * 0.54, y: h * 0.16))
        path.addQuadCurve(to: CGPoint(x: w * 0.66, y: h * 0.17), control: CGPoint(x: w * 0.60, y: h * 0.165))
        
        // Sternum / Center Line
        path.move(to: CGPoint(x: w * 0.50, y: h * 0.17))
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.38))
        
        // Knee caps
        path.addEllipse(in: CGRect(x: w * 0.38, y: h * 0.73, width: w * 0.05, height: h * 0.03))
        path.addEllipse(in: CGRect(x: w * 0.57, y: h * 0.73, width: w * 0.05, height: h * 0.03))
        
        return path
    }
}

// MARK: - Front Muscle Group Shapes

/// Chest / Pectorals (Left & Right)
public struct FrontChestShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Left Pec
        path.move(to: CGPoint(x: w * 0.49, y: h * 0.19))
        path.addLine(to: CGPoint(x: w * 0.36, y: h * 0.19))
        path.addQuadCurve(to: CGPoint(x: w * 0.36, y: h * 0.27), control: CGPoint(x: w * 0.34, y: h * 0.23))
        path.addQuadCurve(to: CGPoint(x: w * 0.49, y: h * 0.28), control: CGPoint(x: w * 0.43, y: h * 0.29))
        path.closeSubpath()
        
        // Right Pec
        path.move(to: CGPoint(x: w * 0.51, y: h * 0.19))
        path.addLine(to: CGPoint(x: w * 0.64, y: h * 0.19))
        path.addQuadCurve(to: CGPoint(x: w * 0.64, y: h * 0.27), control: CGPoint(x: w * 0.66, y: h * 0.23))
        path.addQuadCurve(to: CGPoint(x: w * 0.51, y: h * 0.28), control: CGPoint(x: w * 0.57, y: h * 0.29))
        path.closeSubpath()
        
        return path
    }
}

/// Shoulders / Anterior Deltoids (Left & Right)
public struct FrontShouldersShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Left Shoulder
        path.move(to: CGPoint(x: w * 0.35, y: h * 0.17))
        path.addQuadCurve(to: CGPoint(x: w * 0.27, y: h * 0.24), control: CGPoint(x: w * 0.29, y: h * 0.19))
        path.addQuadCurve(to: CGPoint(x: w * 0.34, y: h * 0.25), control: CGPoint(x: w * 0.30, y: h * 0.26))
        path.closeSubpath()
        
        // Right Shoulder
        path.move(to: CGPoint(x: w * 0.65, y: h * 0.17))
        path.addQuadCurve(to: CGPoint(x: w * 0.73, y: h * 0.24), control: CGPoint(x: w * 0.71, y: h * 0.19))
        path.addQuadCurve(to: CGPoint(x: w * 0.66, y: h * 0.25), control: CGPoint(x: w * 0.70, y: h * 0.26))
        path.closeSubpath()
        
        return path
    }
}

/// Biceps (Left & Right)
public struct FrontBicepsShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Left Bicep
        path.move(to: CGPoint(x: w * 0.27, y: h * 0.26))
        path.addQuadCurve(to: CGPoint(x: w * 0.24, y: h * 0.35), control: CGPoint(x: w * 0.23, y: h * 0.30))
        path.addQuadCurve(to: CGPoint(x: w * 0.30, y: h * 0.34), control: CGPoint(x: w * 0.27, y: h * 0.36))
        path.closeSubpath()
        
        // Right Bicep
        path.move(to: CGPoint(x: w * 0.73, y: h * 0.26))
        path.addQuadCurve(to: CGPoint(x: w * 0.76, y: h * 0.35), control: CGPoint(x: w * 0.77, y: h * 0.30))
        path.addQuadCurve(to: CGPoint(x: w * 0.70, y: h * 0.34), control: CGPoint(x: w * 0.73, y: h * 0.36))
        path.closeSubpath()
        
        return path
    }
}

/// Core / Abdominals & Obliques
public struct FrontCoreShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Left & Right Upper Abs
        path.addRoundedRect(in: CGRect(x: w * 0.43, y: h * 0.30, width: w * 0.06, height: h * 0.035), cornerSize: CGSize(width: 2, height: 2))
        path.addRoundedRect(in: CGRect(x: w * 0.51, y: h * 0.30, width: w * 0.06, height: h * 0.035), cornerSize: CGSize(width: 2, height: 2))
        
        // Mid Abs
        path.addRoundedRect(in: CGRect(x: w * 0.43, y: h * 0.345, width: w * 0.06, height: h * 0.035), cornerSize: CGSize(width: 2, height: 2))
        path.addRoundedRect(in: CGRect(x: w * 0.51, y: h * 0.345, width: w * 0.06, height: h * 0.035), cornerSize: CGSize(width: 2, height: 2))
        
        // Lower Abs
        path.addRoundedRect(in: CGRect(x: w * 0.44, y: h * 0.39, width: w * 0.055, height: h * 0.035), cornerSize: CGSize(width: 2, height: 2))
        path.addRoundedRect(in: CGRect(x: w * 0.505, y: h * 0.39, width: w * 0.055, height: h * 0.035), cornerSize: CGSize(width: 2, height: 2))
        
        // Left Oblique Flank
        path.move(to: CGPoint(x: w * 0.39, y: h * 0.31))
        path.addQuadCurve(to: CGPoint(x: w * 0.41, y: h * 0.43), control: CGPoint(x: w * 0.38, y: h * 0.37))
        path.addLine(to: CGPoint(x: w * 0.425, y: h * 0.43))
        path.addLine(to: CGPoint(x: w * 0.41, y: h * 0.31))
        path.closeSubpath()
        
        // Right Oblique Flank
        path.move(to: CGPoint(x: w * 0.61, y: h * 0.31))
        path.addQuadCurve(to: CGPoint(x: w * 0.59, y: h * 0.43), control: CGPoint(x: w * 0.62, y: h * 0.37))
        path.addLine(to: CGPoint(x: w * 0.575, y: h * 0.43))
        path.addLine(to: CGPoint(x: w * 0.59, y: h * 0.31))
        path.closeSubpath()
        
        return path
    }
}

/// Quads / Quadriceps
public struct FrontQuadsShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Left Quad
        path.move(to: CGPoint(x: w * 0.37, y: h * 0.53))
        path.addQuadCurve(to: CGPoint(x: w * 0.37, y: h * 0.71), control: CGPoint(x: w * 0.34, y: h * 0.62)) // Outer curve
        path.addLine(to: CGPoint(x: w * 0.43, y: h * 0.71))
        path.addQuadCurve(to: CGPoint(x: w * 0.46, y: h * 0.55), control: CGPoint(x: w * 0.44, y: h * 0.63)) // Inner curve
        path.closeSubpath()
        
        // Right Quad
        path.move(to: CGPoint(x: w * 0.63, y: h * 0.53))
        path.addQuadCurve(to: CGPoint(x: w * 0.63, y: h * 0.71), control: CGPoint(x: w * 0.66, y: h * 0.62)) // Outer curve
        path.addLine(to: CGPoint(x: w * 0.57, y: h * 0.71))
        path.addQuadCurve(to: CGPoint(x: w * 0.54, y: h * 0.55), control: CGPoint(x: w * 0.56, y: h * 0.63)) // Inner curve
        path.closeSubpath()
        
        return path
    }
}

/// Calves (Front Shin / Calves)
public struct FrontCalvesShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Left Calf / Shin
        path.move(to: CGPoint(x: w * 0.38, y: h * 0.77))
        path.addQuadCurve(to: CGPoint(x: w * 0.40, y: h * 0.92), control: CGPoint(x: w * 0.36, y: h * 0.84))
        path.addLine(to: CGPoint(x: w * 0.43, y: h * 0.92))
        path.addQuadCurve(to: CGPoint(x: w * 0.43, y: h * 0.77), control: CGPoint(x: w * 0.45, y: h * 0.84))
        path.closeSubpath()
        
        // Right Calf / Shin
        path.move(to: CGPoint(x: w * 0.62, y: h * 0.77))
        path.addQuadCurve(to: CGPoint(x: w * 0.60, y: h * 0.92), control: CGPoint(x: w * 0.64, y: h * 0.84))
        path.addLine(to: CGPoint(x: w * 0.57, y: h * 0.92))
        path.addQuadCurve(to: CGPoint(x: w * 0.57, y: h * 0.77), control: CGPoint(x: w * 0.55, y: h * 0.84))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Back Anatomical Shapes

public struct BackBodySilhouetteShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Head
        let headRect = CGRect(x: w * 0.44, y: h * 0.02, width: w * 0.12, height: h * 0.10)
        path.addEllipse(in: headRect)
        
        // Body outline from neck down left side, then right side
        path.move(to: CGPoint(x: w * 0.46, y: h * 0.12))
        path.addLine(to: CGPoint(x: w * 0.46, y: h * 0.14))
        path.addQuadCurve(to: CGPoint(x: w * 0.32, y: h * 0.17), control: CGPoint(x: w * 0.38, y: h * 0.15))
        path.addQuadCurve(to: CGPoint(x: w * 0.28, y: h * 0.25), control: CGPoint(x: w * 0.27, y: h * 0.20))
        path.addQuadCurve(to: CGPoint(x: w * 0.24, y: h * 0.38), control: CGPoint(x: w * 0.25, y: h * 0.31))
        path.addQuadCurve(to: CGPoint(x: w * 0.20, y: h * 0.48), control: CGPoint(x: w * 0.22, y: h * 0.43))
        path.addQuadCurve(to: CGPoint(x: w * 0.18, y: h * 0.54), control: CGPoint(x: w * 0.18, y: h * 0.51))
        path.addQuadCurve(to: CGPoint(x: w * 0.23, y: h * 0.48), control: CGPoint(x: w * 0.21, y: h * 0.52))
        path.addQuadCurve(to: CGPoint(x: w * 0.28, y: h * 0.36), control: CGPoint(x: w * 0.26, y: h * 0.42))
        path.addQuadCurve(to: CGPoint(x: w * 0.34, y: h * 0.28), control: CGPoint(x: w * 0.32, y: h * 0.32))
        path.addQuadCurve(to: CGPoint(x: w * 0.36, y: h * 0.42), control: CGPoint(x: w * 0.34, y: h * 0.35))
        path.addQuadCurve(to: CGPoint(x: w * 0.34, y: h * 0.52), control: CGPoint(x: w * 0.33, y: h * 0.47))
        
        // Left Leg
        path.addQuadCurve(to: CGPoint(x: w * 0.35, y: h * 0.70), control: CGPoint(x: w * 0.33, y: h * 0.61))
        path.addQuadCurve(to: CGPoint(x: w * 0.36, y: h * 0.75), control: CGPoint(x: w * 0.35, y: h * 0.72))
        path.addQuadCurve(to: CGPoint(x: w * 0.38, y: h * 0.92), control: CGPoint(x: w * 0.34, y: h * 0.83))
        path.addQuadCurve(to: CGPoint(x: w * 0.39, y: h * 0.98), control: CGPoint(x: w * 0.37, y: h * 0.96))
        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.98))
        path.addQuadCurve(to: CGPoint(x: w * 0.44, y: h * 0.91), control: CGPoint(x: w * 0.45, y: h * 0.95))
        path.addQuadCurve(to: CGPoint(x: w * 0.43, y: h * 0.75), control: CGPoint(x: w * 0.46, y: h * 0.83))
        path.addQuadCurve(to: CGPoint(x: w * 0.48, y: h * 0.55), control: CGPoint(x: w * 0.45, y: h * 0.65))
        
        // Right Leg
        path.addQuadCurve(to: CGPoint(x: w * 0.57, y: h * 0.75), control: CGPoint(x: w * 0.55, y: h * 0.65))
        path.addQuadCurve(to: CGPoint(x: w * 0.56, y: h * 0.91), control: CGPoint(x: w * 0.54, y: h * 0.83))
        path.addQuadCurve(to: CGPoint(x: w * 0.56, y: h * 0.98), control: CGPoint(x: w * 0.55, y: h * 0.95))
        path.addLine(to: CGPoint(x: w * 0.61, y: h * 0.98))
        path.addQuadCurve(to: CGPoint(x: w * 0.62, y: h * 0.92), control: CGPoint(x: w * 0.63, y: h * 0.96))
        path.addQuadCurve(to: CGPoint(x: w * 0.64, y: h * 0.75), control: CGPoint(x: w * 0.66, y: h * 0.83))
        path.addQuadCurve(to: CGPoint(x: w * 0.65, y: h * 0.70), control: CGPoint(x: w * 0.65, y: h * 0.72))
        path.addQuadCurve(to: CGPoint(x: w * 0.66, y: h * 0.52), control: CGPoint(x: w * 0.67, y: h * 0.61))
        path.addQuadCurve(to: CGPoint(x: w * 0.64, y: h * 0.42), control: CGPoint(x: w * 0.67, y: h * 0.47))
        path.addQuadCurve(to: CGPoint(x: w * 0.66, y: h * 0.28), control: CGPoint(x: w * 0.66, y: h * 0.35))
        
        // Right Arm
        path.addQuadCurve(to: CGPoint(x: w * 0.72, y: h * 0.36), control: CGPoint(x: w * 0.68, y: h * 0.32))
        path.addQuadCurve(to: CGPoint(x: w * 0.77, y: h * 0.48), control: CGPoint(x: w * 0.74, y: h * 0.42))
        path.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.54), control: CGPoint(x: w * 0.79, y: h * 0.52))
        path.addQuadCurve(to: CGPoint(x: w * 0.80, y: h * 0.48), control: CGPoint(x: w * 0.82, y: h * 0.51))
        path.addQuadCurve(to: CGPoint(x: w * 0.76, y: h * 0.38), control: CGPoint(x: w * 0.78, y: h * 0.43))
        path.addQuadCurve(to: CGPoint(x: w * 0.72, y: h * 0.25), control: CGPoint(x: w * 0.75, y: h * 0.31))
        path.addQuadCurve(to: CGPoint(x: w * 0.68, y: h * 0.17), control: CGPoint(x: w * 0.73, y: h * 0.20))
        path.addQuadCurve(to: CGPoint(x: w * 0.54, y: h * 0.14), control: CGPoint(x: w * 0.62, y: h * 0.15))
        path.addLine(to: CGPoint(x: w * 0.54, y: h * 0.12))
        
        return path
    }
}

public struct BackAnatomicalGuideLines: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Spine Line
        path.move(to: CGPoint(x: w * 0.50, y: h * 0.14))
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.50))
        
        // Scapula / Shoulder blade outlines
        path.move(to: CGPoint(x: w * 0.41, y: h * 0.20))
        path.addLine(to: CGPoint(x: w * 0.37, y: h * 0.26))
        path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.28))
        
        path.move(to: CGPoint(x: w * 0.59, y: h * 0.20))
        path.addLine(to: CGPoint(x: w * 0.63, y: h * 0.26))
        path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.28))
        
        return path
    }
}

/// Trapezius Kite & Upper Back
public struct BackTrapsShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Trapezius Kite shape
        path.move(to: CGPoint(x: w * 0.50, y: h * 0.13)) // Top base of skull
        path.addLine(to: CGPoint(x: w * 0.37, y: h * 0.18)) // Left shoulder tip
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.27)) // Mid spine T12
        path.addLine(to: CGPoint(x: w * 0.63, y: h * 0.18)) // Right shoulder tip
        path.closeSubpath()
        
        return path
    }
}

/// Lats (Latissimus Dorsi) Wings
public struct BackLatsShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Left Lat
        path.move(to: CGPoint(x: w * 0.48, y: h * 0.27))
        path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.23))
        path.addQuadCurve(to: CGPoint(x: w * 0.38, y: h * 0.38), control: CGPoint(x: w * 0.34, y: h * 0.32))
        path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.39))
        path.closeSubpath()
        
        // Right Lat
        path.move(to: CGPoint(x: w * 0.52, y: h * 0.27))
        path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.23))
        path.addQuadCurve(to: CGPoint(x: w * 0.62, y: h * 0.38), control: CGPoint(x: w * 0.66, y: h * 0.32))
        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.39))
        path.closeSubpath()
        
        return path
    }
}

/// Posterior Deltoids
public struct BackRearDeltsShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Left Rear Delt
        path.move(to: CGPoint(x: w * 0.34, y: h * 0.18))
        path.addQuadCurve(to: CGPoint(x: w * 0.27, y: h * 0.24), control: CGPoint(x: w * 0.29, y: h * 0.20))
        path.addQuadCurve(to: CGPoint(x: w * 0.33, y: h * 0.24), control: CGPoint(x: w * 0.30, y: h * 0.25))
        path.closeSubpath()
        
        // Right Rear Delt
        path.move(to: CGPoint(x: w * 0.66, y: h * 0.18))
        path.addQuadCurve(to: CGPoint(x: w * 0.73, y: h * 0.24), control: CGPoint(x: w * 0.71, y: h * 0.20))
        path.addQuadCurve(to: CGPoint(x: w * 0.67, y: h * 0.24), control: CGPoint(x: w * 0.70, y: h * 0.25))
        path.closeSubpath()
        
        return path
    }
}

/// Triceps (Back upper arm)
public struct BackTricepsShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Left Tricep
        path.move(to: CGPoint(x: w * 0.28, y: h * 0.25))
        path.addQuadCurve(to: CGPoint(x: w * 0.24, y: h * 0.35), control: CGPoint(x: w * 0.24, y: h * 0.30))
        path.addQuadCurve(to: CGPoint(x: w * 0.30, y: h * 0.35), control: CGPoint(x: w * 0.28, y: h * 0.36))
        path.closeSubpath()
        
        // Right Tricep
        path.move(to: CGPoint(x: w * 0.72, y: h * 0.25))
        path.addQuadCurve(to: CGPoint(x: w * 0.76, y: h * 0.35), control: CGPoint(x: w * 0.76, y: h * 0.30))
        path.addQuadCurve(to: CGPoint(x: w * 0.70, y: h * 0.35), control: CGPoint(x: w * 0.72, y: h * 0.36))
        path.closeSubpath()
        
        return path
    }
}

/// Glutes (Gluteus Maximus Left & Right)
public struct BackGlutesShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Left Glute
        path.move(to: CGPoint(x: w * 0.49, y: h * 0.44))
        path.addLine(to: CGPoint(x: w * 0.37, y: h * 0.44))
        path.addQuadCurve(to: CGPoint(x: w * 0.38, y: h * 0.55), control: CGPoint(x: w * 0.35, y: h * 0.50))
        path.addQuadCurve(to: CGPoint(x: w * 0.49, y: h * 0.54), control: CGPoint(x: w * 0.44, y: h * 0.56))
        path.closeSubpath()
        
        // Right Glute
        path.move(to: CGPoint(x: w * 0.51, y: h * 0.44))
        path.addLine(to: CGPoint(x: w * 0.63, y: h * 0.44))
        path.addQuadCurve(to: CGPoint(x: w * 0.62, y: h * 0.55), control: CGPoint(x: w * 0.65, y: h * 0.50))
        path.addQuadCurve(to: CGPoint(x: w * 0.51, y: h * 0.54), control: CGPoint(x: w * 0.56, y: h * 0.56))
        path.closeSubpath()
        
        return path
    }
}

/// Hamstrings (Posterior Thighs)
public struct BackHamstringsShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Left Hamstring
        path.move(to: CGPoint(x: w * 0.38, y: h * 0.56))
        path.addQuadCurve(to: CGPoint(x: w * 0.37, y: h * 0.71), control: CGPoint(x: w * 0.34, y: h * 0.64))
        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.71))
        path.addQuadCurve(to: CGPoint(x: w * 0.47, y: h * 0.56), control: CGPoint(x: w * 0.45, y: h * 0.64))
        path.closeSubpath()
        
        // Right Hamstring
        path.move(to: CGPoint(x: w * 0.62, y: h * 0.56))
        path.addQuadCurve(to: CGPoint(x: w * 0.63, y: h * 0.71), control: CGPoint(x: w * 0.66, y: h * 0.64))
        path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.71))
        path.addQuadCurve(to: CGPoint(x: w * 0.53, y: h * 0.56), control: CGPoint(x: w * 0.55, y: h * 0.64))
        path.closeSubpath()
        
        return path
    }
}

/// Calves (Back Gastrocnemius & Soleus)
public struct BackCalvesShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Left Calf
        path.move(to: CGPoint(x: w * 0.38, y: h * 0.76))
        path.addQuadCurve(to: CGPoint(x: w * 0.40, y: h * 0.90), control: CGPoint(x: w * 0.35, y: h * 0.83))
        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.90))
        path.addQuadCurve(to: CGPoint(x: w * 0.44, y: h * 0.76), control: CGPoint(x: w * 0.46, y: h * 0.83))
        path.closeSubpath()
        
        // Right Calf
        path.move(to: CGPoint(x: w * 0.62, y: h * 0.76))
        path.addQuadCurve(to: CGPoint(x: w * 0.60, y: h * 0.90), control: CGPoint(x: w * 0.65, y: h * 0.83))
        path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.90))
        path.addQuadCurve(to: CGPoint(x: w * 0.56, y: h * 0.76), control: CGPoint(x: w * 0.54, y: h * 0.83))
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    VStack {
        MuscleMapView(
            engagement: [
                .chest: 0.8,
                .shoulders: 0.7,
                .quads: 0.9,
                .back: 0.6,
                .glutes: 0.75,
                .core: 0.5
            ]
        )
        .padding()
    }
    #if canImport(UIKit)
    .background(Color(uiColor: .systemGroupedBackground))
    #else
    .background(Color.gray.opacity(0.1))
    #endif
}
