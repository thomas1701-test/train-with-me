import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - UIImage Extension

extension UIImage {
    convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill(); UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
}

// MARK: - SwiftData Models

@Model final class ExerciseSet {
    var id: UUID
    var weight: String
    var reps: String
    var date: Date

    var rpe: Int?
    var rir: Int?
    var duration: Double?    // cardio: minutes (nil for strength sets)
    var calories: Double?    // cardio: kcal    (nil for strength sets)

    var volume: Double {
        // For cardio sets use duration as the "volume" proxy (minutes)
        if let d = duration { return d }
        let w = weight.replacingOccurrences(of: ",", with: ".")
        guard let wv = Double(w), let rv = Double(reps) else { return 0 }
        return wv * rv
    }
    var oneRepMax: Double {
        let w = weight.replacingOccurrences(of: ",", with: ".")
        guard let wv = Double(w), let rv = Double(reps) else { return 0 }
        if rv == 1 { return wv }
        return wv * (1 + rv / 30.0)
    }
    var intensityScore: Double? {
        guard let r = rpe, let ri = rir else { return nil }
        return (Double(r) / 10.0 + Double(5 - ri) / 5.0) / 2.0
    }
    init(id: UUID = UUID(), weight: String, reps: String, date: Date = .now) {
        self.id = id; self.weight = weight; self.reps = reps; self.date = date
    }
}

@Model final class Machine {
    var id: UUID
    var name: String
    var muscleGroup: String
    var imageFileName: String
    var notes: String
    var isAssisted: Bool
    var isTimed: Bool
    @Relationship(deleteRule: .cascade) var sets: [ExerciseSet]
    init(id: UUID = UUID(), name: String, muscleGroup: String, imageFileName: String, notes: String = "", isAssisted: Bool = false, isTimed: Bool = false) {
        self.id = id; self.name = name; self.muscleGroup = muscleGroup
        self.imageFileName = imageFileName; self.notes = notes; self.isAssisted = isAssisted; self.isTimed = isTimed; self.sets = []
    }
}

@Model final class Routine {
    var id: UUID
    var name: String
    var machineIDs: [UUID]
    init(id: UUID = UUID(), name: String, machineIDs: [UUID] = []) {
        self.id = id; self.name = name; self.machineIDs = machineIDs
    }
}

// MARK: - Backup Structs

struct ExerciseSetData: Codable { var id: UUID?; var weight: String; var reps: String; var date: Date }
struct MachineData: Codable { var id: UUID; var name: String; var muscleGroup: String; var imageFileName: String; var notes: String?; var isAssisted: Bool?; var isTimed: Bool?; var sets: [ExerciseSetData] }
struct RoutineData: Codable { var id: UUID; var name: String; var machineIDs: [UUID] }
struct BackupData: Codable {
    let machines: [MachineData]; let muscleGroups: [String]; let routines: [RoutineData]?
    let weightHistory: [ChartDataPoint]?; let waistHistory: [ChartDataPoint]?
    let bodyFatHistory: [ChartDataPoint]?; let bicepsHistory: [ChartDataPoint]?
    let chestHistory: [ChartDataPoint]?; let thighHistory: [ChartDataPoint]?
    let imagesData: [String: Data]
}
struct LegacyBackupData: Codable { let machines: [MachineData]; let muscleGroups: [String]; let imagesData: [String: Data] }

// MARK: - Feature Support Types

enum RecoveryStatus {
    case recovering, almostReady, ready, fresh
    var color: Color {
        switch self {
        case .recovering:  return .red
        case .almostReady: return .orange
        case .ready:       return .yellow
        case .fresh:       return .green
        }
    }
    var label: String {
        switch self {
        case .recovering:  return "Erholt sich"
        case .almostReady: return "Fast bereit"
        case .ready:       return "Bereit"
        case .fresh:       return "Ausgeruht"
        }
    }
    var emoji: String {
        switch self { case .recovering: return "😴"; case .almostReady: return "🟡"; case .ready: return "🟢"; case .fresh: return "💪" }
    }
}

struct Achievement: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let subtitle: String
    var isUnlocked: Bool
}

struct PersonalRecord: Identifiable {
    let id = UUID()
    let machineName: String
    let muscleGroup: String
    let isAssisted: Bool
    let isTimed: Bool
    let maxWeight: Double   // normal: highest weight; assisted: lowest weight; timed: best duration in seconds
    let maxReps: Int
    let bestOneRepMax: Double
    let date: Date
}

struct OverloadSuggestion {
    let lastWeight: Double
    let lastReps: Int
    let message: String
}

// MARK: - Chart / UI Models

struct ChartDataPoint: Identifiable, Codable {
    var id: UUID
    var date: Date
    var value: Double

    init(id: UUID = UUID(), date: Date, value: Double) {
        self.id = id; self.date = date; self.value = value
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id    = (try? c.decode(UUID.self,   forKey: .id))    ?? UUID()
        self.date  = try  c.decode(Date.self,    forKey: .date)
        self.value = try  c.decode(Double.self,  forKey: .value)
    }
}
struct MuscleShare: Identifiable { var id = UUID(); var name: String; var percentage: Double }

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case midnight = "Midnight"; case beast = "Beast Mode"; case sunset = "Sunset"; case ocean = "Ocean"
    var id: String { rawValue }
    var accentColor: Color {
        switch self {
        case .midnight: return Color(red: 0.45, green: 0.55, blue: 1.0)
        case .beast:    return Color(red: 1.0,  green: 0.25, blue: 0.25)
        case .sunset:   return Color(red: 1.0,  green: 0.5,  blue: 0.2)
        case .ocean:    return Color(red: 0.2,  green: 0.85, blue: 1.0)
        }
    }
    var accentGradient: LinearGradient {
        switch self {
        case .midnight: return LinearGradient(colors: [Color(red:0.4,green:0.5,blue:1.0), Color(red:0.6,green:0.3,blue:1.0)], startPoint: .leading, endPoint: .trailing)
        case .beast:    return LinearGradient(colors: [Color(red:1.0,green:0.2,blue:0.2), Color(red:1.0,green:0.5,blue:0.0)], startPoint: .leading, endPoint: .trailing)
        case .sunset:   return LinearGradient(colors: [Color(red:1.0,green:0.4,blue:0.1), Color(red:1.0,green:0.2,blue:0.5)], startPoint: .leading, endPoint: .trailing)
        case .ocean:    return LinearGradient(colors: [Color(red:0.0,green:0.8,blue:1.0), Color(red:0.0,green:0.5,blue:0.9)], startPoint: .leading, endPoint: .trailing)
        }
    }
    @ViewBuilder var backgroundView: some View {
        switch self {
        case .midnight:
            MeshGradient(width: 3, height: 3, points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.6, 0.4], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ], colors: [
                Color(red:0.04,green:0.02,blue:0.12), Color(red:0.08,green:0.04,blue:0.20), Color(red:0.02,green:0.02,blue:0.10),
                Color(red:0.10,green:0.05,blue:0.25), Color(red:0.18,green:0.06,blue:0.38), Color(red:0.06,green:0.03,blue:0.18),
                Color(red:0.02,green:0.02,blue:0.08), Color(red:0.08,green:0.04,blue:0.18), Color(red:0.04,green:0.02,blue:0.10)
            ]).ignoresSafeArea()
        case .beast:
            MeshGradient(width: 3, height: 3, points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.7, 0.3], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ], colors: [
                Color(red:0.06,green:0.03,blue:0.03), Color(red:0.08,green:0.04,blue:0.04), Color(red:0.04,green:0.02,blue:0.02),
                Color(red:0.04,green:0.02,blue:0.02), Color(red:0.28,green:0.04,blue:0.04), Color(red:0.18,green:0.03,blue:0.03),
                Color(red:0.04,green:0.02,blue:0.02), Color(red:0.10,green:0.03,blue:0.03), Color(red:0.06,green:0.02,blue:0.02)
            ]).ignoresSafeArea()
        case .sunset:
            MeshGradient(width: 3, height: 3, points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.4, 0.6], [1.0, 0.4],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ], colors: [
                Color(red:0.20,green:0.03,blue:0.10), Color(red:0.28,green:0.06,blue:0.08), Color(red:0.18,green:0.04,blue:0.14),
                Color(red:0.30,green:0.08,blue:0.05), Color(red:0.38,green:0.10,blue:0.18), Color(red:0.24,green:0.06,blue:0.20),
                Color(red:0.12,green:0.04,blue:0.18), Color(red:0.20,green:0.06,blue:0.22), Color(red:0.14,green:0.04,blue:0.16)
            ]).ignoresSafeArea()
        case .ocean:
            MeshGradient(width: 3, height: 3, points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.4], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ], colors: [
                Color(red:0.00,green:0.08,blue:0.18), Color(red:0.00,green:0.12,blue:0.24), Color(red:0.00,green:0.08,blue:0.16),
                Color(red:0.00,green:0.10,blue:0.22), Color(red:0.00,green:0.22,blue:0.36), Color(red:0.00,green:0.12,blue:0.28),
                Color(red:0.00,green:0.06,blue:0.14), Color(red:0.00,green:0.10,blue:0.20), Color(red:0.00,green:0.06,blue:0.12)
            ]).ignoresSafeArea()
        }
    }
}

enum VolumeStatus {
    case noData, tooLow, minimal, optimal, high
    var label: String {
        switch self { case .noData: return "Keine Daten"; case .tooLow: return "Zu wenig"; case .minimal: return "Minimal"; case .optimal: return "Optimal"; case .high: return "Sehr viel" }
    }
    var color: Color {
        switch self { case .noData: return .gray; case .tooLow: return .red; case .minimal: return .orange; case .optimal: return .green; case .high: return .blue }
    }
    var icon: String {
        switch self { case .noData: return "minus"; case .tooLow: return "arrow.down"; case .minimal: return "arrow.up.right"; case .optimal: return "checkmark"; case .high: return "exclamationmark" }
    }
}

enum PeriodizationPhase: Equatable {
    case strength, hypertrophy, noData
    var title: String {
        switch self { case .strength: return "Kraftphase"; case .hypertrophy: return "Hypertrophiephase"; case .noData: return "" }
    }
    var emoji: String {
        switch self { case .strength: return "🏋️"; case .hypertrophy: return "💪"; case .noData: return "" }
    }
    var description: String {
        switch self {
        case .strength:    return "Du trainierst viel im Kraftbereich (≤6 Wdh). Ein Wechsel zu 8–12 Wdh maximiert das Muskelwachstum."
        case .hypertrophy: return "Du trainierst im Hypertrophiebereich (7–12 Wdh). Eine Kraftphase mit 4–6 Wdh baut Grundstärke auf."
        case .noData:      return ""
        }
    }
    var suggestion: String {
        switch self { case .strength: return "Tipp: Wechsel zu Hypertrophie (8–12 Wdh)"; case .hypertrophy: return "Tipp: Probiere eine Kraftphase (4–6 Wdh)"; case .noData: return "" }
    }
}

enum ChartMetric: String, CaseIterable, Identifiable { case oneRepMax = "🔥 1RM"; case volume = "📊 Volumen"; case maxWeight = "⚖️ Max kg"; var id: String { rawValue } }
enum ChartTimeRange: String, CaseIterable, Identifiable { case week = "1W"; case month = "1M"; case quarter = "3M"; case half = "6M"; case year = "1J"; case all = "Alle"; var id: String { rawValue } }

extension UTType {
    static var trainingBackup: UTType { UTType(importedAs: "com.trainwithme.backup") }
    static var csv: UTType { UTType(importedAs: "public.comma-separated-values-text") }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var fileURL: URL
    init(fileURL: URL) { self.fileURL = fileURL }
    init(configuration: ReadConfiguration) throws { fileURL = URL(fileURLWithPath: "") }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try Data(contentsOf: fileURL))
    }
}
