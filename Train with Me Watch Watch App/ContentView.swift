import SwiftUI
import WatchKit
import Combine
import WatchConnectivity

class WatchSync: NSObject, WCSessionDelegate, ObservableObject {
    @Published var muscleGroups: [String] = []
    @Published var machines: [[String: String]] = []

    var onStartWorkout: (() -> Void)? = nil
    var onStopWorkout: (() -> Void)? = nil

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            if let groups = applicationContext["muscleGroups"] as? [String] { self.muscleGroups = groups }
            if let machs  = applicationContext["machines"]     as? [[String: String]] { self.machines = machs }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let action = userInfo["action"] as? String else { return }
        DispatchQueue.main.async {
            switch action {
            case "addSet":
                break // handled by ContentView observation of incomingSet
            case "startWorkout":
                self.onStartWorkout?()
            case "stopWorkout":
                self.onStopWorkout?()
            default:
                break
            }
        }
    }

    func sendSet(machine: String, weight: Double, reps: Int) {
        let data: [String: Any] = [
            "action":      "addSet",
            "machineName": machine,
            "weight":      String(format: "%.1f", weight).replacingOccurrences(of: ".", with: ","),
            "reps":        String(reps)
        ]
        WCSession.default.transferUserInfo(data)
    }
}

struct ContentView: View {
    @StateObject var sync = WatchSync()
    @State private var workoutManager = WatchWorkoutManager()

    @State private var selectedCategory = ""
    @State private var selectedMachine  = ""
    @State private var weight: Double   = 50.0
    @State private var reps: Int        = 10
    @State private var showSaved        = false

    var availableMachines: [String] {
        sync.machines.filter { $0["muscleGroup"] == selectedCategory }.compactMap { $0["name"] }
    }

    var isCardio: Bool { selectedCategory.lowercased() == "cardio" }

    var body: some View {
        TabView {
            strengthTab
                .tabItem { Label("Kraft", systemImage: "dumbbell.fill") }
            CardioWorkoutView()
                .tabItem { Label("Cardio", systemImage: "figure.run") }
        }
        .onAppear {
            workoutManager.requestAuth()
            sync.onStartWorkout = { workoutManager.start() }
            sync.onStopWorkout  = { workoutManager.stop() }
            if let firstGroup = sync.muscleGroups.first {
                selectedCategory = firstGroup
                selectedMachine = sync.machines.filter { $0["muscleGroup"] == firstGroup }.compactMap { $0["name"] }.first ?? ""
            }
        }
        .onChange(of: sync.muscleGroups) { _, groups in
            if selectedCategory.isEmpty, let first = groups.first { selectedCategory = first }
        }
        .onChange(of: sync.machines) { _, _ in
            if selectedMachine.isEmpty, let first = availableMachines.first { selectedMachine = first }
        }
    }

    // MARK: - Strength Tab

    var strengthTab: some View {
        ZStack {
            if sync.muscleGroups.isEmpty {
                VStack {
                    Image(systemName: "iphone.and.arrow.forward").font(.largeTitle).foregroundColor(.green)
                    Text("Bitte öffne kurz die App auf dem iPhone, um deine Daten zu laden.")
                        .font(.caption).multilineTextAlignment(.center).padding()
                }
            } else {
                Form {
                    // HR display when workout session is active
                    if workoutManager.isRunning {
                        Section {
                            HStack {
                                Image(systemName: "heart.fill").foregroundColor(.red)
                                if workoutManager.currentHR > 0 {
                                    Text("\(Int(workoutManager.currentHR)) bpm")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(.red)
                                } else {
                                    Text("-- bpm").foregroundColor(.gray)
                                }
                                Spacer()
                                Text(formatElapsed(workoutManager.elapsedSeconds))
                                    .font(.caption2).foregroundColor(.green)
                            }
                        }
                    }

                    Section {
                        Picker("Kategorie", selection: $selectedCategory) {
                            ForEach(sync.muscleGroups, id: \.self) { group in Text(group).tag(group) }
                        }
                        .onChange(of: selectedCategory) { _, newCat in
                            let machs = sync.machines.filter { $0["muscleGroup"] == newCat }.compactMap { $0["name"] }
                            selectedMachine = machs.first ?? ""
                            if newCat.lowercased() == "cardio" { weight = 15.0; reps = 5 }
                        }
                    }

                    if !availableMachines.isEmpty {
                        Section {
                            Picker("Gerät", selection: $selectedMachine) {
                                ForEach(availableMachines, id: \.self) { m in Text(m).tag(m) }
                            }
                        }

                        Section(isCardio ? "Dauer (min)" : "Gewicht (kg)") {
                            Stepper("\(weight, specifier: "%.1f")", value: $weight,
                                    in: 0...500, step: isCardio ? 5.0 : 2.5)
                                .foregroundColor(.green)
                        }

                        Section(isCardio ? "Level / km/h" : "Wiederholungen") {
                            Stepper("\(reps)", value: $reps, in: 1...100, step: 1)
                                .foregroundColor(.blue)
                        }

                        Button(action: saveSet) {
                            HStack { Spacer(); Text("Satz speichern").bold(); Spacer() }
                        }
                        .tint(.green)

                        if workoutManager.isRunning {
                            Button(action: { workoutManager.stop() }) {
                                HStack {
                                    Spacer()
                                    Label("Training beenden", systemImage: "stop.circle.fill")
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                            }
                            .tint(.red)
                        }
                    } else {
                        Text("Keine Geräte angelegt.").font(.caption).foregroundColor(.gray)
                    }
                }
            }

            if showSaved {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60)).foregroundColor(.green)
                    Text("Gespeichert!").font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.85))
                .transition(.scale)
            }
        }
    }

    func saveSet() {
        guard !selectedMachine.isEmpty else { return }
        sync.sendSet(machine: selectedMachine, weight: weight, reps: reps)
        if !workoutManager.isRunning { workoutManager.start() }
        WKInterfaceDevice.current().play(.success)
        withAnimation { showSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { showSaved = false } }
    }

    func formatElapsed(_ s: Int) -> String {
        let m = (s % 3600) / 60, sec = s % 60
        return String(format: "%02d:%02d", m, sec)
    }
}
