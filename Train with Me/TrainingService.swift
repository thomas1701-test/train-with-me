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
        saveContext()
    }

    func updateMachineImage(machineId: UUID, newImage: UIImage) {
        guard let m = machines.first(where: { $0.id == machineId }) else { return }
        deleteImageFile(fileName: m.imageFileName)
        m.imageFileName = saveImage(image: newImage, id: m.id)
        saveContext()
    }

    func updateMachineNotes(machineId: UUID, notes: String) {
        machines.first(where: { $0.id == machineId })?.notes = notes
        saveContext()
    }

    func updateMachineAssisted(machineId: UUID, isAssisted: Bool) {
        machines.first(where: { $0.id == machineId })?.isAssisted = isAssisted
        saveContext()
    }

    func deleteMachine(machine: Machine) {
        guard let ctx = modelContext else { return }
        deleteImageFile(fileName: machine.imageFileName)
        ctx.delete(machine); machines.removeAll { $0.id == machine.id }
    }

    func insertMachine(_ machine: Machine) {
        guard let ctx = modelContext else { return }
        ctx.insert(machine); machines.append(machine)
    }

    // MARK: - Set CRUD

    /// Returns true if today's sets represent a new personal best for this machine.
    /// For assisted machines: PR = today's min weight < any previous day's min weight.
    @discardableResult
    func addSet(machineId: UUID, weight: String, reps: String) -> Bool {
        guard let m = machines.first(where: { $0.id == machineId }) else { return false }
        m.sets.append(ExerciseSet(weight: weight, reps: reps, date: Date()))
        calculateStats()
        if m.isAssisted {
            let cal = Calendar.current
            let todaySets = m.sets.filter { cal.isDateInToday($0.date) && (Int($0.reps) ?? 0) > 0 }
            guard let todayMin = todaySets.compactMap({ Double($0.weight.replacingOccurrences(of: ",", with: ".")) }).min() else { return false }
            let prevMin = Dictionary(grouping: m.sets.filter { (Int($0.reps) ?? 0) > 0 }) { cal.startOfDay(for: $0.date) }
                .filter { !cal.isDateInToday($0.key) }
                .compactMap { $0.value.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.min() }
                .min()
            guard let prev = prevMin else { return false }
            return todayMin < prev
        } else {
            let todayVol = m.sets.filter { Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.volume }
            let bestVol  = Dictionary(grouping: m.sets) { Calendar.current.startOfDay(for: $0.date) }
                .filter { !Calendar.current.isDateInToday($0.key) }
                .map { $0.value.reduce(0) { $0 + $1.volume } }.max() ?? 0
            return todayVol > bestVol && bestVol > 0
        }
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
        s.rpe = rpe; s.rir = rir; saveContext()
    }

    // MARK: - Routine CRUD

    func addRoutine(name: String, selectedMachines: [Machine]) {
        guard let ctx = modelContext else { return }
        let r = Routine(name: name, machineIDs: selectedMachines.map { $0.id })
        ctx.insert(r); routines.append(r); saveContext()
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

        if machine.isAssisted {
            let lastMinW = last.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.min() ?? lastW
            if byDay.count == 1 {
                return OverloadSuggestion(lastWeight: lastMinW, lastReps: lastR,
                    message: "Zuletzt: \(fmt(lastMinW)) kg Unterstützung × \(lastR) – weniger versuchen 🎯")
            }
            let prevMinW = byDay[1].value.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.min() ?? 0
            if lastMinW <= prevMinW && lastR >= 8 {
                return OverloadSuggestion(lastWeight: lastMinW, lastReps: lastR,
                    message: "Zuletzt: \(fmt(lastMinW)) kg → heute \(fmt(max(lastMinW - 2.5, 0))) kg Unterstützung versuchen 💡")
            } else {
                return OverloadSuggestion(lastWeight: lastMinW, lastReps: lastR,
                    message: "Zuletzt: \(fmt(lastMinW)) kg Unterstützung × \(lastR)")
            }
        }

        if byDay.count == 1 {
            return OverloadSuggestion(lastWeight: lastW, lastReps: lastR,
                message: "Letztes Mal: \(fmt(lastW)) kg × \(lastR) – mehr Wiederholungen versuchen 🎯")
        }
        let prevW = byDay[1].value.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.max() ?? 0
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
            if m.isAssisted {
                let valid = m.sets.filter { (Int($0.reps) ?? 0) > 0 }
                guard !valid.isEmpty else { return nil }
                let minW = valid.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.min() ?? 0
                let best = valid.min(by: {
                    (Double($0.weight.replacingOccurrences(of: ",", with: ".")) ?? .infinity) <
                    (Double($1.weight.replacingOccurrences(of: ",", with: ".")) ?? .infinity)
                })!
                return PersonalRecord(machineName: m.name, muscleGroup: m.muscleGroup, isAssisted: true,
                                      maxWeight: minW, maxReps: Int(best.reps) ?? 0, bestOneRepMax: 0, date: best.date)
            } else {
                let best = m.sets.max(by: { $0.oneRepMax < $1.oneRepMax })!
                let maxW = m.sets.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.max() ?? 0
                let maxR = m.sets.compactMap { Int($0.reps) }.max() ?? 0
                return PersonalRecord(machineName: m.name, muscleGroup: m.muscleGroup, isAssisted: false,
                                      maxWeight: maxW, maxReps: maxR, bestOneRepMax: best.oneRepMax, date: best.date)
            }
        }.sorted {
            if $0.isAssisted != $1.isAssisted { return !$0.isAssisted }
            if $0.isAssisted { return $0.maxWeight < $1.maxWeight }
            return $0.bestOneRepMax > $1.bestOneRepMax
        }
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
        var dist: [String: Double] = [:]; var total = 0.0
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

    // MARK: - Watch Support

    func machinesForWatch() -> [[String: Any]] {
        machines.map { ["id": $0.id.uuidString, "name": $0.name, "muscleGroup": $0.muscleGroup] }
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
                            imageFileName: md.imageFileName, notes: md.notes, isAssisted: md.isAssisted ?? false)
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
