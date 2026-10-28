import Foundation

/// Intensity scale for logged cycle symptoms.
public enum SymptomIntensity: String, Codable, CaseIterable, Identifiable {
    case mild = "Mild"
    case moderate = "Moderate"
    case severe = "Severe"
    
    public var id: String { rawValue }
    
    public var score: Int {
        switch self {
        case .mild: return 1
        case .moderate: return 2
        case .severe: return 3
        }
    }
}

/// Standardized cycle symptoms matching the 8 categories in `DesignReferences/cycle-screen.jpeg`.
public enum CycleSymptomType: String, Codable, CaseIterable, Identifiable {
    case cramps = "Cramps"
    case mood = "Mood"
    case fatigue = "Fatigue"
    case bloating = "Bloating"
    case headache = "Headache"
    case backache = "Backache"
    case cravings = "Cravings"
    case acne = "Acne"
    
    public var id: String { rawValue }
    
    public var systemIcon: String {
        switch self {
        case .cramps: return "drop.fill"
        case .mood: return "face.smiling"
        case .fatigue: return "moon.zzz.fill"
        case .bloating: return "balloon.fill"
        case .headache: return "brain.head.profile"
        case .backache: return "figure.walk"
        case .cravings: return "birthday.cake.fill"
        case .acne: return "circle.grid.cross.fill"
        }
    }
}

/// Individual user-recorded symptom entry with timestamp and intensity.
public struct LoggedSymptom: Identifiable, Codable, Equatable {
    public let id: UUID
    public let type: CycleSymptomType
    public var intensity: SymptomIntensity
    public var date: Date
    public var notes: String?
    
    public init(
        id: UUID = UUID(),
        type: CycleSymptomType,
        intensity: SymptomIntensity = .mild,
        date: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.type = type
        self.intensity = intensity
        self.date = date
        self.notes = notes
    }
}
