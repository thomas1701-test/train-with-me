import Foundation
import HealthKit

@Observable
final class WatchWorkoutManager: NSObject {
    var isRunning = false
    var currentHR: Double = 0
    var avgHR: Double = 0
    var maxHR: Double = 0
    var calories: Double = 0
    var elapsedSeconds: Int = 0

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private var workoutStartDate: Date = Date()

    func requestAuth() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let types: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.workoutType()
        ]
        store.requestAuthorization(toShare: types, read: types) { _, _ in }
    }

    func start() {
        guard !isRunning else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        guard let session = try? HKWorkoutSession(healthStore: store, configuration: config) else { return }
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
        session.delegate = self
        builder.delegate = self
        self.session = session
        self.builder = builder
        let startDate = Date()
        session.startActivity(with: startDate)
        builder.beginCollection(withStart: startDate) { _, _ in }
        DispatchQueue.main.async {
            self.isRunning = true
            self.currentHR = 0; self.avgHR = 0; self.maxHR = 0
            self.calories = 0; self.elapsedSeconds = 0
            self.workoutStartDate = startDate
            self.startTimer()
        }
    }

    func stop() {
        guard isRunning else { return }
        stopTimer()
        session?.end()
        builder?.endCollection(withEnd: Date()) { [weak self] _, _ in
            self?.builder?.finishWorkout { _, _ in
                DispatchQueue.main.async { self?.isRunning = false }
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsedSeconds = Int(Date().timeIntervalSince(self.workoutStartDate))
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState, date: Date) {}
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async { self.isRunning = false; self.stopTimer() }
    }
}

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let bpm = HKUnit.count().unitDivided(by: .minute())
        if let t = HKQuantityType.quantityType(forIdentifier: .heartRate),
           collectedTypes.contains(t),
           let s = workoutBuilder.statistics(for: t) {
            DispatchQueue.main.async {
                self.currentHR = s.mostRecentQuantity()?.doubleValue(for: bpm) ?? self.currentHR
                self.avgHR     = s.averageQuantity()?.doubleValue(for: bpm)    ?? self.avgHR
                self.maxHR     = s.maximumQuantity()?.doubleValue(for: bpm)    ?? self.maxHR
            }
        }
        if let t = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           collectedTypes.contains(t),
           let s = workoutBuilder.statistics(for: t) {
            DispatchQueue.main.async {
                self.calories = s.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? self.calories
            }
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
