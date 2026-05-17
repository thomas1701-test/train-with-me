import SwiftUI

struct BodyStatsView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedTab = 0
    @State private var weightInput = ""; @State private var waistInput = ""
    @State private var fatInput = "";    @State private var bicepsInput = ""
    @State private var chestInput = "";  @State private var thighInput = ""
    @State private var sysInput = "";    @State private var diaInput = ""
    @State private var msg = ""

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            VStack {
                Picker("Ansicht", selection: $selectedTab) {
                    Text("Eintragen").tag(0); Text("Verlauf").tag(1)
                }.pickerStyle(SegmentedPickerStyle()).padding()
                .onAppear { UISegmentedControl.appearance().selectedSegmentTintColor = .white.withAlphaComponent(0.3) }

                if selectedTab == 0 {
                    ScrollView {
                        VStack(spacing: 20) {
                            GlassSection(title: "Allgemein") {
                                StatInputRow(title: "Gewicht (kg)", text: $weightInput)
                                StatInputRow(title: "Körperfett (%)", text: $fatInput)
                            }
                            GlassSection(title: "Umfänge (cm)") {
                                StatInputRow(title: "Bauch",  text: $waistInput)
                                StatInputRow(title: "Brust",  text: $chestInput)
                                StatInputRow(title: "Bizeps", text: $bicepsInput)
                                StatInputRow(title: "Bein",   text: $thighInput)
                            }
                            Button(action: saveMeasurements) {
                                Text("Werte speichern").bold().frame(maxWidth: .infinity).padding()
                                    .background(viewModel.currentTheme.accentColor.gradient).cornerRadius(10).foregroundColor(.white)
                            }
                            if viewModel.bloodPressureEnabled {
                                GlassSection(title: "Blutdruck") {
                                    HStack {
                                        TextField("Sys", text: $sysInput).keyboardType(.numberPad).foregroundColor(.white)
                                        Text("/").foregroundColor(.white)
                                        TextField("Dia", text: $diaInput).keyboardType(.numberPad).foregroundColor(.white)
                                    }
                                    Button("Speichern") { saveBloodPressure() }
                                        .font(.caption).foregroundColor(viewModel.currentTheme.accentColor)
                                }
                            }
                            if !msg.isEmpty { Text(msg).foregroundColor(.green).bold() }
                        }.padding()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            BodyChart(title: "Gewicht (kg)",     data: viewModel.health.weightHistory,  color: .blue)
                            BodyChart(title: "Körperfett (%)",   data: viewModel.health.bodyFatHistory, color: .purple)
                            BodyChart(title: "Bauch (cm)",       data: viewModel.health.waistHistory,   color: .orange)
                            BodyChart(title: "Brust (cm)",       data: viewModel.health.chestHistory,   color: .red)
                            BodyChart(title: "Bizeps (cm)",      data: viewModel.health.bicepsHistory,  color: .green)
                            BodyChart(title: "Bein (cm)",        data: viewModel.health.thighHistory,   color: .yellow)
                        }.padding()
                    }
                }
            }
        }
        .navigationTitle("Körper")
        .toolbar { Button("Fertig") { presentationMode.wrappedValue.dismiss() } }
        .onAppear { viewModel.health.refreshFromHealthKit(); if viewModel.health.currentWeight > 0 { weightInput = String(format: "%.1f", viewModel.health.currentWeight) } }
    }

    func saveMeasurements() {
        let parse: (String) -> Double? = { Double($0.replacingOccurrences(of: ",", with: ".")) }
        viewModel.health.addMeasurement(weight: parse(weightInput), waist: parse(waistInput), fat: parse(fatInput),
                                        biceps: parse(bicepsInput), chest: parse(chestInput), thigh: parse(thighInput),
                                        healthKitEnabled: viewModel.healthKitEnabled)
        msg = "Gespeichert!"
        weightInput = ""; waistInput = ""; fatInput = ""; bicepsInput = ""; chestInput = ""; thighInput = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { msg = "" }
    }

    func saveBloodPressure() {
        guard let s = Double(sysInput), let d = Double(diaInput) else { return }
        viewModel.saveBloodPressure(systolic: s, diastolic: d)
        msg = "Gespeichert!"; sysInput = ""; diaInput = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { msg = "" }
    }
}
