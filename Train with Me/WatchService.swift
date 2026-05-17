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

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let action      = userInfo["action"]      as? String, action == "addSet",
              let machineName = userInfo["machineName"] as? String,
              let weight      = userInfo["weight"]      as? String,
              let reps        = userInfo["reps"]        as? String else { return }
        DispatchQueue.main.async {
            self.incomingSet = (machineName, weight, reps)
        }
    }
}
