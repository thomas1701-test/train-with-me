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

    // MARK: - Blood Pressure

    func saveBloodPressure(systolic: Double, diastolic: Double) {
        latestSystolic = systolic; latestDiastolic = diastolic
        if healthKitEnabled { health.saveBloodPressure(systolic: systolic, diastolic: diastolic) }
    }
}
