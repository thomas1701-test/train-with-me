import SwiftUI
import WatchKit
import Combine
import WatchConnectivity

class WatchSync: NSObject, WCSessionDelegate, ObservableObject {
    @Published var muscleGroups: [String] = []
    @Published var machines: [[String: String]] = []
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            if let groups = applicationContext["muscleGroups"] as? [String] { self.muscleGroups = groups }
            if let machs = applicationContext["machines"] as? [[String: String]] { self.machines = machs }
        }
    }
    
    func sendSet(machine: String, weight: Double, reps: Int) {
        let data: [String: Any] = [
            "action": "addSet",
            "machineName": machine,
            "weight": String(format: "%.1f", weight).replacingOccurrences(of: ".", with: ","),
            "reps": String(reps)
        ]
        WCSession.default.transferUserInfo(data)
    }
}

struct ContentView: View {
    @StateObject var sync = WatchSync()
    
    @State private var selectedCategory = ""
    @State private var selectedMachine = ""
    @State private var weight: Double = 50.0
    @State private var reps: Int = 10
    @State private var showSaved = false
    
    var availableMachines: [String] {
        sync.machines.filter { $0["muscleGroup"] == selectedCategory }.compactMap { $0["name"] }
    }
    
    // Check, ob wir im Cardio-Modus sind
    var isCardio: Bool {
        selectedCategory.lowercased() == "cardio"
    }
    
    var body: some View {
        ZStack {
            if sync.muscleGroups.isEmpty {
                VStack {
                    Image(systemName: "iphone.and.arrow.forward").font(.largeTitle).foregroundColor(.green)
                    Text("Bitte öffne kurz die App auf dem iPhone, um deine Daten zu laden.").font(.caption).multilineTextAlignment(.center).padding()
                }
            } else {
                Form {
                    Section {
                        Picker("Kategorie", selection: $selectedCategory) {
                            ForEach(sync.muscleGroups, id: \.self) { group in Text(group).tag(group) }
                        }
                        .onChange(of: selectedCategory) { _, newCat in
                            let machs = sync.machines.filter { $0["muscleGroup"] == newCat }.compactMap { $0["name"] }
                            selectedMachine = machs.first ?? ""
                            
                            // Standardwerte anpassen, wenn man auf Cardio wechselt
                            if newCat.lowercased() == "cardio" {
                                weight = 15.0 // 15 Minuten
                                reps = 5      // Stufe 5
                            }
                        }
                    }
                    
                    if !availableMachines.isEmpty {
                        Section {
                            Picker("Gerät", selection: $selectedMachine) {
                                ForEach(availableMachines, id: \.self) { m in Text(m).tag(m) }
                            }
                        }
                        
                        // DYNAMISCHE FELDER FÜR CARDIO ODER GEWICHTE
                        Section(isCardio ? "Dauer (min)" : "Gewicht (kg)") {
                            Stepper("\(weight, specifier: "%.1f")", value: $weight, in: 0...500, step: isCardio ? 5.0 : 2.5)
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
                    } else {
                        Text("Keine Geräte angelegt.").font(.caption).foregroundColor(.gray)
                    }
                }
            }
            
            if showSaved {
                VStack {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 60)).foregroundColor(.green)
                    Text("Gespeichert!").font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.85))
                .transition(.scale)
            }
        }
        .onAppear {
            if let firstGroup = sync.muscleGroups.first {
                selectedCategory = firstGroup
                let machs = sync.machines.filter { $0["muscleGroup"] == firstGroup }.compactMap { $0["name"] }
                selectedMachine = machs.first ?? ""
            }
        }
        .onChange(of: sync.muscleGroups) { _, groups in
            if selectedCategory.isEmpty, let firstGroup = groups.first { selectedCategory = firstGroup }
        }
        .onChange(of: sync.machines) { _, _ in
            if selectedMachine.isEmpty, let firstMach = availableMachines.first { selectedMachine = firstMach }
        }
    }
    
    func saveSet() {
        if !selectedMachine.isEmpty {
            sync.sendSet(machine: selectedMachine, weight: weight, reps: reps)
            WKInterfaceDevice.current().play(.success)
            withAnimation { showSaved = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { showSaved = false } }
        }
    }
}
