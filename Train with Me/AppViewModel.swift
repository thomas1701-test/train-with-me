import SwiftUI
import SwiftData
import ActivityKit
import UIKit

@Observable
final class AppViewModel {

    // MARK: - Services
    let training = TrainingService()
    let health   = HealthService()
    let gemini   = GeminiService()
    let watch    = WatchService()
    let backup   = BackupService()

    // MARK: - Workout Session State
    var isWorkoutActive      = false
    var workoutStartDate: Date? = nil
    var sessionSummaryMessage: String? = nil
    var shareImage: UIImage? = nil
    var workoutAnalysis      = ""
    var isAnalyzingWorkout   = false

    // MARK: - UI Feedback
    var errorMessage: String? = nil
    var newlyUnlockedAchievement: Achievement? = nil

    // MARK: - Blood Pressure
    var latestSystolic:  Double = UserDefaults.standard.double(forKey: "latestSystolic")  { didSet { UserDefaults.standard.set(latestSystolic,  forKey: "latestSystolic") } }
    var latestDiastolic: Double = UserDefaults.standard.double(forKey: "latestDiastolic") { didSet { UserDefaults.standard.set(latestDiastolic, forKey: "latestDiastolic") } }

    // MARK: - Preferences (UserDefaults-backed)
    var timerEnabled:         Bool   = UserDefaults.standard.bool(forKey: "TimerEnabled")         { didSet { UserDefaults.standard.set(timerEnabled,         forKey: "TimerEnabled") } }
    var timerDuration:        Double = { let v = UserDefaults.standard.double(forKey: "TimerDuration"); return v == 0 ? 90 : v }()  { didSet { UserDefaults.standard.set(timerDuration,        forKey: "TimerDuration") } }
    var healthKitEnabled:     Bool   = UserDefaults.standard.bool(forKey: "HealthKitEnabled")     { didSet { UserDefaults.standard.set(healthKitEnabled,     forKey: "HealthKitEnabled") } }
    var bodyStatsEnabled:     Bool   = UserDefaults.standard.bool(forKey: "BodyStatsEnabled")     { didSet { UserDefaults.standard.set(bodyStatsEnabled,     forKey: "BodyStatsEnabled") } }
    var bloodPressureEnabled: Bool   = UserDefaults.standard.bool(forKey: "BloodPressureEnabled") { didSet { UserDefaults.standard.set(bloodPressureEnabled, forKey: "BloodPressureEnabled") } }
    var currentTheme: AppTheme = {
        if let d = UserDefaults.standard.data(forKey: "AppTheme"),
           let v = try? JSONDecoder().decode(AppTheme.self, from: d) { return v }
        return .midnight
    }() { didSet { if let d = try? JSONEncoder().encode(currentTheme) { UserDefaults.standard.set(d, forKey: "AppTheme") } } }

    // MARK: - AI

    var aiKeyVersion: Int = 0

    var isAIEnabled: Bool {
        _ = aiKeyVersion
        return KeychainService.load() != nil
    }

    func notifyAIKeyChanged() { aiKeyVersion += 1 }

    // MARK: - Setup

    func configure(modelContext: ModelContext) {
        training.configure(modelContext: modelContext)
        health.configure(modelContext: modelContext)
        NotificationManager.shared.requestPermission()
        if healthKitEnabled || bodyStatsEnabled {
            health.fetchLatestWeight { [weak self] w in
                if let v = w { self?.health.currentWeight = v }
            }
        }
    }

    // MARK: - Workout

    func startWorkout() {
        isWorkoutActive = true
        workoutStartDate = Date()
        health.lastWorkoutAvgHR = nil
        health.lastWorkoutMaxHR = nil
        health.lastWorkoutKcal = 0
        watch.sendWorkoutCommand("startWorkout")
    }

    @MainActor func finishWorkout() {
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
                // Collect exercise data for HealthKit
                let exerciseData = todayData.map { item -> (name: String, maxWeight: Double) in
                    let maxW = item.sets.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.max() ?? 0
                    return (name: item.machine.name, maxWeight: maxW)
                }
                let muscleList = Array(muscles)
                let totalSets = todayData.reduce(0) { $0 + $1.sets.count }

                health.saveWorkout(startDate: start, endDate: end, totalVolume: vol,
                                   muscles: muscleList, exercises: exerciseData, totalSets: totalSets)

                // Fetch HR from Apple Watch if available
                let workoutStart = start
                health.fetchHeartRate(from: workoutStart, to: end) { [weak self] avg, max in
                    self?.health.lastWorkoutAvgHR = avg
                    self?.health.lastWorkoutMaxHR = max
                }

                // Store estimated kcal for display
                let hours = end.timeIntervalSince(start) / 3600
                let bodyWeight = health.currentWeight > 0 ? health.currentWeight : 80.0
                health.lastWorkoutKcal = max(5.0 * bodyWeight * hours, vol * 0.06)
            }
            if !todayData.isEmpty && isAIEnabled {
                Task { await analyzeCompletedWorkout(todaysSets: todayData) }
            }
        } else {
            sessionSummaryMessage = "Keine Sätze für heute."
        }
        isWorkoutActive = false; workoutStartDate = nil
        watch.sendWorkoutCommand("stopWorkout")
        training.calculateStats()
        if let a = training.checkNewAchievements() { newlyUnlockedAchievement = a }
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

    func handleIncomingCardioResult(_ result: IncomingCardioResult) {
        let machineName = "Watch: \(result.activityName)"
        let durationStr = String(format: "%.1f", result.durationMinutes).replacingOccurrences(of: ".", with: ",")
        let kcalStr     = String(format: "%.0f", result.calories)

        if let m = training.machines.first(where: { $0.name == machineName && $0.muscleGroup == "Cardio" }) {
            if !m.sets.contains(where: { abs($0.date.timeIntervalSince(result.date)) < 60 }) {
                let s = ExerciseSet(weight: durationStr, reps: kcalStr, date: result.date)
                s.duration = result.durationMinutes
                s.calories = result.calories
                m.sets.append(s)
                if result.avgHR > 0 { health.lastWorkoutAvgHR = result.avgHR }
                if result.maxHR > 0 { health.lastWorkoutMaxHR = result.maxHR }
                training.calculateStats()
            }
        } else {
            let id  = UUID()
            let img = UIImage(color: .darkGray, size: CGSize(width: 400, height: 400)) ?? UIImage()
            let m   = Machine(id: id, name: machineName, muscleGroup: "Cardio",
                              imageFileName: training.saveImage(image: img, id: id))
            let s   = ExerciseSet(weight: durationStr, reps: kcalStr, date: result.date)
            s.duration = result.durationMinutes
            s.calories = result.calories
            m.sets.append(s)
            training.insertMachine(m)
            if result.avgHR > 0 { health.lastWorkoutAvgHR = result.avgHR }
            if result.maxHR > 0 { health.lastWorkoutMaxHR = result.maxHR }
            training.calculateStats()
        }
    }

    // MARK: - Blood Pressure

    func saveBloodPressure(systolic: Double, diastolic: Double) {
        latestSystolic = systolic; latestDiastolic = diastolic
        if healthKitEnabled { health.saveBloodPressure(systolic: systolic, diastolic: diastolic) }
    }
}
