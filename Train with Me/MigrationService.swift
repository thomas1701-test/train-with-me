import Foundation
import SwiftData

/// Runs once at app launch (guarded by UserDefaults flag) to migrate data from
/// UserDefaults into SwiftData for MuscleGroup, BodyMeasurement, and Cardio sets.
final class MigrationService {

    static func runIfNeeded(context: ModelContext) {
        let key = "migration_v2_done"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        migrateMuscleGroups(context: context)
        migrateBodyMeasurements(context: context)
        migrateCardioSets(context: context)
        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }

    // MARK: - Muscle Groups

    private static func migrateMuscleGroups(context: ModelContext) {
        // Only migrate if no MuscleGroup rows exist yet
        let existing = (try? context.fetch(FetchDescriptor<MuscleGroup>())) ?? []
        guard existing.isEmpty else { return }

        let ud = UserDefaults.standard
        let names: [String]
        if let d = ud.data(forKey: "Data_Groups"),
           let v = try? JSONDecoder().decode([String].self, from: d) {
            names = v
        } else {
            names = ["Brust", "Rücken", "Beine", "Arme", "Bauch", "Schultern", "Cardio"]
        }
        for (i, name) in names.enumerated() {
            context.insert(MuscleGroup(name: name, sortIndex: i))
        }
        ud.removeObject(forKey: "Data_Groups")
    }

    // MARK: - Body Measurements

    private static func migrateBodyMeasurements(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<BodyMeasurement>())) ?? []
        guard existing.isEmpty else { return }

        let ud = UserDefaults.standard
        let mapping: [(key: String, type: String)] = [
            ("Data_Weight", "weight"),
            ("Data_Waist",  "waist"),
            ("Data_Fat",    "bodyFat"),
            ("Data_Biceps", "biceps"),
            ("Data_Chest",  "chest"),
            ("Data_Thigh",  "thigh"),
        ]
        for (key, type) in mapping {
            guard let d = ud.data(forKey: key),
                  let points = try? JSONDecoder().decode([ChartDataPoint].self, from: d) else { continue }
            for p in points {
                context.insert(BodyMeasurement(date: p.date, type: type, value: p.value))
            }
            ud.removeObject(forKey: key)
        }
    }

    // MARK: - Cardio Sets

    private static func migrateCardioSets(context: ModelContext) {
        let machines = (try? context.fetch(FetchDescriptor<Machine>())) ?? []
        for machine in machines where machine.muscleGroup.lowercased() == "cardio" {
            for set in machine.sets where set.duration == nil {
                // weight field held minutes, reps field held kcal
                if let min = Double(set.weight.replacingOccurrences(of: ",", with: ".")) {
                    set.duration = min
                }
                if let kcal = Double(set.reps.replacingOccurrences(of: ",", with: ".")) {
                    set.calories = kcal
                }
            }
        }
    }
}
