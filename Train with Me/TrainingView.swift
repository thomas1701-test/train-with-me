import SwiftUI
import Charts
import ActivityKit

struct TrainingView: View {
    var viewModel: AppViewModel
    let machine: Machine

    @State private var weight = ""
    @State private var reps = ""
    @State private var notesInput = ""
    @State private var showPRAnimation = false
    @State private var showSavedPopup = false
    @State private var showingImagePicker = false
    @State private var newImage: UIImage?
    @State private var selectedMetric: ChartMetric = .oneRepMax
    @State private var timerActive = false
    @State private var timeRemaining = 0.0
    @State private var totalTime = 0.0
    @State private var liveActivity: Activity<TimerAttributes>? = nil
    @State private var showingRenameAlert = false
    @State private var newMachineName = ""
    @State private var selectedSetIDForIntensity: UUID? = nil
    @State private var editRPE: Int = 7
    @State private var editRIR: Int = 2

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var currentMachine: Machine { viewModel.training.machines.first(where: { $0.id == machine.id }) ?? machine }
    var isCardio: Bool { currentMachine.muscleGroup.lowercased() == "cardio" }

    var chartData: [ChartDataPoint] {
        let grouped = Dictionary(grouping: currentMachine.sets) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.map { (key, value) -> ChartDataPoint in
            let val: Double
            switch selectedMetric {
            case .maxWeight: val = value.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.max() ?? 0
            case .oneRepMax: val = value.map { $0.oneRepMax }.max() ?? 0
            case .volume:    val = value.reduce(0) { $0 + $1.volume }
            }
            return ChartDataPoint(date: key, value: val)
        }.sorted { $0.date < $1.date }
    }

    // Feature 1+6: Overload-Vorschlag
    var overloadSuggestion: OverloadSuggestion? {
        isCardio ? nil : viewModel.training.progressiveOverloadSuggestion(for: currentMachine.id)
    }

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            VStack {
                ZStack(alignment: .topTrailing) {
                    CachedAsyncImage(fileName: currentMachine.imageFileName) { image in
                        image.resizable().scaledToFill().frame(height: 200).clipped()
                    } placeholder: {
                        Rectangle().fill(Color.white.opacity(0.15)).frame(height: 200)
                    }
                    Button(action: { showingImagePicker = true }) {
                        Image(systemName: "photo.circle.fill").font(.largeTitle).foregroundColor(.white).shadow(radius: 3)
                    }.padding()
                    if timerActive {
                        HStack {
                            Text("Pause: \(Int(timeRemaining))s").bold()
                            Spacer()
                            ProgressView(value: timeRemaining, total: totalTime).tint(.white)
                        }.padding().background(.ultraThinMaterial).cornerRadius(10).padding()
                    }
                }

                ScrollView {
                    VStack(spacing: 20) {
                        // Notizen
                        VStack(alignment: .leading) {
                            Text("Notizen").font(.caption).foregroundColor(.white)
                            TextField("Einstellungen...", text: $notesInput, onCommit: {
                                viewModel.training.updateMachineNotes(machineId: currentMachine.id, notes: notesInput)
                            })
                            .textFieldStyle(.plain).padding(10)
                            .background(Color.white.opacity(0.1)).cornerRadius(10).foregroundColor(.white)
                        }.padding(.horizontal).onAppear { notesInput = currentMachine.notes }

                        // Chart
                        if chartData.count >= 2 {
                            VStack {
                                Picker("", selection: $selectedMetric) {
                                    ForEach(ChartMetric.allCases) { m in Text(m.rawValue).tag(m) }
                                }.pickerStyle(SegmentedPickerStyle()).onAppear {
                                    UISegmentedControl.appearance().selectedSegmentTintColor = .white.withAlphaComponent(0.3)
                                }
                                Chart(chartData) { point in
                                    AreaMark(x: .value("Datum", point.date), y: .value("Wert", point.value))
                                        .foregroundStyle(LinearGradient(colors: [viewModel.currentTheme.accentColor.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom))
                                    LineMark(x: .value("Datum", point.date), y: .value("Wert", point.value))
                                        .foregroundStyle(viewModel.currentTheme.accentColor).interpolationMethod(.catmullRom)
                                }
                                .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(.white) } }
                                .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(.white) } }
                                .frame(height: 150)
                            }.padding().glassStyle().padding(.horizontal)
                        }

                        if let s = overloadSuggestion {
                            InsightBanner(emoji: "💡", title: "Progression", message: s.message, color: .yellow)
                                .padding(.horizontal)
                        }

                        // Eingabe
                        HStack {
                            TextField(isCardio ? "min" : "kg", text: $weight)
                                .keyboardType(.decimalPad).multilineTextAlignment(.center).padding()
                                .background(Color.white.opacity(0.1)).cornerRadius(10).foregroundColor(.white)
                            TextField(isCardio ? "Level / Kcal" : "Wdh", text: $reps)
                                .keyboardType(.decimalPad).multilineTextAlignment(.center).padding()
                                .background(Color.white.opacity(0.1)).cornerRadius(10).foregroundColor(.white)
                            Button(action: addSetAction) {
                                Image(systemName: "plus").font(.title).foregroundColor(.white).padding()
                                    .background(viewModel.currentTheme.accentColor).clipShape(Circle())
                            }
                        }.padding(.horizontal)

                        // Intensitäts-Durchschnitt
                        if let avg = viewModel.training.averageIntensity(for: currentMachine.id) {
                            IntensityAverageBanner(score: avg).padding(.horizontal)
                        }

                        // Sätze
                        ForEach(currentMachine.sets.sorted(by: { $0.date > $1.date })) { set in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(set.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundColor(.gray)
                                    HStack {
                                        if isCardio {
                                            let displayMin  = set.duration.map { String(format: "%.1f", $0) } ?? set.weight
                                            let displayKcal = set.calories.map { String(format: "%.0f", $0) } ?? set.reps
                                            Text("\(displayMin) min").bold()
                                            Text("| \(displayKcal) Kcal").bold()
                                        } else {
                                            Text("\(set.weight) kg").bold()
                                            Text("x \(set.reps)").bold()
                                        }
                                    }.foregroundColor(.white)
                                }
                                Spacer()
                                if !isCardio { Text("1RM: \(Int(set.oneRepMax))").font(.caption).foregroundColor(viewModel.currentTheme.accentColor) }
                                Button(action: {
                                    editRPE = set.rpe ?? 7
                                    editRIR = set.rir ?? 2
                                    selectedSetIDForIntensity = set.id
                                }) {
                                    Circle()
                                        .fill(intensityColor(score: set.intensityScore))
                                        .frame(width: 14, height: 14)
                                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                }.buttonStyle(.plain)
                            }
                            .padding().glassStyle().padding(.horizontal)
                            .contextMenu { Button("Löschen", role: .destructive) { viewModel.training.deleteSet(machineId: currentMachine.id, setId: set.id) } }
                        }
                    }
                }
            }

            if showSavedPopup {
                Image(systemName: "checkmark").font(.system(size: 60)).foregroundColor(.white)
                    .padding(40).background(.ultraThinMaterial).cornerRadius(20).transition(.scale).zIndex(10)
            }
            if showPRAnimation {
                Text("NEW RECORD! 🏆").font(.largeTitle.bold()).foregroundColor(.yellow)
                    .shadow(color: .orange, radius: 10).padding().background(.ultraThinMaterial)
                    .cornerRadius(20).transition(.scale).zIndex(11)
            }
        }
        .navigationTitle(currentMachine.name).navigationBarTitleDisplayMode(.inline)
        .toolbar { Button(action: { newMachineName = currentMachine.name; showingRenameAlert = true }) { Image(systemName: "pencil") } }
        .alert("Gerät umbenennen", isPresented: $showingRenameAlert) {
            TextField("Neuer Name", text: $newMachineName)
            Button("Speichern") { if !newMachineName.isEmpty { viewModel.training.renameMachine(machineId: currentMachine.id, newName: newMachineName) } }
            Button("Abbrechen", role: .cancel) { }
        }
        .sheet(isPresented: $showingImagePicker) { ImagePicker(image: $newImage) }
        .sheet(isPresented: Binding(get: { selectedSetIDForIntensity != nil }, set: { if !$0 { selectedSetIDForIntensity = nil } })) {
            IntensitySheet(rpe: $editRPE, rir: $editRIR) {
                if let id = selectedSetIDForIntensity {
                    viewModel.training.updateSetIntensity(machineId: currentMachine.id, setId: id, rpe: editRPE, rir: editRIR)
                }
                selectedSetIDForIntensity = nil
            }
        }
        .onChange(of: newImage) { _, img in if let i = img { viewModel.training.updateMachineImage(machineId: currentMachine.id, newImage: i) } }
        .onReceive(timer) { _ in
            guard timerActive else { return }
            if timeRemaining > 0 {
                timeRemaining -= 1
                Task { let s = TimerAttributes.ContentState(timeRemaining: Int(timeRemaining)); await liveActivity?.update(using: s) }
            } else {
                timerActive = false
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                NotificationManager.shared.scheduleTimerNotification(seconds: 0.1)
                Task { let s = TimerAttributes.ContentState(timeRemaining: 0); await liveActivity?.end(using: s, dismissalPolicy: .immediate) }
            }
        }
        .onDisappear { Task { let s = TimerAttributes.ContentState(timeRemaining: Int(timeRemaining)); await liveActivity?.end(using: s, dismissalPolicy: .immediate) } }
    }

    private func intensityColor(score: Double?) -> Color {
        guard let s = score else { return Color.white.opacity(0.25) }
        if s < 0.4 { return .green }
        if s < 0.7 { return .orange }
        return .red
    }

    func addSetAction() {
        if !viewModel.isWorkoutActive { viewModel.startWorkout() }
        let isPR: Bool
        if isCardio {
            let dur  = Double(weight.replacingOccurrences(of: ",", with: ".")) ?? 0
            let kcal = Double(reps.replacingOccurrences(of: ",", with: ".")) ?? 0
            viewModel.training.addCardioSet(machineId: currentMachine.id, duration: dur, calories: kcal)
            isPR = false
        } else {
            isPR = viewModel.training.addSet(machineId: currentMachine.id, weight: weight, reps: reps)
        }
        if viewModel.timerEnabled {
            totalTime = viewModel.timerDuration; timeRemaining = viewModel.timerDuration; timerActive = true
            NotificationManager.shared.scheduleTimerNotification(seconds: viewModel.timerDuration)
            if ActivityAuthorizationInfo().areActivitiesEnabled {
                let attr  = TimerAttributes(totalTime: Int(totalTime))
                let state = TimerAttributes.ContentState(timeRemaining: Int(timeRemaining))
                do { liveActivity = try Activity.request(attributes: attr, content: .init(state: state, staleDate: nil), pushType: nil) }
                catch { print("Live Activity Fehler: \(error)") }
            }
        }
        withAnimation { showSavedPopup = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { withAnimation { showSavedPopup = false } }
        if isPR {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation { showPRAnimation = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { withAnimation { showPRAnimation = false } }
        } else { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }
}

// MARK: - Intensity Average Banner

struct IntensityAverageBanner: View {
    let score: Double
    var color: Color { score < 0.4 ? .green : score < 0.7 ? .orange : .red }
    var label: String { score < 0.4 ? "Niedrig" : score < 0.7 ? "Moderat" : "Hoch" }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Ø Intensität (letzte 4 Sessions)").font(.caption).foregroundColor(.gray)
                Spacer()
                Text(label).font(.caption.bold()).foregroundColor(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.1)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(color)
                        .frame(width: geo.size.width * score, height: 6)
                        .animation(.easeInOut, value: score)
                }
            }.frame(height: 6)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Intensity Sheet

struct IntensitySheet: View {
    @Binding var rpe: Int
    @Binding var rir: Int
    let onSave: () -> Void

    var intensityScore: Double { (Double(rpe) / 10.0 + Double(5 - rir) / 5.0) / 2.0 }
    var intensityColor: Color { intensityScore < 0.4 ? .green : intensityScore < 0.7 ? .orange : .red }
    var rpeHint: String {
        switch rpe {
        case 10: return "Maximale Anstrengung — kein Reserve"
        case 9:  return "Fast maximal — noch ~1 Wdh möglich"
        case 8:  return "Sehr schwer — 2 Wdh Reserve"
        case 7:  return "Schwer — 3 Wdh Reserve"
        case 6:  return "Moderat-schwer"
        default: return "Leicht bis moderat"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Satz-Intensität").font(.headline).padding(.top, 20)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)).frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [.green, .orange, .red], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * intensityScore, height: 10)
                        .animation(.easeInOut, value: intensityScore)
                }
            }.frame(height: 10).padding(.horizontal)

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("RPE (Anstrengung)").font(.subheadline.bold())
                        Spacer()
                        Text("\(rpe)/10").font(.title3.bold()).foregroundColor(intensityColor)
                    }
                    Stepper("", value: $rpe, in: 1...10).labelsHidden()
                    Text(rpeHint).font(.caption).foregroundColor(.secondary)
                }
                .padding().background(Color(.secondarySystemBackground)).cornerRadius(12)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("RIR (Reserve)").font(.subheadline.bold())
                        Spacer()
                        Text("\(rir)").font(.title3.bold()).foregroundColor(intensityColor)
                    }
                    Stepper("", value: $rir, in: 0...5).labelsHidden()
                    Text(rir == 0 ? "Komplett ausbelastet" : "\(rir) weitere Wdh wären möglich").font(.caption).foregroundColor(.secondary)
                }
                .padding().background(Color(.secondarySystemBackground)).cornerRadius(12)
            }.padding(.horizontal)

            Button(action: onSave) {
                Text("Speichern").font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(intensityColor).cornerRadius(16)
            }.padding(.horizontal).padding(.bottom, 10)
        }
        .presentationDetents([.height(390)])
        .presentationDragIndicator(.visible)
    }
}
