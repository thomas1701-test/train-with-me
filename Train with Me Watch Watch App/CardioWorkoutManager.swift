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
    private var routeBuilder: HKWorkoutRouteBuilder?
    private var locationManager: CLLocationManager?
    private var timer: Timer?
    private var speedSamples: [Double] = []
    private var collectedLocations: [CLLocation] = []
    private var distanceIdentifier: HKQuantityTypeIdentifier = .distanceWalkingRunning

    func requestAuth() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        var share: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
        if let cycling = HKObjectType.quantityType(forIdentifier: .distanceCycling) {
            share.insert(cycling)
        }
        var read = share as Set<HKObjectType>
        read.insert(HKSeriesType.workoutRoute())
        store.requestAuthorization(toShare: share, read: read) { _, _ in }
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
        self.routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: nil)
        let startDate = Date()
        session.startActivity(with: startDate)
        builder.beginCollection(withStart: startDate) { _, _ in }
        DispatchQueue.main.async {
            self.isRunning = true; self.isPaused = false; self.isFinished = false
            self.distanceMeters = 0; self.calories = 0; self.currentHR = 0
            self.avgHR = 0; self.maxHR = 0; self.currentSpeedKmh = 0
            self.avgSpeedKmh = 0; self.maxSpeedKmh = 0; self.currentPaceMinKm = 0
            self.elapsedSeconds = 0; self.speedSamples = []; self.collectedLocations = []
            self.summary = nil
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

        sendWorkoutStopped()

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
        sendResultToPhone(s)

        let endDate = Date()
        let locationsToSave = collectedLocations
        let route = routeBuilder

        session?.end()
        builder?.endCollection(withEnd: endDate) { [weak self] _, _ in
            self?.builder?.finishWorkout { workout, _ in
                guard let workout, let route else { return }
                // Insert all collected GPS locations into the route
                if !locationsToSave.isEmpty {
                    route.insertRouteData(locationsToSave) { success, _ in
                        if success {
                            route.finishRoute(with: workout, metadata: nil) { _, _ in }
                        }
                    }
                }
            }
        }
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
        // .common mode ensures the timer fires even during scroll/gesture tracking
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsedSeconds += 1
            self.sendLiveMetrics()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func sendLiveMetrics() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        let msg: [String: Any] = [
            "action":           "liveMetrics",
            "activityName":     selectedActivity.name,
            "activityIcon":     selectedActivity.icon,
            "elapsedSeconds":   elapsedSeconds,
            "currentHR":        currentHR,
            "avgHR":            avgHR,
            "maxHR":            maxHR,
            "currentSpeedKmh":  currentSpeedKmh,
            "avgSpeedKmh":      avgSpeedKmh,
            "maxSpeedKmh":      maxSpeedKmh,
            "distanceMeters":   distanceMeters,
            "calories":         calories,
            "currentPaceMinKm": currentPaceMinKm
        ]
        WCSession.default.sendMessage(msg, replyHandler: nil, errorHandler: nil)
    }

    func sendWorkoutStopped() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["action": "workoutStopped"], replyHandler: nil, errorHandler: nil)
    }

    private func startLocation() {
        let lm = CLLocationManager()
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyBest
        lm.distanceFilter = 5  // only update every 5 metres to save battery
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
        // Filter out inaccurate fixes
        let valid = locations.filter { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy < 50 }
        guard !valid.isEmpty else { return }

        // Accumulate for route saving
        collectedLocations.append(contentsOf: valid)

        // Stream locations into route builder in batches as they arrive
        routeBuilder?.insertRouteData(valid) { _, _ in }

        // Update live speed display from most recent valid fix
        if let loc = valid.last, loc.speed >= 0 {
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
}
