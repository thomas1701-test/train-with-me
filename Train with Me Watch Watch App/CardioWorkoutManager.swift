import Foundation
import HealthKit
import CoreLocation
import WatchConnectivity

struct CardioSummary {
    var durationSeconds: Int
    var distanceMeters: Double
    var avgSpeedKmh: Double
    var maxSpeedKmh: Double
    var avgPaceMinKm: Double
    var avgHR: Double
    var maxHR: Double
    var calories: Double
    var activityName: String
}

struct CardioActivity {
    let name: String
    let type: HKWorkoutActivityType
    let icon: String
    let distanceIdentifier: HKQuantityTypeIdentifier
}

let cardioActivities: [CardioActivity] = [
    CardioActivity(name: "Laufen",       type: .running,  icon: "figure.run",           distanceIdentifier: .distanceWalkingRunning),
    CardioActivity(name: "Radfahren",    type: .cycling,  icon: "figure.outdoor.cycle",  distanceIdentifier: .distanceCycling),
    CardioActivity(name: "Gehen",        type: .walking,  icon: "figure.walk",           distanceIdentifier: .distanceWalkingRunning),
    CardioActivity(name: "Wandern",      type: .hiking,   icon: "figure.hiking",         distanceIdentifier: .distanceWalkingRunning),
    CardioActivity(name: "Rudern",       type: .rowing,   icon: "figure.rower",          distanceIdentifier: .distanceWalkingRunning),
    CardioActivity(name: "Seilspringen", type: .jumpRope, icon: "figure.jumprope",       distanceIdentifier: .distanceWalkingRunning),
    CardioActivity(name: "Sonstiges",    type: .other,    icon: "heart.fill",            distanceIdentifier: .distanceWalkingRunning),
]

@Observable
final class CardioWorkoutManager: NSObject {
    var isRunning = false
    var isPaused = false
    var isFinished = false
    var currentHR: Double = 0
    var avgHR: Double = 0
    var maxHR: Double = 0
    var currentSpeedKmh: Double = 0
    var avgSpeedKmh: Double = 0
    var maxSpeedKmh: Double = 0
    var currentPaceMinKm: Double = 0
    var distanceMeters: Double = 0
    var calories: Double = 0
    var elapsedSeconds: Int = 0
    var summary: CardioSummary? = nil
    var selectedActivityIndex: Int = 0

    var selectedActivity: CardioActivity { cardioActivities[selectedActivityIndex] }

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var locationManager: CLLocationManager?
    private var timer: Timer?
    private var speedSamples: [Double] = []
    private var distanceIdentifier: HKQuantityTypeIdentifier = .distanceWalkingRunning

    func requestAuth() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        var share: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.workoutType()
        ]
        if let cycling = HKObjectType.quantityType(forIdentifier: .distanceCycling) {
            share.insert(cycling)
        }
        store.requestAuthorization(toShare: share, read: share as Set<HKObjectType>) { _, _ in }
    }

    func start() {
        guard !isRunning else { return }
        let activity = selectedActivity
        distanceIdentifier = activity.distanceIdentifier
        let config = HKWorkoutConfiguration()
        config.activityType = activity.type
        config.locationType = .outdoor
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
            self.isRunning = true; self.isPaused = false; self.isFinished = false
            self.distanceMeters = 0; self.calories = 0; self.currentHR = 0
            self.avgHR = 0; self.maxHR = 0; self.currentSpeedKmh = 0
            self.avgSpeedKmh = 0; self.maxSpeedKmh = 0; self.currentPaceMinKm = 0
            self.elapsedSeconds = 0; self.speedSamples = []; self.summary = nil
            self.startTimer()
            self.startLocation()
        }
    }

    func pause() {
        guard isRunning, !isPaused else { return }
        session?.pause()
        isPaused = true
        timer?.invalidate()
    }

    func resume() {
        guard isRunning, isPaused else { return }
        session?.resume()
        isPaused = false
        startTimer()
    }

    func stop() {
        guard isRunning else { return }
        locationManager?.stopUpdatingLocation()
        timer?.invalidate(); timer = nil
        isRunning = false; isFinished = true
        let s = CardioSummary(
            durationSeconds: elapsedSeconds,
            distanceMeters: distanceMeters,
            avgSpeedKmh: avgSpeedKmh,
            maxSpeedKmh: maxSpeedKmh,
            avgPaceMinKm: avgSpeedKmh > 0.5 ? 60.0 / avgSpeedKmh : 0,
            avgHR: avgHR, maxHR: maxHR,
            calories: calories,
            activityName: selectedActivity.name
        )
        self.summary = s
        session?.end()
        builder?.endCollection(withEnd: Date()) { [weak self] _, _ in
            self?.builder?.finishWorkout { _, _ in }
        }
        sendResultToPhone(s)
    }

    func reset() {
        isFinished = false
        summary = nil
    }

    private func sendResultToPhone(_ s: CardioSummary) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let info: [String: Any] = [
            "action":          "cardioResult",
            "activityName":    s.activityName,
            "durationMinutes": Double(s.durationSeconds) / 60.0,
            "distanceKm":      s.distanceMeters / 1000.0,
            "avgSpeedKmh":     s.avgSpeedKmh,
            "maxSpeedKmh":     s.maxSpeedKmh,
            "avgHR":           s.avgHR,
            "maxHR":           s.maxHR,
            "calories":        s.calories,
            "date":            ISO8601DateFormatter().string(from: Date())
        ]
        WCSession.default.transferUserInfo(info)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    private func startLocation() {
        let lm = CLLocationManager()
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyBest
        lm.requestWhenInUseAuthorization()
        lm.startUpdatingLocation()
        self.locationManager = lm
    }
}

extension CardioWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState, date: Date) {}
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async { self.isRunning = false; self.timer?.invalidate() }
    }
}

extension CardioWorkoutManager: HKLiveWorkoutBuilderDelegate {
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
        if let t = HKQuantityType.quantityType(forIdentifier: distanceIdentifier),
           collectedTypes.contains(t),
           let s = workoutBuilder.statistics(for: t) {
            DispatchQueue.main.async {
                self.distanceMeters = s.sumQuantity()?.doubleValue(for: .meter()) ?? self.distanceMeters
            }
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

extension CardioWorkoutManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last,
              loc.horizontalAccuracy >= 0,
              loc.horizontalAccuracy < 50,
              loc.speed >= 0 else { return }
        let kmh = loc.speed * 3.6
        DispatchQueue.main.async {
            self.currentSpeedKmh = kmh
            if kmh > 0.5 { self.speedSamples.append(kmh) }
            if kmh > self.maxSpeedKmh { self.maxSpeedKmh = kmh }
            self.avgSpeedKmh = self.speedSamples.isEmpty ? 0 : self.speedSamples.reduce(0, +) / Double(self.speedSamples.count)
            self.currentPaceMinKm = kmh > 0.5 ? 60.0 / kmh : 0
        }
    }
}
