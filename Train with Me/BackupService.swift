import UIKit
import HealthKit
import SwiftData

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
                                imageFileName: m.imageFileName, notes: m.notes, isAssisted: m.isAssisted,
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
                           ctx: ModelContext, healthKitEnabled: Bool) {
        if let b = try? JSONDecoder().decode(BackupData.self, from: data) {
            training.replaceAll(machines: b.machines, routines: b.routines ?? [],
                                muscleGroups: b.muscleGroups, imgs: b.imagesData, ctx: ctx)
            restoreBodyData(b, health: health, ctx: ctx, healthKitEnabled: healthKitEnabled)
            message = "Backup importiert! ✅"
        } else if let b = try? JSONDecoder().decode(LegacyBackupData.self, from: data) {
            training.replaceAll(machines: b.machines, routines: [],
                                muscleGroups: b.muscleGroups, imgs: b.imagesData, ctx: ctx)
            message = "Legacy-Backup importiert! ✅"
        } else {
            message = "Unbekanntes Backup-Format."
        }
    }

    private func restoreBodyData(_ b: BackupData, health: HealthService,
                                  ctx: ModelContext, healthKitEnabled: Bool) {
        let existing = (try? ctx.fetch(FetchDescriptor<BodyMeasurement>())) ?? []
        existing.forEach { ctx.delete($0) }
        func insert(_ type: String, _ points: [ChartDataPoint]?) {
            for p in (points ?? []) { ctx.insert(BodyMeasurement(date: p.date, type: type, value: p.value)) }
        }
        insert("weight",  b.weightHistory);  insert("waist",   b.waistHistory)
        insert("bodyFat", b.bodyFatHistory); insert("biceps",  b.bicepsHistory)
        insert("chest",   b.chestHistory);   insert("thigh",   b.thighHistory)
        try? ctx.save()
        let all = (try? ctx.fetch(FetchDescriptor<BodyMeasurement>(sortBy: [SortDescriptor(\.date)]))) ?? []
        health.weightHistory  = all.filter { $0.type == "weight"  }.map { ChartDataPoint(date: $0.date, value: $0.value) }
        health.waistHistory   = all.filter { $0.type == "waist"   }.map { ChartDataPoint(date: $0.date, value: $0.value) }
        health.bodyFatHistory = all.filter { $0.type == "bodyFat" }.map { ChartDataPoint(date: $0.date, value: $0.value) }
        health.bicepsHistory  = all.filter { $0.type == "biceps"  }.map { ChartDataPoint(date: $0.date, value: $0.value) }
        health.chestHistory   = all.filter { $0.type == "chest"   }.map { ChartDataPoint(date: $0.date, value: $0.value) }
        health.thighHistory   = all.filter { $0.type == "thigh"   }.map { ChartDataPoint(date: $0.date, value: $0.value) }
        health.currentWeight  = health.weightHistory.last?.value ?? health.currentWeight
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
