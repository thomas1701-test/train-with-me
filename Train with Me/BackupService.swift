import UIKit
import HealthKit

@Observable
final class BackupService {

    var message: String? = nil

    // MARK: - Backup Export

    func createBackupFile(training: TrainingService, health: HealthService) -> URL? {
        do {
            var imgs: [String: Data] = [:]
            let docs = training.documentsURL
            for m in training.machines {
                if let d = try? Data(contentsOf: docs.appendingPathComponent(m.imageFileName)) {
                    imgs[m.imageFileName] = d
                }
            }
            let backup = BackupData(
                machines: training.machines.map { m in
                    MachineData(id: m.id, name: m.name, muscleGroup: m.muscleGroup,
                                imageFileName: m.imageFileName, notes: m.notes, isAssisted: m.isAssisted, isTimed: m.isTimed,
                                sets: m.sets.map { ExerciseSetData(id: $0.id, weight: $0.weight, reps: $0.reps, date: $0.date) })
                },
                muscleGroups:   training.muscleGroupNames(),
                routines:       training.routines.map { RoutineData(id: $0.id, name: $0.name, machineIDs: $0.machineIDs) },
                weightHistory:  health.weightHistory,  waistHistory:   health.waistHistory,
                bodyFatHistory: health.bodyFatHistory, bicepsHistory:  health.bicepsHistory,
                chestHistory:   health.chestHistory,   thighHistory:   health.thighHistory,
                imagesData:     imgs
            )
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Backup.json")
            try JSONEncoder().encode(backup).write(to: url)
            return url
        } catch {
            message = "Backup fehlgeschlagen: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Backup Import

    func restoreBackupData(_ data: Data, training: TrainingService, health: HealthService,
                           healthKitEnabled: Bool) {
        do {
            let b = try JSONDecoder().decode(BackupData.self, from: data)
            try training.replaceAll(machines: b.machines, routines: b.routines ?? [],
                                    muscleGroups: b.muscleGroups, imgs: b.imagesData)
            try health.restoreBodyMeasurements(from: b)
            message = "Backup importiert! ✅"
        } catch let primaryError {
            if let b = try? JSONDecoder().decode(LegacyBackupData.self, from: data) {
                do {
                    try training.replaceAll(machines: b.machines, routines: [],
                                            muscleGroups: b.muscleGroups, imgs: b.imagesData)
                    message = "Backup importiert! ✅"
                } catch {
                    message = "Import fehlgeschlagen: \(error)"
                }
            } else {
                message = "Import fehlgeschlagen: \(primaryError)"
            }
        }
    }

    // MARK: - CSV Export

    func generateCSV(machines: [Machine]) -> URL? {
        do {
            var s = "Datum;Übung;Muskel;Gewicht;Wdh;Volumen;1RM\n"
            let f = DateFormatter(); f.dateStyle = .short
            let rows = machines.flatMap { m in m.sets.map { (m.name, m.muscleGroup, $0) } }
                               .sorted { $0.2.date > $1.2.date }
            for row in rows {
                s += "\(f.string(from: row.2.date));\(row.0);\(row.1);\(row.2.weight);\(row.2.reps);\(row.2.volume);\(row.2.oneRepMax)\n"
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Export.csv")
            try s.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            message = "CSV-Export fehlgeschlagen."
            return nil
        }
    }

    // MARK: - Cardio Import from HealthKit

    func importCardioFromHealth(training: TrainingService, health: HealthService, completion: @escaping () -> Void) {
        health.fetchCardioWorkouts { [weak self] workouts in
            guard let self else { return }
            var count = 0
            for w in workouts {
                let name  = "Health: " + health.activityName(for: w.workoutActivityType)
                let min   = String(format: "%.1f", w.duration / 60).replacingOccurrences(of: ".", with: ",")
                let kcal  = String(format: "%.0f", w.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0)
                if let m = training.machines.first(where: { $0.name == name && $0.muscleGroup == "Cardio" }) {
                    if !m.sets.contains(where: { abs($0.date.timeIntervalSince(w.startDate)) < 60 }) {
                        let s = ExerciseSet(weight: min, reps: kcal, date: w.startDate)
                        s.duration = w.duration / 60; s.calories = Double(kcal) ?? 0
                        m.sets.append(s); count += 1
                    }
                } else {
                    let id  = UUID()
                    let img = UIImage(color: .darkGray, size: CGSize(width: 400, height: 400)) ?? UIImage()
                    let m   = Machine(id: id, name: name, muscleGroup: "Cardio",
                                      imageFileName: training.saveImage(image: img, id: id))
                    let s   = ExerciseSet(weight: min, reps: kcal, date: w.startDate)
                    s.duration = w.duration / 60; s.calories = Double(kcal) ?? 0
                    m.sets.append(s)
                    training.insertMachine(m); count += 1
                }
            }
            DispatchQueue.main.async {
                if count > 0 { training.calculateStats() }
                self.message = count > 0 ? "\(count) Cardio-Trainings importiert!" : "Keine neuen Cardio-Trainings."
                completion()
            }
        }
    }
}
