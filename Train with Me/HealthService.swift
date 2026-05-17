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
    var lastWorkoutAvgHR: Double? = nil
    var lastWorkoutMaxHR: Double? = nil
    var lastWorkoutKcal: Double = 0

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
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
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
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: nil, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, _ in
            DispatchQueue.main.async { completion(samples as? [HKWorkout] ?? []) }
        }
        store.execute(query)
    }

    /// Fetches non-strength workouts (cardio, running, cycling…) from HealthKit for the given date range.
    /// Excludes .traditionalStrengthTraining which the app itself saves.
    func fetchExternalWorkouts(from startDate: Date, to endDate: Date, completion: @escaping ([HKWorkout]) -> Void) {
        let pred = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: pred,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            let workouts = (samples as? [HKWorkout] ?? [])
                .filter { $0.workoutActivityType != .traditionalStrengthTraining }
            DispatchQueue.main.async { completion(workouts) }
        }
        store.execute(query)
    }

    // MARK: - HealthKit Write

    func saveWorkout(startDate: Date, endDate: Date, totalVolume: Double,
                     muscles: [String], exercises: [(name: String, maxWeight: Double)],
                     totalSets: Int) {
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())

        builder.beginCollection(withStart: startDate) { [weak self] success, _ in
            guard success, let self else { return }

            // Calorie estimation: MET 5.0 × bodyweight(kg) × hours
            let hours = endDate.timeIntervalSince(startDate) / 3600
            let bodyWeight = self.currentWeight > 0 ? self.currentWeight : 80.0
            let estimatedKcal = max(5.0 * bodyWeight * hours, totalVolume * 0.06)

            let energyType = HKQuantityType(.activeEnergyBurned)
            let energySample = HKQuantitySample(
                type: energyType,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: estimatedKcal),
                start: startDate, end: endDate)

            builder.add([energySample]) { _, _ in
                let topExercises = exercises.prefix(3)
                    .map { "\($0.name) \(Int($0.maxWeight)) kg" }
                    .joined(separator: ", ")

                let _: [String: Any] = [
                    HKMetadataKeyWorkoutBrandName: "Train with Me",
                    "MuscleGroups": muscles.joined(separator: ", "),
                    "TotalSets": "\(totalSets)",
                    "TotalVolume": "\(Int(totalVolume)) kg",
                    "TopExercises": topExercises.isEmpty ? "-" : topExercises
                ]

                builder.endCollection(withEnd: endDate) { _, _ in
                    builder.finishWorkout { _, _ in }
                    // metadata must be added to the finished workout via a separate save — skip for now,
                    // Apple doesn't support metadata via builder directly in all iOS versions.
                    // The key data (calories) is already embedded as a sample.
                }
            }
        }
    }

    func fetchHeartRate(from start: Date, to end: Date, completion: @escaping (Double?, Double?) -> Void) {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(nil, nil); return
        }
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: hrType, predicate: pred,
                                   limit: HKObjectQueryNoLimit,
                                   sortDescriptors: nil) { _, samples, _ in
            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            let values = (samples as? [HKQuantitySample] ?? []).map {
                $0.quantity.doubleValue(for: bpmUnit)
            }
            DispatchQueue.main.async {
                if values.isEmpty {
                    completion(nil, nil)
                } else {
                    let avg = values.reduce(0, +) / Double(values.count)
                    let max = values.max() ?? avg
                    completion(avg, max)
                }
            }
        }
        store.execute(query)
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

    func restoreBodyMeasurements(from b: BackupData) throws {
        guard let ctx = modelContext else { return }
        let existing = (try? ctx.fetch(FetchDescriptor<BodyMeasurement>())) ?? []
        existing.forEach { ctx.delete($0) }
        func insert(_ type: String, _ points: [ChartDataPoint]?) {
            for p in (points ?? []) { ctx.insert(BodyMeasurement(date: p.date, type: type, value: p.value)) }
        }
        insert("weight",  b.weightHistory);  insert("waist",   b.waistHistory)
        insert("bodyFat", b.bodyFatHistory); insert("biceps",  b.bicepsHistory)
        insert("chest",   b.chestHistory);   insert("thigh",   b.thighHistory)
        try ctx.save()
        let all = (try? ctx.fetch(FetchDescriptor<BodyMeasurement>(sortBy: [SortDescriptor(\.date)]))) ?? []
        weightHistory  = all.filter { $0.type == "weight"  }.map { ChartDataPoint(date: $0.date, value: $0.value) }
        waistHistory   = all.filter { $0.type == "waist"   }.map { ChartDataPoint(date: $0.date, value: $0.value) }
        bodyFatHistory = all.filter { $0.type == "bodyFat" }.map { ChartDataPoint(date: $0.date, value: $0.value) }
        bicepsHistory  = all.filter { $0.type == "biceps"  }.map { ChartDataPoint(date: $0.date, value: $0.value) }
        chestHistory   = all.filter { $0.type == "chest"   }.map { ChartDataPoint(date: $0.date, value: $0.value) }
        thighHistory   = all.filter { $0.type == "thigh"   }.map { ChartDataPoint(date: $0.date, value: $0.value) }
        currentWeight  = weightHistory.last?.value ?? currentWeight
    }

    func refreshFromHealthKit() {
        fetchHistory(for: .bodyMass,          unit: .gramUnit(with: .kilo))    { [weak self] p in self?.weightHistory  = p; self?.currentWeight = p.last?.value ?? self?.currentWeight ?? 0 }
        fetchHistory(for: .waistCircumference, unit: .meterUnit(with: .centi)) { [weak self] p in self?.waistHistory   = p }
        fetchHistory(for: .bodyFatPercentage,  unit: .percent())               { [weak self] p in self?.bodyFatHistory = p.map { ChartDataPoint(id: $0.id, date: $0.date, value: $0.value * 100) } }
    }
}
