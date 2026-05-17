import WatchConnectivity

struct IncomingWatchSet: Equatable {
    let machineName: String
    let weight: String
    let reps: String
}

struct IncomingCardioResult: Equatable {
    let activityName: String
    let durationMinutes: Double
    let distanceKm: Double
    let avgSpeedKmh: Double
    let maxSpeedKmh: Double
    let avgHR: Double
    let maxHR: Double
    let calories: Double
    let date: Date
}

/// NSObject subclass required for WCSessionDelegate conformance.
/// @Observable tracks incomingSet so AppViewModel can react to it.
@Observable
final class WatchService: NSObject, WCSessionDelegate {

    var incomingSet: IncomingWatchSet? = nil
    var incomingCardioResult: IncomingCardioResult? = nil

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

    /// Sends a workout lifecycle command to the Watch.
    func sendWorkoutCommand(_ action: String) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled else { return }
        WCSession.default.transferUserInfo(["action": action])
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let action = userInfo["action"] as? String else { return }
        switch action {
        case "addSet":
            guard let machineName = userInfo["machineName"] as? String,
                  let weight      = userInfo["weight"]      as? String,
                  let reps        = userInfo["reps"]        as? String else { return }
            DispatchQueue.main.async {
                self.incomingSet = IncomingWatchSet(machineName: machineName, weight: weight, reps: reps)
            }
        case "cardioResult":
            guard let activityName  = userInfo["activityName"]    as? String,
                  let durationMin   = userInfo["durationMinutes"]  as? Double,
                  let distanceKm    = userInfo["distanceKm"]       as? Double,
                  let avgSpeedKmh   = userInfo["avgSpeedKmh"]      as? Double,
                  let maxSpeedKmh   = userInfo["maxSpeedKmh"]      as? Double,
                  let avgHR         = userInfo["avgHR"]            as? Double,
                  let maxHR         = userInfo["maxHR"]            as? Double,
                  let calories      = userInfo["calories"]         as? Double,
                  let dateString    = userInfo["date"]             as? String else { return }
            let date = ISO8601DateFormatter().date(from: dateString) ?? Date()
            DispatchQueue.main.async {
                self.incomingCardioResult = IncomingCardioResult(
                    activityName: activityName,
                    durationMinutes: durationMin,
                    distanceKm: distanceKm,
                    avgSpeedKmh: avgSpeedKmh,
                    maxSpeedKmh: maxSpeedKmh,
                    avgHR: avgHR,
                    maxHR: maxHR,
                    calories: calories,
                    date: date
                )
            }
        default:
            break
        }
    }
}
