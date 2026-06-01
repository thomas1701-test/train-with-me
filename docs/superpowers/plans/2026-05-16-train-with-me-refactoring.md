# Train with Me — Refactoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the monolithic `FitnessViewModel` into focused `@Observable` services, consolidate all model data into SwiftData, and move the Gemini API key to a gitignored `.xcconfig` file — keeping all features and UI identical.

**Architecture:** A slim `@Observable AppViewModel` owns UI state and holds references to 5 `@Observable` services (`TrainingService`, `HealthService`, `GeminiService`, `WatchService`, `BackupService`). AppViewModel is injected via `@Environment`. Views access services through it: `viewModel.training.machines`, `viewModel.health.weightHistory`. All model data lives in SwiftData — two new `@Model` classes (`BodyMeasurement`, `MuscleGroup`) replace the UserDefaults arrays. `MigrationService` runs once at launch to transfer existing data.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, `@Observable` macro (iOS 17+), HealthKit, WatchConnectivity, ActivityKit, Swift Charts, GoogleGenerativeAI SDK

**Note on Xcode project:** All new Swift files are created inside `Train with Me/` so Xcode sees them immediately. After each new file is created, open Xcode → right-click the `Train with Me` group → **Add Files to "Train with Me"** → select the file and confirm the target checkbox is ticked.

---

## File Map

| Action | File |
|--------|------|
| Create | `Train with Me/AppViewModel.swift` |
| Create | `Train with Me/TrainingService.swift` |
| Create | `Train with Me/HealthService.swift` |
| Create | `Train with Me/GeminiService.swift` |
| Create | `Train with Me/WatchService.swift` |
| Create | `Train with Me/BackupService.swift` |
| Create | `Train with Me/BodyMeasurement.swift` |
| Create | `Train with Me/MuscleGroup.swift` |
| Create | `Train with Me/MigrationService.swift` |
| Create | `Secrets.xcconfig` (gitignored) |
| Create | `Secrets.xcconfig.template` |
| Modify | `Secrets.swift` |
| Modify | `Train with Me/Models.swift` — add `duration`/`calories` to ExerciseSet |
| Modify | `Train with Me/Train_with_MeApp.swift` |
| Modify | `Train with Me/ContentView.swift` |
| Modify | `Train with Me/TrainingView.swift` |
| Modify | `Train with Me/MachineListView.swift` |
| Modify | `Train with Me/SmartStatsView.swift` |
| Modify | `Train with Me/BodyStatsView.swift` |
| Modify | `Train with Me/HistoryView.swift` |
| Modify | `Train with Me/SettingsView.swift` |
| Modify | `Train with Me/GamificationView.swift` |
| Modify | `Train with Me/PRDashboardView.swift` |
| Modify | `Train with Me/WorkoutCalendarView.swift` |
| Modify | `Train with Me/MuscleHeatmapView.swift` |
| Modify | `Train with Me/CreateRoutineView.swift` |
| Modify | `Train with Me/RoutineDetailView.swift` |
| Modify | `.gitignore` |
| Delete | `Train with Me/FitnessViewModel.swift` |
| Delete | `Train with Me/HealthManager.swift` |
| Delete | `Train with Me/Untitled.swift` |

---

## Task 1: API Key via xcconfig

**Files:**
- Create: `Secrets.xcconfig`
- Create: `Secrets.xcconfig.template`
- Modify: `Secrets.swift`
- Modify: `.gitignore`

- [ ] **Step 1: Create `Secrets.xcconfig.template`** (safe to commit)

```
// Copy this file to Secrets.xcconfig and fill in your key.
// Secrets.xcconfig is gitignored — never commit it.
GEMINI_API_KEY = YOUR_GEMINI_KEY_HERE
```

- [ ] **Step 2: Create `Secrets.xcconfig`** (will be gitignored)

Copy `Secrets.xcconfig.template` to `Secrets.xcconfig` and insert the real key from the current `Secrets.swift`:

```
GEMINI_API_KEY = <DEIN_GEMINI_KEY>
```

- [ ] **Step 3: Wire xcconfig into Xcode project**

Open `Train with Me.xcodeproj` in Xcode:
1. Click the project (blue icon) in the navigator → select the **project** (not a target) → **Info** tab
2. Under **Configurations**, for both **Debug** and **Release**, set the configuration file to `Secrets.xcconfig`
3. Open `Train-with-Me-Info.plist` → add a new row: key `GEMINI_API_KEY`, value `$(GEMINI_API_KEY)`

- [ ] **Step 4: Update `Secrets.swift`**

Replace the entire file content:

```swift
import Foundation

enum Secrets {
    static var geminiKey: String {
        Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String ?? ""
    }
}
```

- [ ] **Step 5: Add `Secrets.xcconfig` to `.gitignore`**

Append to `.gitignore` (create it at repo root if it doesn't exist):

```
Secrets.xcconfig
```

- [ ] **Step 6: Commit**

```bash
git add Secrets.xcconfig.template Secrets.swift .gitignore
git commit -m "feat: move Gemini API key to gitignored xcconfig"
```

---

## Task 2: New SwiftData Models

**Files:**
- Create: `Train with Me/BodyMeasurement.swift`
- Create: `Train with Me/MuscleGroup.swift`
- Modify: `Train with Me/Models.swift`

- [ ] **Step 1: Create `Train with Me/BodyMeasurement.swift`**

```swift
import Foundation
import SwiftData

@Model final class BodyMeasurement {
    var id: UUID
    var date: Date
    var type: String   // "weight" | "waist" | "bodyFat" | "biceps" | "chest" | "thigh"
    var value: Double

    init(date: Date, type: String, value: Double) {
        self.id = UUID()
        self.date = date
        self.type = type
        self.value = value
    }
}
```

Add file to Xcode target (see note at top of plan).

- [ ] **Step 2: Create `Train with Me/MuscleGroup.swift`**

```swift
import Foundation
import SwiftData

@Model final class MuscleGroup {
    var id: UUID
    var name: String
    var sortIndex: Int

    init(name: String, sortIndex: Int) {
        self.id = UUID()
        self.name = name
        self.sortIndex = sortIndex
    }
}
```

Add file to Xcode target.

- [ ] **Step 3: Add `duration` and `calories` to `ExerciseSet` in `Models.swift`**

Find the `ExerciseSet` class (line 21) and add two optional stored properties after `var rir: Int?`:

```swift
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
```

- [ ] **Step 4: Verify build compiles**

Open Xcode → `Cmd+B`. Fix any errors (likely none at this stage).

- [ ] **Step 5: Commit**

```bash
git add "Train with Me/BodyMeasurement.swift" "Train with Me/MuscleGroup.swift" "Train with Me/Models.swift"
git commit -m "feat: add BodyMeasurement, MuscleGroup models; add duration/calories to ExerciseSet"
```

---

## Task 3: MigrationService

**Files:**
- Create: `Train with Me/MigrationService.swift`

- [ ] **Step 1: Create `Train with Me/MigrationService.swift`**

```swift
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
```

Add file to Xcode target.

- [ ] **Step 2: Build check**

`Cmd+B` in Xcode. Fix any errors.

- [ ] **Step 3: Commit**

```bash
git add "Train with Me/MigrationService.swift"
git commit -m "feat: add MigrationService for UserDefaults → SwiftData migration"
```

---

## Task 4: TrainingService

**Files:**
- Create: `Train with Me/TrainingService.swift`

- [ ] **Step 1: Create `Train with Me/TrainingService.swift`**

```swift
import SwiftUI
import SwiftData

@Observable
final class TrainingService {

    // MARK: - State
    var machines: [Machine] = []
    var muscleGroups: [MuscleGroup] = []
    var routines: [Routine] = []
    var muscleShare: [MuscleShare] = []
    var weeklyTrend: Double = 0.0

    private var modelContext: ModelContext?

    // MARK: - Setup

    func configure(modelContext: ModelContext) {
        guard self.modelContext == nil else { return }
        self.modelContext = modelContext
        fetchAll()
        ensureDefaultGroups()
        calculateStats()
    }

    private func fetchAll() {
        guard let ctx = modelContext else { return }
        machines     = (try? ctx.fetch(FetchDescriptor<Machine>())) ?? []
        muscleGroups = (try? ctx.fetch(FetchDescriptor<MuscleGroup>(sortBy: [SortDescriptor(\.sortIndex)]))) ?? []
        routines     = (try? ctx.fetch(FetchDescriptor<Routine>())) ?? []
    }

    func muscleGroupNames() -> [String] { muscleGroups.map { $0.name } }

    // MARK: - MuscleGroup CRUD

    func addMuscleGroup(name: String) {
        guard let ctx = modelContext, !muscleGroups.contains(where: { $0.name == name }) else { return }
        let g = MuscleGroup(name: name, sortIndex: muscleGroups.count)
        ctx.insert(g); muscleGroups.append(g); saveContext()
    }

    func deleteMuscleGroup(name: String) {
        guard let ctx = modelContext, let g = muscleGroups.first(where: { $0.name == name }) else { return }
        ctx.delete(g); muscleGroups.removeAll { $0.name == name }; saveContext()
    }

    func renameMuscleGroup(oldName: String, newName: String) {
        guard let g = muscleGroups.first(where: { $0.name == oldName }) else { return }
        g.name = newName
        machines.filter { $0.muscleGroup == oldName }.forEach { $0.muscleGroup = newName }
        saveContext()
    }

    func ensureDefaultGroups() {
        let defaults = ["Brust", "Rücken", "Beine", "Arme", "Bauch", "Schultern", "Cardio"]
        var changed = false
        for name in defaults where !muscleGroups.contains(where: { $0.name == name }) {
            let g = MuscleGroup(name: name, sortIndex: muscleGroups.count)
            modelContext?.insert(g); muscleGroups.append(g); changed = true
        }
        if changed { saveContext() }
    }

    // MARK: - Machine CRUD

    func addMachine(muscle: String, image: UIImage) {
        guard let ctx = modelContext else { return }
        let id = UUID()
        let m = Machine(id: id, name: "Gerät \(machines.count + 1)", muscleGroup: muscle,
                        imageFileName: saveImage(image: image, id: id))
        ctx.insert(m); machines.append(m); saveContext()
    }

    func renameMachine(machineId: UUID, newName: String) {
        machines.first(where: { $0.id == machineId })?.name = newName
    }

    func updateMachineImage(machineId: UUID, newImage: UIImage) {
        guard let m = machines.first(where: { $0.id == machineId }) else { return }
        m.imageFileName = saveImage(image: newImage, id: UUID())
    }

    func updateMachineNotes(machineId: UUID, notes: String) {
        machines.first(where: { $0.id == machineId })?.notes = notes
    }

    func deleteMachine(machine: Machine) {
        guard let ctx = modelContext else { return }
        deleteImageFile(fileName: machine.imageFileName)
        ctx.delete(machine); machines.removeAll { $0.id == machine.id }
    }

    // MARK: - Set CRUD

    /// Returns true if today's volume is a new personal best for this machine.
    @discardableResult
    func addSet(machineId: UUID, weight: String, reps: String) -> Bool {
        guard let m = machines.first(where: { $0.id == machineId }) else { return false }
        m.sets.append(ExerciseSet(weight: weight, reps: reps, date: Date()))
        calculateStats()
        let todayVol = m.sets.filter { Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.volume }
        let bestVol  = Dictionary(grouping: m.sets) { Calendar.current.startOfDay(for: $0.date) }
            .filter { !Calendar.current.isDateInToday($0.key) }
            .map { $0.value.reduce(0) { $0 + $1.volume } }.max() ?? 0
        return todayVol > bestVol && bestVol > 0
    }

    func addCardioSet(machineId: UUID, duration: Double, calories: Double) {
        guard let m = machines.first(where: { $0.id == machineId }) else { return }
        let s = ExerciseSet(weight: String(duration), reps: String(calories), date: Date())
        s.duration = duration; s.calories = calories
        m.sets.append(s); calculateStats()
    }

    func deleteSet(machineId: UUID, setId: UUID) {
        machines.first(where: { $0.id == machineId })?.sets.removeAll { $0.id == setId }
        calculateStats()
    }

    func updateSetIntensity(machineId: UUID, setId: UUID, rpe: Int, rir: Int) {
        guard let m = machines.first(where: { $0.id == machineId }),
              let s = m.sets.first(where: { $0.id == setId }) else { return }
        s.rpe = rpe; s.rir = rir
    }

    // MARK: - Routine CRUD

    func addRoutine(name: String, selectedMachines: [Machine]) {
        guard let ctx = modelContext else { return }
        let r = Routine(name: name, machineIDs: selectedMachines.map { $0.id })
        ctx.insert(r); routines.append(r)
    }

    func deleteRoutine(at offsets: IndexSet) {
        guard let ctx = modelContext else { return }
        for i in offsets { ctx.delete(routines[i]) }
        routines.remove(atOffsets: offsets)
    }

    // MARK: - Progressive Overload

    func progressiveOverloadSuggestion(for machineId: UUID) -> OverloadSuggestion? {
        guard let machine = machines.first(where: { $0.id == machineId }), !machine.sets.isEmpty else { return nil }
        let cal = Calendar.current
        let byDay = Dictionary(grouping: machine.sets) { cal.startOfDay(for: $0.date) }.sorted { $0.key > $1.key }
        guard !byDay.isEmpty else { return nil }
        let last  = byDay[0].value
        let lastW = last.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.max() ?? 0
        let lastR = last.compactMap { Int($0.reps) }.max() ?? 0
        if byDay.count == 1 {
            return OverloadSuggestion(lastWeight: lastW, lastReps: lastR,
                message: "Letztes Mal: \(fmt(lastW)) kg × \(lastR) – mehr Wiederholungen versuchen 🎯")
        }
        let prev  = byDay[1].value
        let prevW = prev.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.max() ?? 0
        if lastW >= prevW && lastR >= 8 {
            return OverloadSuggestion(lastWeight: lastW, lastReps: lastR,
                message: "Letztes Mal: \(fmt(lastW)) kg × \(lastR) → heute \(fmt(lastW + 2.5)) kg versuchen 💡")
        } else if lastW >= prevW {
            return OverloadSuggestion(lastWeight: lastW, lastReps: lastR,
                message: "Letztes Mal: \(fmt(lastW)) kg × \(lastR) – ziel auf \(lastR + 2)+ Wdh 🎯")
        } else {
            return OverloadSuggestion(lastWeight: lastW, lastReps: lastR,
                message: "Letztes Mal: \(fmt(lastW)) kg × \(lastR)")
        }
    }

    // MARK: - Recovery

    func recoveryStatus(for muscleGroup: String) -> RecoveryStatus {
        let last = machines.filter { $0.muscleGroup == muscleGroup }.flatMap { $0.sets }.max(by: { $0.date < $1.date })
        guard let l = last else { return .fresh }
        let h = Date().timeIntervalSince(l.date) / 3600
        if h < 24 { return .recovering }
        if h < 48 { return .almostReady }
        if h < 72 { return .ready }
        return .fresh
    }

    // MARK: - Volume Intelligence

    func weeklySets(for muscleGroup: String) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return machines.filter { $0.muscleGroup == muscleGroup }.flatMap { $0.sets }.filter { $0.date > cutoff }.count
    }

    func volumeStatus(for muscleGroup: String) -> VolumeStatus {
        let sets = weeklySets(for: muscleGroup)
        if sets == 0  { return .noData }
        if sets < 5   { return .tooLow }
        if sets <= 10 { return .minimal }
        if sets <= 20 { return .optimal }
        return .high
    }

    var shouldSuggestDeload: Bool {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        let recent = machines.flatMap { $0.sets }.filter { $0.date > cutoff }
        guard recent.count >= 30 else { return false }
        let rpes = recent.compactMap { $0.rpe }
        guard rpes.count >= 15 else { return false }
        return Double(rpes.reduce(0, +)) / Double(rpes.count) >= 8.0
    }

    var periodizationPhase: PeriodizationPhase {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        let reps = machines.filter { $0.muscleGroup.lowercased() != "cardio" }
            .flatMap { $0.sets }.filter { $0.date > cutoff }.compactMap { Int($0.reps) }
        guard reps.count >= 10 else { return .noData }
        let avg = Double(reps.reduce(0, +)) / Double(reps.count)
        return avg <= 6 ? .strength : .hypertrophy
    }

    // MARK: - Streak

    var currentStreak: Int {
        let cal   = Calendar.current
        let dates = Set(machines.flatMap { $0.sets }.map { cal.startOfDay(for: $0.date) })
        var check = cal.startOfDay(for: Date())
        if !dates.contains(check) { check = cal.date(byAdding: .day, value: -1, to: check)! }
        var streak = 0
        while dates.contains(check) { streak += 1; check = cal.date(byAdding: .day, value: -1, to: check)! }
        return streak
    }

    var longestStreak: Int {
        let cal   = Calendar.current
        let dates = Set(machines.flatMap { $0.sets }.map { cal.startOfDay(for: $0.date) }).sorted()
        guard !dates.isEmpty else { return 0 }
        var longest = 1, current = 1
        for i in 1..<dates.count {
            let diff = cal.dateComponents([.day], from: dates[i-1], to: dates[i]).day ?? 0
            if diff == 1 { current += 1; longest = max(longest, current) } else if diff > 1 { current = 1 }
        }
        return longest
    }

    var totalTrainingDays: Int {
        Set(machines.flatMap { $0.sets }.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    var streakMilestoneMessage: String? {
        switch currentStreak {
        case 3:  return "🔥 3 Tage in Folge — stark!"
        case 7:  return "⚡️ 1 Woche Streak — Wahnsinn!"
        case 14: return "💪 2 Wochen am Stück — Elite!"
        case 30: return "🏆 30 Tage Streak — Legende!"
        default: return nil
        }
    }

    // MARK: - Gamification

    private let xpLevelThresholds = [0, 300, 800, 1800, 3500, 6000, 10000, 16000, 24000, 35000, 50000]
    private let xpLevelTitles = ["Anfänger","Einsteiger","Aktiv","Sportler","Athlet","Veteran","Profi","Champion","Elite","Master","Legende"]

    var totalVolume: Double { machines.flatMap { $0.sets }.reduce(0) { $0 + $1.volume } }

    var totalXP: Int {
        machines.flatMap { $0.sets }.reduce(0) { total, s in
            var xp = Int(s.volume / 10)
            if let rpe = s.rpe, rpe >= 8 { xp = Int(Double(xp) * 1.2) }
            return total + xp
        }
    }

    var currentLevelIndex: Int {
        var idx = 0
        for (i, t) in xpLevelThresholds.enumerated() where totalXP >= t { idx = i }
        return min(idx, xpLevelThresholds.count - 1)
    }

    var levelTitle: String { xpLevelTitles[currentLevelIndex] }

    var levelProgress: Double {
        let lvl = currentLevelIndex
        guard lvl < xpLevelThresholds.count - 1 else { return 1.0 }
        return Double(totalXP - xpLevelThresholds[lvl]) / Double(xpLevelThresholds[lvl + 1] - xpLevelThresholds[lvl])
    }

    var xpToNextLevel: Int {
        let lvl = currentLevelIndex
        guard lvl < xpLevelThresholds.count - 1 else { return 0 }
        return xpLevelThresholds[lvl + 1] - totalXP
    }

    var achievements: [Achievement] {
        let allSets      = machines.flatMap { $0.sets }
        let trainedGroups = Set(machines.filter { !$0.sets.isEmpty }.map { $0.muscleGroup })
        let highRPE      = allSets.filter { ($0.rpe ?? 0) >= 9 }.count
        let vol          = totalVolume
        return [
            Achievement(id: "first_set",     emoji: "🏃", title: "Erster Schritt",  subtitle: "Ersten Satz geloggt",         isUnlocked: !allSets.isEmpty),
            Achievement(id: "ten_sets",       emoji: "💪", title: "Aufgewärmt",       subtitle: "10 Sätze insgesamt",          isUnlocked: allSets.count >= 10),
            Achievement(id: "vol_1k",         emoji: "🏋️", title: "Volumen-Starter", subtitle: "1.000 kg Gesamtvolumen",      isUnlocked: vol >= 1000),
            Achievement(id: "vol_10k",        emoji: "👑", title: "Volumen-König",    subtitle: "10.000 kg Gesamtvolumen",     isUnlocked: vol >= 10000),
            Achievement(id: "vol_100k",       emoji: "⚡️", title: "Volumen-Gott",    subtitle: "100.000 kg Gesamtvolumen",    isUnlocked: vol >= 100000),
            Achievement(id: "first_pr",       emoji: "🏆", title: "Erstes PR",        subtitle: "Personal Record aufgestellt", isUnlocked: !personalRecords.isEmpty),
            Achievement(id: "allrounder",     emoji: "🎯", title: "Allrounder",       subtitle: "Alle Gruppen trainiert",      isUnlocked: muscleGroups.allSatisfy { trainedGroups.contains($0.name) }),
            Achievement(id: "streak_3",       emoji: "🔥", title: "Auf Kurs",         subtitle: "3 Tage Streak",               isUnlocked: longestStreak >= 3),
            Achievement(id: "streak_7",       emoji: "⚡️", title: "Streak Master",   subtitle: "7 Tage Streak",               isUnlocked: longestStreak >= 7),
            Achievement(id: "streak_30",      emoji: "💎", title: "Streak Legende",   subtitle: "30 Tage Streak",              isUnlocked: longestStreak >= 30),
            Achievement(id: "high_intensity", emoji: "😤", title: "Hochintensiv",     subtitle: "10 Sätze mit RPE ≥ 9",        isUnlocked: highRPE >= 10),
            Achievement(id: "days_50",        emoji: "🦾", title: "Veteran",          subtitle: "50 Trainingstage",            isUnlocked: totalTrainingDays >= 50),
        ]
    }

    /// Returns the newly unlocked Achievement (if any) and persists the unlocked list.
    func checkNewAchievements() -> Achievement? {
        let unlocked = achievements.filter { $0.isUnlocked }.map { $0.id }
        let stored   = Set(UserDefaults.standard.stringArray(forKey: "UnlockedAchievements") ?? [])
        guard let newID = unlocked.first(where: { !stored.contains($0) }) else { return nil }
        UserDefaults.standard.set(unlocked, forKey: "UnlockedAchievements")
        return achievements.first { $0.id == newID }
    }

    // MARK: - Personal Records

    var personalRecords: [PersonalRecord] {
        machines.compactMap { m in
            guard !m.sets.isEmpty else { return nil }
            let best = m.sets.max(by: { $0.oneRepMax < $1.oneRepMax })!
            let maxW = m.sets.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.max() ?? 0
            let maxR = m.sets.compactMap { Int($0.reps) }.max() ?? 0
            return PersonalRecord(machineName: m.name, muscleGroup: m.muscleGroup,
                                  maxWeight: maxW, maxReps: maxR, bestOneRepMax: best.oneRepMax, date: best.date)
        }.sorted { $0.bestOneRepMax > $1.bestOneRepMax }
    }

    // MARK: - Calendar

    func volumeForDay(_ date: Date) -> Double {
        let cal = Calendar.current
        let s = cal.startOfDay(for: date), e = cal.date(byAdding: .day, value: 1, to: s)!
        return machines.flatMap { $0.sets }.filter { $0.date >= s && $0.date < e }.reduce(0) { $0 + $1.volume }
    }

    func trainingCalendarData(weeks: Int = 16) -> [(date: Date, volume: Double)] {
        let cal   = Calendar.current
        var start = cal.date(byAdding: .day, value: -(weeks * 7 - 1), to: cal.startOfDay(for: Date()))!
        let today = cal.startOfDay(for: Date())
        var result: [(date: Date, volume: Double)] = []
        while start <= today {
            result.append((date: start, volume: volumeForDay(start)))
            start = cal.date(byAdding: .day, value: 1, to: start)!
        }
        return result
    }

    // MARK: - Stats

    func calculateStats() {
        var dist: [String: Double] = []; var total = 0.0
        for m in machines { let v = m.sets.reduce(0) { $0 + $1.volume }; dist[m.muscleGroup, default: 0] += v; total += v }
        muscleShare  = total > 0 ? dist.map { MuscleShare(name: $0.key, percentage: $0.value / total) }.sorted { $0.percentage > $1.percentage } : []
        let d7  = Calendar.current.date(byAdding: .day, value:  -7, to: Date())!
        let d14 = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        var cur = 0.0, last = 0.0
        for m in machines { for s in m.sets { if s.date >= d7 { cur += s.volume } else if s.date >= d14 { last += s.volume } } }
        weeklyTrend = last > 0 ? ((cur - last) / last) * 100 : 0
    }

    func averageIntensity(for machineId: UUID) -> Double? {
        guard let m = machines.first(where: { $0.id == machineId }) else { return nil }
        let scores = Dictionary(grouping: m.sets) { Calendar.current.startOfDay(for: $0.date) }
            .sorted { $0.key > $1.key }.prefix(4).flatMap { $0.value }.compactMap { $0.intensityScore }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    // MARK: - Image Management

    func saveImage(image: UIImage, id: UUID) -> String {
        let f = "\(id.uuidString).jpg"
        guard let d = image.jpegData(compressionQuality: 0.7) else { return f }
        try? d.write(to: documentsURL.appendingPathComponent(f))
        ImageCache.shared.set(image, for: f)
        return f
    }

    func deleteImageFile(fileName: String) {
        try? FileManager.default.removeItem(at: documentsURL.appendingPathComponent(fileName))
        ImageCache.shared.remove(fileName)
    }

    var documentsURL: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    // MARK: - Bulk Replace (used by BackupService restore)

    func replaceAll(machines ml: [MachineData], routines rl: [RoutineData], muscleGroups gl: [String],
                    imgs: [String: Data], ctx: ModelContext) {
        machines.forEach  { ctx.delete($0) }
        routines.forEach  { ctx.delete($0) }
        muscleGroups.forEach { ctx.delete($0) }

        var newM: [Machine] = []
        for md in ml {
            let m = Machine(id: md.id, name: md.name, muscleGroup: md.muscleGroup,
                            imageFileName: md.imageFileName, notes: md.notes)
            for sd in md.sets { m.sets.append(ExerciseSet(id: sd.id, weight: sd.weight, reps: sd.reps, date: sd.date)) }
            ctx.insert(m); newM.append(m)
        }
        var newR: [Routine] = []
        for rd in rl { let r = Routine(id: rd.id, name: rd.name, machineIDs: rd.machineIDs); ctx.insert(r); newR.append(r) }

        var newG: [MuscleGroup] = []
        for (i, name) in gl.enumerated() { let g = MuscleGroup(name: name, sortIndex: i); ctx.insert(g); newG.append(g) }

        self.machines = newM; self.routines = newR; self.muscleGroups = newG

        for (f, d) in imgs { try? d.write(to: documentsURL.appendingPathComponent(f)); ImageCache.shared.remove(f) }
        ensureDefaultGroups(); calculateStats(); try? ctx.save()
    }

    // MARK: - Helpers

    private func saveContext() { try? modelContext?.save() }

    func fmt(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
    }
}
```

Add file to Xcode target.

- [ ] **Step 2: Build check** — `Cmd+B`. Fix any errors.

- [ ] **Step 3: Commit**

```bash
git add "Train with Me/TrainingService.swift"
git commit -m "feat: add TrainingService — extracts all training logic from FitnessViewModel"
```

---

## Task 5: HealthService

**Files:**
- Create: `Train with Me/HealthService.swift`

- [ ] **Step 1: Create `Train with Me/HealthService.swift`**

```swift
import HealthKit
import SwiftData

@Observable
final class HealthService {

    // MARK: - State (body measurement histories)
    var weightHistory:  [ChartDataPoint] = []
    var waistHistory:   [ChartDataPoint] = []
    var bodyFatHistory: [ChartDataPoint] = []
    var bicepsHistory:  [ChartDataPoint] = []
    var chestHistory:   [ChartDataPoint] = []
    var thighHistory:   [ChartDataPoint] = []
    var currentWeight:  Double = 0.0

    private let store = HKHealthStore()
    private var modelContext: ModelContext?

    // MARK: - Setup

    func configure(modelContext: ModelContext) {
        guard self.modelContext == nil else { return }
        self.modelContext = modelContext
        loadFromSwiftData()
    }

    private func loadFromSwiftData() {
        guard let ctx = modelContext else { return }
        let all = (try? ctx.fetch(FetchDescriptor<BodyMeasurement>(sortBy: [SortDescriptor(\.date)]))) ?? []
        weightHistory  = all.filter { $0.type == "weight"  }.map { ChartDataPoint(date: $0.date, value: $0.value) }
        waistHistory   = all.filter { $0.type == "waist"   }.map { ChartDataPoint(date: $0.date, value: $0.value) }
        bodyFatHistory = all.filter { $0.type == "bodyFat" }.map { ChartDataPoint(date: $0.date, value: $0.value) }
        bicepsHistory  = all.filter { $0.type == "biceps"  }.map { ChartDataPoint(date: $0.date, value: $0.value) }
        chestHistory   = all.filter { $0.type == "chest"   }.map { ChartDataPoint(date: $0.date, value: $0.value) }
        thighHistory   = all.filter { $0.type == "thigh"   }.map { ChartDataPoint(date: $0.date, value: $0.value) }
        currentWeight  = weightHistory.last?.value ?? 0.0
    }

    // MARK: - Authorization

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else { completion(false); return }
        let read: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .waistCircumference)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.workoutType()
        ]
        let write: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .waistCircumference)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKObjectType.workoutType()
        ]
        store.requestAuthorization(toShare: write, read: read) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }

    // MARK: - Add Measurement

    func addMeasurement(weight: Double?, waist: Double?, fat: Double?,
                        biceps: Double?, chest: Double?, thigh: Double?,
                        healthKitEnabled: Bool) {
        guard let ctx = modelContext else { return }
        let now = Date()
        func insert(_ type: String, _ value: Double, append list: inout [ChartDataPoint]) {
            ctx.insert(BodyMeasurement(date: now, type: type, value: value))
            list.append(ChartDataPoint(date: now, value: value))
        }
        if let w  = weight { insert("weight",  w,  append: &weightHistory);  currentWeight = w
            if healthKitEnabled { saveQuantity(typeIdentifier: .bodyMass, value: w, unit: .gramUnit(with: .kilo)) }
        }
        if let wa = waist  { insert("waist",   wa, append: &waistHistory)
            if healthKitEnabled { saveQuantity(typeIdentifier: .waistCircumference, value: wa, unit: .meterUnit(with: .centi)) }
        }
        if let f  = fat    { insert("bodyFat", f,  append: &bodyFatHistory)
            if healthKitEnabled { saveQuantity(typeIdentifier: .bodyFatPercentage, value: f / 100, unit: .percent()) }
        }
        if let b  = biceps { insert("biceps",  b,  append: &bicepsHistory) }
        if let c  = chest  { insert("chest",   c,  append: &chestHistory) }
        if let t  = thigh  { insert("thigh",   t,  append: &thighHistory) }
        try? ctx.save()
    }

    // MARK: - HealthKit Read

    func fetchLatestWeight(completion: @escaping (Double?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { completion(nil); return }
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, _ in
            DispatchQueue.main.async {
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .gramUnit(with: .kilo))
                completion(value)
            }
        }
        store.execute(query)
    }

    func fetchHistory(for typeIdentifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping ([ChartDataPoint]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else { completion([]); return }
        let anchor = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let pred   = HKQuery.predicateForSamples(withStart: anchor, end: Date(), options: .strictStartDate)
        let query  = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit,
                                   sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
            let points = (samples as? [HKQuantitySample] ?? []).map {
                ChartDataPoint(date: $0.startDate, value: $0.quantity.doubleValue(for: unit))
            }
            DispatchQueue.main.async { completion(points) }
        }
        store.execute(query)
    }

    func fetchCardioWorkouts(completion: @escaping ([HKWorkout]) -> Void) {
        let pred  = HKQuery.predicateForWorkouts(with: .other)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: nil, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, _ in
            DispatchQueue.main.async { completion(samples as? [HKWorkout] ?? []) }
        }
        store.execute(query)
    }

    // MARK: - HealthKit Write

    func saveWorkout(startDate: Date, endDate: Date, totalVolume: Double) {
        let workout = HKWorkout(activityType: .traditionalStrengthTraining, start: startDate, end: endDate)
        store.save(workout) { _, _ in }
    }

    func saveQuantity(typeIdentifier: HKQuantityTypeIdentifier, value: Double, unit: HKUnit) {
        guard let type = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else { return }
        let sample = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: value),
                                      start: Date(), end: Date())
        store.save(sample) { _, _ in }
    }

    func saveBloodPressure(systolic: Double, diastolic: Double) {
        guard let sType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let dType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic),
              let bpType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure) else { return }
        let s = HKQuantitySample(type: sType, quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: systolic),  start: Date(), end: Date())
        let d = HKQuantitySample(type: dType, quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: diastolic), start: Date(), end: Date())
        let bp = HKCorrelation(type: bpType, start: Date(), end: Date(), objects: [s, d])
        store.save(bp) { _, _ in }
    }

    func activityName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:           return "Laufen"
        case .cycling:           return "Radfahren"
        case .swimming:          return "Schwimmen"
        case .rowing:            return "Rudern"
        case .elliptical:        return "Ellipsentrainer"
        case .walking:           return "Gehen"
        case .hiking:            return "Wandern"
        case .stairClimbing:     return "Treppensteigen"
        case .jumpRope:          return "Seilspringen"
        default:                 return "Cardio"
        }
    }

    func refreshFromHealthKit() {
        fetchHistory(for: .bodyMass,          unit: .gramUnit(with: .kilo))   { [weak self] p in self?.weightHistory  = p; self?.currentWeight = p.last?.value ?? self?.currentWeight ?? 0 }
        fetchHistory(for: .waistCircumference, unit: .meterUnit(with: .centi)) { [weak self] p in self?.waistHistory   = p }
        fetchHistory(for: .bodyFatPercentage,  unit: .percent())               { [weak self] p in self?.bodyFatHistory = p.map { ChartDataPoint(id: $0.id, date: $0.date, value: $0.value * 100) } }
    }
}
```

Add file to Xcode target.

- [ ] **Step 2: Build check** — `Cmd+B`.

- [ ] **Step 3: Commit**

```bash
git add "Train with Me/HealthService.swift"
git commit -m "feat: add HealthService — replaces HealthManager, reads body data from SwiftData"
```

---

## Task 6: GeminiService

**Files:**
- Create: `Train with Me/GeminiService.swift`

- [ ] **Step 1: Create `Train with Me/GeminiService.swift`**

```swift
import GoogleGenerativeAI

@Observable
final class GeminiService {

    var isLoading = false
    var lastResponse = "Tippe auf 'Analysieren', um Feedback zu erhalten."

    // MARK: - Public API

    func analyzeBodyStats(
        weightHistory: [ChartDataPoint], waistHistory: [ChartDataPoint],
        bodyFatHistory: [ChartDataPoint], systolic: Double, diastolic: Double,
        machines: [Machine]
    ) async {
        guard !isLoading else { return }
        isLoading = true; lastResponse = ""
        var prompt = "Du bist ein Fitness-Coach. Analysiere diese Daten kurz auf Deutsch (6-8 Sätze):\n\n"
        if let w  = weightHistory.last?.value  { prompt += "- Gewicht: \(String(format: "%.1f", w)) kg\n" }
        if let wa = waistHistory.last?.value   { prompt += "- Bauch: \(String(format: "%.1f", wa)) cm\n" }
        if let f  = bodyFatHistory.last?.value { prompt += "- Körperfett: \(String(format: "%.1f", f)) %\n" }
        if systolic > 0 { prompt += "- Blutdruck: \(Int(systolic))/\(Int(diastolic)) mmHg\n" }
        prompt += "\nTraining (30 Tage):\n" + buildTrainingContext(machines: machines, days: 30)
        lastResponse = await call(prompt: prompt)
        isLoading = false
    }

    func analyzeWorkout(
        todaysSets: [(machine: Machine, sets: [ExerciseSet])],
        allMachines: [Machine]
    ) async -> String {
        let cal         = Calendar.current
        let today       = Date()
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: today))!
        var prompt = buildWorkoutPrompt(todaysSets: todaysSets, today: today, sevenDaysAgo: sevenDaysAgo, allMachines: allMachines)
        let intensityCtx = buildIntensityContext(machines: allMachines, days: 28)
        if !intensityCtx.isEmpty { prompt += "\n\nINTENSITÄT (letzte 4 Wochen, RPE/RIR):\n\(intensityCtx)" }
        return await call(prompt: prompt)
    }

    // MARK: - Prompt Builders

    private func buildTrainingContext(machines: [Machine], days: Int) -> String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        var ctx = ""
        for m in machines {
            let recent = m.sets.filter { $0.date > cutoff }; guard !recent.isEmpty else { continue }
            if m.muscleGroup.lowercased() == "cardio" {
                let min = recent.compactMap { $0.duration ?? Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.reduce(0, +)
                ctx += "- \(m.name): \(String(format: "%.0f", min)) min\n"
            } else {
                let maxW = recent.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.max() ?? 0
                let reps = recent.compactMap { Int($0.reps) }.reduce(0, +)
                ctx += "- \(m.name) (\(m.muscleGroup)): Max \(fmt(maxW)) kg, \(reps) Wdh\n"
            }
        }
        return ctx.isEmpty ? "Keine Daten." : ctx
    }

    private func buildWorkoutPrompt(todaysSets: [(machine: Machine, sets: [ExerciseSet])],
                                    today: Date, sevenDaysAgo: Date, allMachines: [Machine]) -> String {
        let df = DateFormatter(); df.dateFormat = "dd.MM.yyyy"
        var p = "Du bist Fitness-Coach. Analysiere das heutige Training vs. letzte 7 Tage. Strukturiere in: 1.💪 Heute 2.📈 Vergleich 3.🎯 Empfehlung.\n\nHEUTE (\(df.string(from: today))):\n"
        for item in todaysSets {
            let maxW = item.sets.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.max() ?? 0
            let vol  = item.sets.reduce(0) { $0 + $1.volume }
            p += "- \(item.machine.name): Max \(fmt(maxW)) kg, Vol \(Int(vol)) kg\n"
        }
        p += "\nVORWOCHE:\n"
        let cal = Calendar.current
        for machine in allMachines where todaysSets.map({ $0.machine.id }).contains(machine.id) {
            let prev = machine.sets.filter { $0.date >= sevenDaysAgo && !cal.isDateInToday($0.date) }
            guard !prev.isEmpty else { continue }
            let maxW = prev.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.max() ?? 0
            p += "- \(machine.name): Max \(fmt(maxW)) kg\n"
        }
        return p
    }

    private func buildIntensityContext(machines: [Machine], days: Int) -> String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        var lines: [String] = []
        for m in machines {
            let rpes = m.sets.filter { $0.date > cutoff }.compactMap { $0.rpe }
            guard !rpes.isEmpty else { continue }
            let avgRPE = Double(rpes.reduce(0, +)) / Double(rpes.count)
            let rirs   = m.sets.filter { $0.date > cutoff }.compactMap { $0.rir }
            var line   = "- \(m.name) (\(m.muscleGroup)): Ø RPE \(String(format: "%.1f", avgRPE))/10"
            if !rirs.isEmpty { line += ", Ø RIR \(String(format: "%.1f", Double(rirs.reduce(0,+)) / Double(rirs.count)))" }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - API Call

    private func call(prompt: String) async -> String {
        let key = Secrets.geminiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.contains("YOUR_") else { return "Kein gültiger API Key." }
        do {
            let r = try await GenerativeModel(name: "gemini-2.5-flash", apiKey: key).generateContent(prompt)
            return r.text ?? "Keine Antwort."
        } catch {
            let d = error.localizedDescription.lowercased()
            if d.contains("quota") || d.contains("rate") { return "API-Limit erreicht. Kurz warten." }
            if d.contains("network")                     { return "Keine Internetverbindung." }
            return "KI-Fehler: \(error.localizedDescription)"
        }
    }

    private func fmt(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
    }
}
```

Add file to Xcode target.

- [ ] **Step 2: Build check** — `Cmd+B`.

- [ ] **Step 3: Commit**

```bash
git add "Train with Me/GeminiService.swift"
git commit -m "feat: add GeminiService — isolates AI prompt building and API calls"
```

---

## Task 7: WatchService

**Files:**
- Create: `Train with Me/WatchService.swift`

- [ ] **Step 1: Create `Train with Me/WatchService.swift`**

```swift
import WatchConnectivity

/// NSObject subclass required for WCSessionDelegate conformance.
/// @Observable tracks incomingSet so AppViewModel can react to it.
@Observable
final class WatchService: NSObject, WCSessionDelegate {

    /// Set by session(_:didReceiveUserInfo:) when the Watch logs a set.
    /// AppViewModel observes this and calls TrainingService.addSet.
    var incomingSet: (machineName: String, weight: String, reps: String)? = nil

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func sync(machines: [[String: Any]], muscleGroups: [String]) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext([
            "muscleGroups": muscleGroups,
            "machines":     machines
        ])
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Sync happens after AppViewModel is configured
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let action     = userInfo["action"]      as? String, action == "addSet",
              let machineName = userInfo["machineName"] as? String,
              let weight      = userInfo["weight"]      as? String,
              let reps        = userInfo["reps"]        as? String else { return }
        DispatchQueue.main.async {
            self.incomingSet = (machineName, weight, reps)
        }
    }
}
```

Add file to Xcode target.

- [ ] **Step 2: Build check** — `Cmd+B`.

- [ ] **Step 3: Commit**

```bash
git add "Train with Me/WatchService.swift"
git commit -m "feat: add WatchService — wraps WCSession delegate"
```

---

## Task 8: BackupService

**Files:**
- Create: `Train with Me/BackupService.swift`

- [ ] **Step 1: Create `Train with Me/BackupService.swift`**

```swift
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
                machines:       training.machines.map { m in
                    MachineData(id: m.id, name: m.name, muscleGroup: m.muscleGroup,
                                imageFileName: m.imageFileName, notes: m.notes,
                                sets: m.sets.map { ExerciseSetData(id: $0.id, weight: $0.weight, reps: $0.reps, date: $0.date) })
                },
                muscleGroups: training.muscleGroupNames(),
                routines:     training.routines.map { RoutineData(id: $0.id, name: $0.name, machineIDs: $0.machineIDs) },
                weightHistory: health.weightHistory, waistHistory:  health.waistHistory,
                bodyFatHistory: health.bodyFatHistory, bicepsHistory: health.bicepsHistory,
                chestHistory:  health.chestHistory,   thighHistory:  health.thighHistory,
                imagesData:    imgs
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

    func restoreBackup(from url: URL, training: TrainingService, health: HealthService,
                       modelContext: Any, healthKitEnabled: Bool) {
        // modelContext typed as Any to avoid SwiftData import cycle; cast at call site
        // This method is called with the actual ModelContext from SettingsView
    }

    func restoreBackupData(_ data: Data, training: TrainingService, health: HealthService,
                           ctx: SwiftData.ModelContext, healthKitEnabled: Bool) {
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
                                  ctx: SwiftData.ModelContext, healthKitEnabled: Bool) {
        let existing = (try? ctx.fetch(FetchDescriptor<BodyMeasurement>())) ?? []
        existing.forEach { ctx.delete($0) }

        func insert(_ type: String, _ points: [ChartDataPoint]?) {
            for p in (points ?? []) { ctx.insert(BodyMeasurement(date: p.date, type: type, value: p.value)) }
        }
        insert("weight",  b.weightHistory);  insert("waist",   b.waistHistory)
        insert("bodyFat", b.bodyFatHistory); insert("biceps",  b.bicepsHistory)
        insert("chest",   b.chestHistory);   insert("thigh",   b.thighHistory)
        try? ctx.save()
        health.configure(modelContext: ctx)   // reload
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

    // MARK: - Cardio Import

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
                    training.modelContext?.insert(m); training.machines.append(m); count += 1
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
```

**Note:** `training.modelContext` is `private` in TrainingService — add `var modelContext: ModelContext?` with `internal` access (remove `private`) or add a helper method `insertMachine(_ machine: Machine)` to TrainingService:

```swift
// Add to TrainingService:
func insertMachine(_ machine: Machine) {
    guard let ctx = modelContext else { return }
    ctx.insert(machine); machines.append(machine)
}
```

Then replace `training.modelContext?.insert(m); training.machines.append(m)` in BackupService with `training.insertMachine(m)`.

Add file to Xcode target.

- [ ] **Step 2: Build check** — `Cmd+B`.

- [ ] **Step 3: Commit**

```bash
git add "Train with Me/BackupService.swift" "Train with Me/TrainingService.swift"
git commit -m "feat: add BackupService; add insertMachine helper to TrainingService"
```

---

## Task 9: AppViewModel

**Files:**
- Create: `Train with Me/AppViewModel.swift`

- [ ] **Step 1: Create `Train with Me/AppViewModel.swift`**

```swift
import SwiftUI
import SwiftData
import ActivityKit

@Observable
final class AppViewModel {

    // MARK: - Services
    let training = TrainingService()
    let health   = HealthService()
    let gemini   = GeminiService()
    let watch    = WatchService()
    let backup   = BackupService()

    // MARK: - Workout Session State
    var isWorkoutActive  = false
    var workoutStartDate: Date? = nil
    var sessionSummaryMessage: String? = nil
    var shareImage: UIImage? = nil
    var workoutAnalysis  = ""
    var isAnalyzingWorkout = false

    // MARK: - UI Feedback
    var errorMessage: String? = nil
    var newlyUnlockedAchievement: Achievement? = nil

    // MARK: - Blood Pressure (preferences, not body model data)
    var latestSystolic:  Double = UserDefaults.standard.double(forKey: "latestSystolic")  { didSet { UserDefaults.standard.set(latestSystolic,  forKey: "latestSystolic") } }
    var latestDiastolic: Double = UserDefaults.standard.double(forKey: "latestDiastolic") { didSet { UserDefaults.standard.set(latestDiastolic, forKey: "latestDiastolic") } }

    // MARK: - Preferences (UserDefaults-backed)
    var timerEnabled:         Bool    = UserDefaults.standard.bool(forKey: "TimerEnabled") { didSet { UserDefaults.standard.set(timerEnabled,         forKey: "TimerEnabled") } }
    var timerDuration:        Double  = { let v = UserDefaults.standard.double(forKey: "TimerDuration"); return v == 0 ? 90 : v }() { didSet { UserDefaults.standard.set(timerDuration,  forKey: "TimerDuration") } }
    var healthKitEnabled:     Bool    = UserDefaults.standard.bool(forKey: "HealthKitEnabled")     { didSet { UserDefaults.standard.set(healthKitEnabled,     forKey: "HealthKitEnabled") } }
    var bodyStatsEnabled:     Bool    = UserDefaults.standard.bool(forKey: "BodyStatsEnabled")     { didSet { UserDefaults.standard.set(bodyStatsEnabled,     forKey: "BodyStatsEnabled") } }
    var bloodPressureEnabled: Bool    = UserDefaults.standard.bool(forKey: "BloodPressureEnabled") { didSet { UserDefaults.standard.set(bloodPressureEnabled, forKey: "BloodPressureEnabled") } }
    var currentTheme:         AppTheme = {
        if let d = UserDefaults.standard.data(forKey: "AppTheme"),
           let v = try? JSONDecoder().decode(AppTheme.self, from: d) { return v }
        return .midnight
    }() { didSet { if let d = try? JSONEncoder().encode(currentTheme) { UserDefaults.standard.set(d, forKey: "AppTheme") } } }

    // MARK: - Setup

    func configure(modelContext: ModelContext) {
        training.configure(modelContext: modelContext)
        health.configure(modelContext: modelContext)
        NotificationManager.shared.requestPermission()
        if healthKitEnabled || bodyStatsEnabled {
            Task { @MainActor in
                health.fetchLatestWeight { [weak self] w in
                    if let v = w { self?.health.currentWeight = v }
                }
            }
        }
        // React to incoming Watch sets
        // Observation happens in views via withObservationTracking or onChange
    }

    // MARK: - Workout

    func startWorkout() {
        isWorkoutActive = true
        workoutStartDate = Date()
    }

    func finishWorkout() {
        let end = Date()
        var vol = 0.0; var muscles: Set<String> = []; var todayData: [(machine: Machine, sets: [ExerciseSet])] = []
        for m in training.machines {
            let s = m.sets.filter { Calendar.current.isDate($0.date, inSameDayAs: end) }
            if !s.isEmpty { muscles.insert(m.muscleGroup); vol += s.reduce(0) { $0 + $1.volume }; todayData.append((m, s)) }
        }
        if vol > 0 {
            sessionSummaryMessage = "Starkes Training! 💪\n\nDu hast heute \(Int(vol)) kg bewegt.\nTrainierte Gruppen: \(muscles.joined(separator: ", "))"
            let r = ImageRenderer(content: ShareView(volume: Int(vol), muscles: muscles.joined(separator: ", ")))
            r.scale = 3.0; shareImage = r.uiImage
            if healthKitEnabled, let start = workoutStartDate {
                health.saveWorkout(startDate: start, endDate: end, totalVolume: vol)
            }
            if !todayData.isEmpty {
                Task { await analyzeCompletedWorkout(todaysSets: todayData) }
            }
        } else {
            sessionSummaryMessage = "Keine Sätze für heute."
        }
        isWorkoutActive = false; workoutStartDate = nil
        training.calculateStats()
        if let a = training.checkNewAchievements() {
            newlyUnlockedAchievement = a
        }
    }

    private func analyzeCompletedWorkout(todaysSets: [(machine: Machine, sets: [ExerciseSet])]) async {
        guard !gemini.isLoading else { return }
        isAnalyzingWorkout = true; workoutAnalysis = ""
        workoutAnalysis = await gemini.analyzeWorkout(todaysSets: todaysSets, allMachines: training.machines)
        isAnalyzingWorkout = false
    }

    // MARK: - Watch Sync

    func syncMachinesToWatch() {
        watch.sync(machines: training.machinesForWatch(), muscleGroups: training.muscleGroupNames())
    }

    func handleIncomingWatchSet(machineName: String, weight: String, reps: String) {
        guard let m = training.machines.first(where: { $0.name == machineName }) else { return }
        training.addSet(machineId: m.id, weight: weight, reps: reps)
    }

    // MARK: - Blood Pressure

    func saveBloodPressure(systolic: Double, diastolic: Double) {
        latestSystolic = systolic; latestDiastolic = diastolic
        if healthKitEnabled { health.saveBloodPressure(systolic: systolic, diastolic: diastolic) }
    }
}
```

Add file to Xcode target.

- [ ] **Step 2: Build check** — `Cmd+B`.

- [ ] **Step 3: Commit**

```bash
git add "Train with Me/AppViewModel.swift"
git commit -m "feat: add slim AppViewModel — coordinates services, owns UI state"
```

---

## Task 10: App Entry Point

**Files:**
- Modify: `Train with Me/Train_with_MeApp.swift`

- [ ] **Step 1: Read current content**

```bash
cat "Train with Me/Train_with_MeApp.swift"
```

- [ ] **Step 2: Replace with wired-up version**

```swift
import SwiftUI
import SwiftData

@main
struct Train_with_MeApp: App {
    @State private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appViewModel)
                .modelContainer(for: [Machine.self, Routine.self, BodyMeasurement.self, MuscleGroup.self])
                .onAppear {
                    // Migration runs on first launch after update
                }
        }
    }
}
```

**Note:** The `modelContainer` modifier provides the `ModelContext` to the environment; `ContentView` reads it via `@Environment(\.modelContext)` and passes it to `appViewModel.configure(...)` in `onAppear`.

- [ ] **Step 3: Build check** — `Cmd+B`.

- [ ] **Step 4: Commit**

```bash
git add "Train with Me/Train_with_MeApp.swift"
git commit -m "feat: wire app entry point — inject AppViewModel, modelContainer with new models"
```

---

## Task 11: Update ContentView

**Files:**
- Modify: `Train with Me/ContentView.swift`

Replace the entire file. Key changes: `@StateObject var viewModel: FitnessViewModel` → `@Environment(AppViewModel.self) var viewModel`; all property accesses namespaced through services (`viewModel.training.*`, `viewModel.health.*`); `configure(modelContext:)` called in `onAppear`; `MigrationService.runIfNeeded(context:)` called before configure.

- [ ] **Step 1: Replace `ContentView.swift`**

```swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppViewModel.self) var viewModel
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddGroupAlert  = false
    @State private var newGroupName          = ""
    @State private var showingHistory        = false
    @State private var showingSettings       = false
    @State private var showEndWorkoutAlert   = false
    @State private var showingBodyStats      = false
    @State private var showingCreateRoutine  = false
    @State private var showingSmartStats     = false
    @State private var showingHeatmap        = false
    @State private var showingPRDashboard    = false
    @State private var showingCalendar       = false
    @State private var showingGamification   = false
    @State private var groupToRename: String? = nil
    @State private var newRenameName         = ""
    @State private var streakMilestone: String? = nil

    init() {
        let a = UINavigationBarAppearance()
        a.configureWithTransparentBackground()
        a.titleTextAttributes      = [.foregroundColor: UIColor.white]
        a.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance   = a
        UINavigationBar.appearance().compactAppearance    = a
        UINavigationBar.appearance().scrollEdgeAppearance = a
    }

    var body: some View {
        NavigationView {
            ZStack {
                viewModel.currentTheme.backgroundView
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        recoverySection
                        trainingIntelligenceSection
                        workoutButtonSection
                        routinesSection
                        librarySection
                    }.padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingHistory)       { HistoryView(viewModel: viewModel) }
            .sheet(isPresented: $showingSettings)      { SettingsView(viewModel: viewModel) }
            .sheet(isPresented: $showingBodyStats)     { BodyStatsView(viewModel: viewModel) }
            .sheet(isPresented: $showingCreateRoutine) { CreateRoutineView(viewModel: viewModel) }
            .sheet(isPresented: $showingSmartStats)    { SmartStatsView(viewModel: viewModel) }
            .sheet(isPresented: $showingHeatmap)       { MuscleHeatmapView(viewModel: viewModel) }
            .sheet(isPresented: $showEndWorkoutAlert)  { EndWorkoutSheet(viewModel: viewModel, isPresented: $showEndWorkoutAlert) }
            .sheet(isPresented: $showingPRDashboard)   { PRDashboardView(viewModel: viewModel) }
            .sheet(isPresented: $showingCalendar)      { WorkoutCalendarView(viewModel: viewModel) }
            .sheet(isPresented: $showingGamification)  { NavigationView { GamificationView(viewModel: viewModel) } }
            .alert("Neue Kategorie", isPresented: $showingAddGroupAlert) {
                TextField("Name", text: $newGroupName)
                Button("Hinzufügen") { if !newGroupName.isEmpty { viewModel.training.addMuscleGroup(name: newGroupName); newGroupName = "" } }
                Button("Abbrechen", role: .cancel) { }
            }
            .alert("Kategorie umbenennen", isPresented: Binding(get: { groupToRename != nil }, set: { if !$0 { groupToRename = nil } })) {
                TextField("Neuer Name", text: $newRenameName)
                Button("Speichern") { if let old = groupToRename, !newRenameName.isEmpty { viewModel.training.renameMuscleGroup(oldName: old, newName: newRenameName) }; groupToRename = nil }
                Button("Abbrechen", role: .cancel) { groupToRename = nil }
            }
            .alert("Fehler", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: { Text(viewModel.errorMessage ?? "") }
            .alert(streakMilestone ?? "", isPresented: Binding(get: { streakMilestone != nil }, set: { if !$0 { streakMilestone = nil } })) {
                Button("💪 Los geht's!") { streakMilestone = nil }
            }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) {
            if let achievement = viewModel.newlyUnlockedAchievement {
                AchievementUnlockedBanner(achievement: achievement)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                            withAnimation { viewModel.newlyUnlockedAchievement = nil }
                        }
                    }
            }
        }
        .onAppear {
            MigrationService.runIfNeeded(context: modelContext)
            viewModel.configure(modelContext: modelContext)
            streakMilestone = viewModel.training.streakMilestoneMessage
        }
        .onChange(of: viewModel.watch.incomingSet) { _, incoming in
            guard let s = incoming else { return }
            viewModel.handleIncomingWatchSet(machineName: s.machineName, weight: s.weight, reps: s.reps)
            viewModel.watch.incomingSet = nil
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dashboard").font(.largeTitle.bold()).foregroundColor(.white)
                    if viewModel.training.currentStreak > 0 {
                        HStack(spacing: 5) {
                            Text("🔥").font(.caption)
                            Text("\(viewModel.training.currentStreak) Tage Streak")
                                .font(.caption.bold()).foregroundColor(.orange)
                        }
                    }
                }
                Spacer()
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.white).padding(10)
                        .background(.ultraThinMaterial).clipShape(Circle())
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    headerButton("medal.fill",           action: { showingGamification = true })
                    headerButton("calendar.badge.clock", action: { showingCalendar = true })
                    headerButton("trophy.fill",          action: { showingPRDashboard = true })
                    headerButton("flame.fill",           action: { showingHeatmap = true })
                    headerButton("sparkles",             action: { showingSmartStats = true })
                    if viewModel.bodyStatsEnabled {
                        headerButton("figure.arms.open", action: { showingBodyStats = true })
                    }
                    headerButton("calendar",             action: { showingHistory = true })
                }
            }
        }.padding(.horizontal)
    }

    private func headerButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.body).foregroundColor(.white)
                .padding(11).background(.ultraThinMaterial).clipShape(Circle())
        }
    }

    // MARK: - Recovery

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Erholung").font(.title3.bold()).foregroundColor(.white)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.training.muscleGroups, id: \.id) { group in
                        let status = viewModel.training.recoveryStatus(for: group.name)
                        VStack(spacing: 5) {
                            Text(status.emoji).font(.title2)
                            Text(group.name).font(.caption2.bold()).foregroundColor(.white).lineLimit(1)
                            Text(status.label).font(.caption2).foregroundColor(status.color)
                        }
                        .frame(width: 76, height: 76)
                        .background(status.color.opacity(0.12)).cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(status.color.opacity(0.4), lineWidth: 1))
                    }
                }
            }
        }.padding(.horizontal)
    }

    // MARK: - Training Intelligence

    private var trainingIntelligenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Insights").font(.title3.bold()).foregroundColor(.white)
            if viewModel.training.shouldSuggestDeload {
                InsightBanner(emoji: "😴", title: "Deload empfohlen",
                    message: "Du trainierst seit 2 Wochen sehr intensiv (Ø RPE ≥ 8). Eine leichtere Woche fördert die Regeneration.",
                    color: .orange)
            }
            if viewModel.training.periodizationPhase != .noData {
                InsightBanner(emoji: viewModel.training.periodizationPhase.emoji,
                    title: "Aktuelle Phase: \(viewModel.training.periodizationPhase.title)",
                    message: viewModel.training.periodizationPhase.description,
                    footer: viewModel.training.periodizationPhase.suggestion,
                    color: viewModel.currentTheme.accentColor)
            }
            VolumeCheckView(viewModel: viewModel)
        }.padding(.horizontal)
    }

    // MARK: - Workout Button

    private var workoutButtonSection: some View {
        Group {
            if !viewModel.isWorkoutActive {
                Button(action: { withAnimation { viewModel.startWorkout() } }) {
                    HStack(spacing: 10) { Image(systemName: "play.fill"); Text("Training starten") }
                        .font(.title3.bold()).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(20).shadow(color: .green.opacity(0.4), radius: 12, x: 0, y: 6)
                }.padding(.horizontal)
            } else {
                Button(action: { viewModel.finishWorkout(); showEndWorkoutAlert = true }) {
                    HStack(spacing: 10) { Image(systemName: "stop.fill"); Text("Training beenden") }
                        .font(.title3.bold()).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(20).shadow(color: .red.opacity(0.4), radius: 12, x: 0, y: 6)
                }.padding(.horizontal)
            }
        }
    }

    // MARK: - Routines

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Meine Pläne", action: { showingCreateRoutine = true })
            if viewModel.training.routines.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: "list.bullet.clipboard").font(.title2).foregroundColor(.gray)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kein Plan vorhanden").font(.subheadline.bold()).foregroundColor(.white)
                        Text("Erstelle deinen ersten Trainingsplan").font(.caption).foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05)).cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.training.routines) { routine in
                            NavigationLink(destination: RoutineDetailView(viewModel: viewModel, routine: routine)) {
                                VStack(spacing: 8) {
                                    Image(systemName: "list.bullet.clipboard").font(.largeTitle)
                                        .foregroundColor(viewModel.currentTheme.accentColor)
                                    Text(routine.name).font(.subheadline.bold()).foregroundColor(.white)
                                        .multilineTextAlignment(.center).lineLimit(2)
                                }.frame(width: 130, height: 110).glassStyle()
                            }
                            .contextMenu {
                                Button("Löschen", role: .destructive) {
                                    if let idx = viewModel.training.routines.firstIndex(where: { $0.id == routine.id }) {
                                        viewModel.training.deleteRoutine(at: IndexSet(integer: idx))
                                    }
                                }
                            }
                        }
                    }.padding(.vertical, 4)
                }
            }
        }.padding(.horizontal)
    }

    // MARK: - Library

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Bibliothek", action: { showingAddGroupAlert = true })
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(viewModel.training.muscleGroups, id: \.id) { group in
                    NavigationLink(destination: MachineListView(viewModel: viewModel, muscle: group.name)) {
                        HStack(spacing: 12) {
                            Image(systemName: iconFor(group.name)).font(.title3)
                                .foregroundColor(viewModel.currentTheme.accentColor).frame(width: 28)
                            Text(group.name).font(.subheadline.bold()).foregroundColor(.white)
                            Spacer()
                            Circle().fill(viewModel.training.recoveryStatus(for: group.name).color)
                                .frame(width: 9, height: 9)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 16).glassStyle()
                    }
                    .contextMenu {
                        Button("Umbenennen") { groupToRename = group.name; newRenameName = group.name }
                        Button("Löschen", role: .destructive) { viewModel.training.deleteMuscleGroup(name: group.name) }
                    }
                }
            }
        }.padding(.horizontal)
    }

    func iconFor(_ muscle: String) -> String {
        switch muscle.lowercased() {
        case "brust": return "shield.fill"; case "rücken": return "figure.rower"
        case "beine": return "figure.run";  case "arme":   return "dumbbell.fill"
        case "bauch": return "circle.grid.2x2.fill"; case "schultern": return "figure.arms.open"
        case "cardio": return "heart.fill"; default: return "star.fill"
        }
    }
}

// MARK: - VolumeCheckView (no change in logic, updated property access)

struct VolumeCheckView: View {
    var viewModel: AppViewModel
    var volumeGroups: [MuscleGroup] { viewModel.training.muscleGroups.filter { $0.name.lowercased() != "cardio" } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Volumen diese Woche").font(.subheadline.bold()).foregroundColor(.white)
                Spacer()
                Text("Ziel: 10–20 Sätze").font(.caption2).foregroundColor(.white.opacity(0.4))
            }
            ForEach(volumeGroups, id: \.id) { group in
                VolumeRow(group: group.name,
                          sets: viewModel.training.weeklySets(for: group.name),
                          status: viewModel.training.volumeStatus(for: group.name))
            }
            HStack(spacing: 14) {
                legendDot(.red, "Zu wenig"); legendDot(.orange, "Minimal")
                legendDot(.green, "Optimal"); legendDot(.blue, "Viel")
            }.padding(.top, 2)
        }
        .padding(14).background(Color.white.opacity(0.05)).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) { Circle().fill(color).frame(width: 6, height: 6); Text(label).font(.caption2).foregroundColor(.white.opacity(0.4)) }
    }
}

// MARK: - EndWorkoutSheet (updated property access)

struct EndWorkoutSheet: View {
    var viewModel: AppViewModel
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Training beendet!").font(.largeTitle.bold()).foregroundColor(.white)
                        Text(viewModel.sessionSummaryMessage ?? "").foregroundColor(.white.opacity(0.6)).multilineTextAlignment(.center)
                    }.padding(.top, 24)
                    if let img = viewModel.shareImage {
                        VStack(spacing: 12) {
                            Image(uiImage: img).resizable().scaledToFit().frame(height: 260).cornerRadius(16).shadow(radius: 10)
                            ShareLink(item: Image(uiImage: img), preview: SharePreview("Training", image: Image(uiImage: img))) {
                                Label("Teilen", systemImage: "square.and.arrow.up").font(.headline).foregroundColor(.white)
                                    .frame(maxWidth: .infinity).padding().background(Color.blue.opacity(0.8)).cornerRadius(16)
                            }
                        }.padding().glassStyle()
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sparkles").foregroundColor(viewModel.currentTheme.accentColor)
                            Text("KI Trainingsanalyse").font(.headline).foregroundColor(.white)
                            Spacer()
                        }
                        if viewModel.isAnalyzingWorkout {
                            HStack(spacing: 12) {
                                ProgressView().tint(.white)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Analysiere...").foregroundColor(.white).font(.subheadline)
                                    Text("Vergleiche mit letzten 7 Tagen").foregroundColor(.white.opacity(0.6)).font(.caption)
                                }
                            }.padding(.vertical, 8)
                        } else if viewModel.workoutAnalysis.isEmpty {
                            Text("Keine Daten für eine Analyse.").foregroundColor(.white.opacity(0.6)).font(.subheadline)
                        } else {
                            Text(viewModel.workoutAnalysis).foregroundColor(.white.opacity(0.6)).font(.subheadline).lineSpacing(5)
                        }
                    }.padding().glassStyle()
                    Button(action: { isPresented = false }) {
                        Text("Schließen").foregroundColor(.white.opacity(0.4)).font(.subheadline).padding(.bottom, 20)
                    }
                }.padding(.horizontal)
            }
        }
    }
}
```

- [ ] **Step 2: Build check** — `Cmd+B`. Fix any errors.

- [ ] **Step 3: Commit**

```bash
git add "Train with Me/ContentView.swift"
git commit -m "refactor: update ContentView to use AppViewModel + services"
```

---

## Task 12: Update TrainingView

**Files:**
- Modify: `Train with Me/TrainingView.swift`

The only change is the type of `viewModel` parameter: `FitnessViewModel` → `AppViewModel`, and all service calls namespaced accordingly.

- [ ] **Step 1: Replace view model type and update service calls**

Change the struct declaration and all service access:

```swift
// Line 6 — change type:
struct TrainingView: View {
    var viewModel: AppViewModel      // was: @ObservedObject var viewModel: FitnessViewModel
    let machine: Machine
    // ... rest unchanged
```

Update all viewModel calls in the file:

| Old | New |
|-----|-----|
| `viewModel.machines` | `viewModel.training.machines` |
| `viewModel.progressiveOverloadSuggestion(for:)` | `viewModel.training.progressiveOverloadSuggestion(for:)` |
| `viewModel.timerEnabled` | `viewModel.timerEnabled` |
| `viewModel.timerDuration` | `viewModel.timerDuration` |
| `viewModel.isWorkoutActive` | `viewModel.isWorkoutActive` |
| `viewModel.startWorkout()` | `viewModel.startWorkout()` |
| `viewModel.addSet(machineId:weight:reps:)` | `viewModel.training.addSet(machineId:weight:reps:)` |
| `viewModel.deleteSet(machineId:setId:)` | `viewModel.training.deleteSet(machineId:setId:)` |
| `viewModel.updateMachineNotes(machineId:notes:)` | `viewModel.training.updateMachineNotes(machineId:notes:)` |
| `viewModel.renameMachine(machineId:newName:)` | `viewModel.training.renameMachine(machineId:newName:)` |
| `viewModel.updateMachineImage(machineId:newImage:)` | `viewModel.training.updateMachineImage(machineId:newImage:)` |
| `viewModel.averageIntensity(for:)` | `viewModel.training.averageIntensity(for:)` |
| `viewModel.updateSetIntensity(machineId:setId:rpe:rir:)` | `viewModel.training.updateSetIntensity(machineId:setId:rpe:rir:)` |
| `viewModel.currentTheme` | `viewModel.currentTheme` |

Also update the cardio display logic to prefer `duration`/`calories` when available:

```swift
// In the set list ForEach, replace the cardio display:
if isCardio {
    let displayMin  = set.duration.map { String(format: "%.1f", $0) } ?? set.weight
    let displayKcal = set.calories.map { String(format: "%.0f", $0) } ?? set.reps
    Text("\(displayMin) min").bold()
    Text("| \(displayKcal) Kcal").bold()
} else {
    Text("\(set.weight) kg").bold()
    Text("x \(set.reps)").bold()
}
```

Also update the cardio input action in `addSetAction()`:

```swift
func addSetAction() {
    if !viewModel.isWorkoutActive { viewModel.startWorkout() }
    if isCardio {
        let dur  = Double(weight.replacingOccurrences(of: ",", with: ".")) ?? 0
        let kcal = Double(reps.replacingOccurrences(of: ",", with: ".")) ?? 0
        viewModel.training.addCardioSet(machineId: currentMachine.id, duration: dur, calories: kcal)
    } else {
        let isPR = viewModel.training.addSet(machineId: currentMachine.id, weight: weight, reps: reps)
        // ... timer and PR animation logic unchanged ...
    }
    // ... rest of the function unchanged
}
```

- [ ] **Step 2: Build check** — `Cmd+B`.

- [ ] **Step 3: Commit**

```bash
git add "Train with Me/TrainingView.swift"
git commit -m "refactor: update TrainingView — use AppViewModel, fix cardio duration/calories display"
```

---

## Task 13: Update MachineListView

**Files:**
- Modify: `Train with Me/MachineListView.swift`

- [ ] **Step 1: Change parameter type and service calls**

```swift
struct MachineListView: View {
    var viewModel: AppViewModel      // was: @ObservedObject var viewModel: FitnessViewModel
```

| Old | New |
|-----|-----|
| `viewModel.machines` | `viewModel.training.machines` |
| `viewModel.addMachine(muscle:image:)` | `viewModel.training.addMachine(muscle:image:)` |
| `viewModel.deleteMachine(machine:)` | `viewModel.training.deleteMachine(machine:)` |
| `viewModel.currentTheme` | `viewModel.currentTheme` |

- [ ] **Step 2: Build check** — `Cmd+B`.

- [ ] **Step 3: Commit**

```bash
git add "Train with Me/MachineListView.swift"
git commit -m "refactor: update MachineListView to use AppViewModel"
```

---

## Task 14: Update Remaining Views

**Files:**
- Modify: `Train with Me/SmartStatsView.swift`
- Modify: `Train with Me/BodyStatsView.swift`
- Modify: `Train with Me/HistoryView.swift`
- Modify: `Train with Me/SettingsView.swift`
- Modify: `Train with Me/GamificationView.swift`
- Modify: `Train with Me/PRDashboardView.swift`
- Modify: `Train with Me/WorkoutCalendarView.swift`
- Modify: `Train with Me/MuscleHeatmapView.swift`
- Modify: `Train with Me/CreateRoutineView.swift`
- Modify: `Train with Me/RoutineDetailView.swift`

Apply the same pattern to each file: change `@ObservedObject var viewModel: FitnessViewModel` → `var viewModel: AppViewModel` and namespace service calls.

- [ ] **Step 1: Update SmartStatsView**

```swift
struct SmartStatsView: View {
    var viewModel: AppViewModel
```

| Old | New |
|-----|-----|
| `viewModel.isAiLoading` | `viewModel.gemini.isLoading` |
| `viewModel.aiResponse` | `viewModel.gemini.lastResponse` |
| `viewModel.analyzeBodyStats()` | `Task { await viewModel.gemini.analyzeBodyStats(weightHistory: viewModel.health.weightHistory, waistHistory: viewModel.health.waistHistory, bodyFatHistory: viewModel.health.bodyFatHistory, systolic: viewModel.latestSystolic, diastolic: viewModel.latestDiastolic, machines: viewModel.training.machines) }` |
| `viewModel.muscleShare` | `viewModel.training.muscleShare` |
| `viewModel.weeklyTrend` | `viewModel.training.weeklyTrend` |
| `viewModel.currentTheme` | `viewModel.currentTheme` |

- [ ] **Step 2: Update BodyStatsView**

```swift
struct BodyStatsView: View {
    var viewModel: AppViewModel
```

| Old | New |
|-----|-----|
| `viewModel.weightHistory` | `viewModel.health.weightHistory` |
| `viewModel.waistHistory` | `viewModel.health.waistHistory` |
| `viewModel.bodyFatHistory` | `viewModel.health.bodyFatHistory` |
| `viewModel.bicepsHistory` | `viewModel.health.bicepsHistory` |
| `viewModel.chestHistory` | `viewModel.health.chestHistory` |
| `viewModel.thighHistory` | `viewModel.health.thighHistory` |
| `viewModel.currentWeight` | `viewModel.health.currentWeight` |
| `viewModel.latestSystolic` | `viewModel.latestSystolic` |
| `viewModel.latestDiastolic` | `viewModel.latestDiastolic` |
| `viewModel.addBodyMeasurement(weight:waist:fat:biceps:chest:thigh:)` | `viewModel.health.addMeasurement(weight:waist:fat:biceps:chest:thigh:healthKitEnabled:viewModel.healthKitEnabled)` |
| `viewModel.saveBloodPressure(systolic:diastolic:)` | `viewModel.saveBloodPressure(systolic:diastolic:)` |
| `viewModel.refreshBodyData()` | `viewModel.health.refreshFromHealthKit()` |
| `viewModel.currentTheme` | `viewModel.currentTheme` |

- [ ] **Step 3: Update HistoryView**

Remove the duplicate file-header comment at the bottom (lines 33–38). Change type:

```swift
struct HistoryView: View {
    var viewModel: AppViewModel
```

`volumeForDate(_:)` in HistoryView delegates to the service:
```swift
func volumeForDate(_ date: Date) -> Double {
    viewModel.training.volumeForDay(date)
}
```

- [ ] **Step 4: Update SettingsView**

```swift
struct SettingsView: View {
    var viewModel: AppViewModel
    @Environment(\.modelContext) private var modelContext
```

| Old | New |
|-----|-----|
| `viewModel.timerEnabled` | `viewModel.timerEnabled` (binding: `Binding(get: { viewModel.timerEnabled }, set: { viewModel.timerEnabled = $0 })` — or use `@Bindable var viewModel`) |
| `viewModel.healthKitEnabled` | `viewModel.healthKitEnabled` |
| `viewModel.bodyStatsEnabled` | `viewModel.bodyStatsEnabled` |
| `viewModel.bloodPressureEnabled` | `viewModel.bloodPressureEnabled` |
| `viewModel.currentTheme` | `viewModel.currentTheme` |
| `viewModel.healthManager.requestAuthorization` | `viewModel.health.requestAuthorization` |
| `viewModel.syncMachinesToWatch()` | `viewModel.syncMachinesToWatch()` |
| `viewModel.importExportMessage` | `viewModel.backup.message` |
| `viewModel.errorMessage` | `viewModel.errorMessage` |
| `viewModel.createBackupFile()` | `viewModel.backup.createBackupFile(training: viewModel.training, health: viewModel.health)` |
| `viewModel.restoreBackup(from:)` | `guard let data = try? Data(contentsOf: url) else { return }; viewModel.backup.restoreBackupData(data, training: viewModel.training, health: viewModel.health, ctx: modelContext, healthKitEnabled: viewModel.healthKitEnabled)` |
| `viewModel.generateCSV()` | `viewModel.backup.generateCSV(machines: viewModel.training.machines)` |
| `viewModel.importCardioFromHealth` | `viewModel.backup.importCardioFromHealth(training: viewModel.training, health: viewModel.health) { showSuccessAlert = true }` |

For `@Binding` on `viewModel` properties, add `@Bindable var viewModel: AppViewModel` at the top of SettingsView — this enables `$viewModel.timerEnabled` syntax with `@Observable`.

- [ ] **Step 5: Update GamificationView**

```swift
struct GamificationView: View {
    var viewModel: AppViewModel
```

| Old | New |
|-----|-----|
| `viewModel.currentLevelIndex` | `viewModel.training.currentLevelIndex` |
| `viewModel.levelTitle` | `viewModel.training.levelTitle` |
| `viewModel.totalXP` | `viewModel.training.totalXP` |
| `viewModel.levelProgress` | `viewModel.training.levelProgress` |
| `viewModel.xpToNextLevel` | `viewModel.training.xpToNextLevel` |
| `viewModel.achievements` | `viewModel.training.achievements` |
| `viewModel.currentStreak` | `viewModel.training.currentStreak` |
| `viewModel.longestStreak` | `viewModel.training.longestStreak` |
| `viewModel.totalTrainingDays` | `viewModel.training.totalTrainingDays` |
| `viewModel.currentTheme` | `viewModel.currentTheme` |

- [ ] **Step 6: Update PRDashboardView**

```swift
struct PRDashboardView: View {
    var viewModel: AppViewModel
```

| Old | New |
|-----|-----|
| `viewModel.personalRecords` | `viewModel.training.personalRecords` |
| `viewModel.currentTheme` | `viewModel.currentTheme` |

- [ ] **Step 7: Update WorkoutCalendarView**

```swift
struct WorkoutCalendarView: View {
    var viewModel: AppViewModel
```

| Old | New |
|-----|-----|
| `viewModel.trainingCalendarData(weeks:)` | `viewModel.training.trainingCalendarData(weeks:)` |
| `viewModel.currentTheme` | `viewModel.currentTheme` |

- [ ] **Step 8: Update MuscleHeatmapView**

```swift
struct MuscleHeatmapView: View {
    var viewModel: AppViewModel
```

| Old | New |
|-----|-----|
| `viewModel.muscleShare` | `viewModel.training.muscleShare` |
| `viewModel.muscleGroups` | `viewModel.training.muscleGroupNames()` |
| `viewModel.machines` | `viewModel.training.machines` |
| `viewModel.currentTheme` | `viewModel.currentTheme` |

- [ ] **Step 9: Update CreateRoutineView**

```swift
struct CreateRoutineView: View {
    var viewModel: AppViewModel
```

| Old | New |
|-----|-----|
| `viewModel.machines` | `viewModel.training.machines` |
| `viewModel.muscleGroups` | `viewModel.training.muscleGroupNames()` |
| `viewModel.addRoutine(name:selectedMachines:)` | `viewModel.training.addRoutine(name:selectedMachines:)` |
| `viewModel.currentTheme` | `viewModel.currentTheme` |

- [ ] **Step 10: Update RoutineDetailView**

```swift
struct RoutineDetailView: View {
    var viewModel: AppViewModel
```

| Old | New |
|-----|-----|
| `viewModel.machines` | `viewModel.training.machines` |
| `viewModel.currentTheme` | `viewModel.currentTheme` |

- [ ] **Step 11: Build check** — `Cmd+B`. Fix all remaining errors.

- [ ] **Step 12: Commit**

```bash
git add "Train with Me/SmartStatsView.swift" "Train with Me/BodyStatsView.swift" \
        "Train with Me/HistoryView.swift" "Train with Me/SettingsView.swift" \
        "Train with Me/GamificationView.swift" "Train with Me/PRDashboardView.swift" \
        "Train with Me/WorkoutCalendarView.swift" "Train with Me/MuscleHeatmapView.swift" \
        "Train with Me/CreateRoutineView.swift" "Train with Me/RoutineDetailView.swift"
git commit -m "refactor: update all remaining views to use AppViewModel + services"
```

---

## Task 15: Cleanup

**Files:**
- Delete: `Train with Me/FitnessViewModel.swift`
- Delete: `Train with Me/HealthManager.swift`
- Delete: `Train with Me/Untitled.swift`

- [ ] **Step 1: Delete obsolete files from filesystem**

```bash
rm "Train with Me/FitnessViewModel.swift"
rm "Train with Me/HealthManager.swift"
rm "Train with Me/Untitled.swift"
```

- [ ] **Step 2: Remove from Xcode project**

In Xcode: select each deleted file → Delete → **Move to Trash** (or **Remove Reference** if already gone).

- [ ] **Step 3: Final build check**

`Cmd+B` — must compile with zero errors and zero new warnings. Fix any remaining issues.

- [ ] **Step 4: Run on simulator**

Run on iPhone simulator (iOS 17+). Verify:
- App launches without crash
- Dashboard loads muscle groups and recovery status
- Can add a machine and log a set
- Settings sheet opens; theme switcher works
- No data loss from existing data (migration ran correctly)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: delete FitnessViewModel, HealthManager, Untitled — refactoring complete"
```

---

## Self-Review Notes

- **Spec §2 (AppViewModel):** Covered in Task 9. Blood pressure kept in AppViewModel as preferences (not body model data) — per spec.
- **Spec §3 (Services):** All 5 services created in Tasks 4–8. `machinesForWatch()` helper on TrainingService feeds WatchService.
- **Spec §4 (ExerciseSet duration/calories):** Task 2 adds fields; Task 12 updates display and input.
- **Spec §5 (xcconfig):** Task 1.
- **Spec §6 (Migration):** Task 3; called in ContentView.onAppear before configure().
- **Type consistency:** `AppViewModel` used consistently across all view parameter types. `viewModel.training.*` / `viewModel.health.*` / `viewModel.gemini.*` namespacing applied uniformly.
- **BackupService.restoreBackup:** Uses `restoreBackupData` with `ModelContext` passed directly from SettingsView's `@Environment(\.modelContext)`.
- **HealthService.configure:** Can be called multiple times (guard protects re-entry) — safe after BackupService restore.
