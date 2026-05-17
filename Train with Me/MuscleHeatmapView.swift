import SwiftUI

struct MuscleHeatmapView: View {
    var viewModel: AppViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showFront = true

    func heatLevel(for muscle: String) -> Double {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        var vols: [String: Double] = [:]
        for m in viewModel.training.machines {
            vols[m.muscleGroup, default: 0] += m.sets.filter { $0.date >= sevenDaysAgo }.reduce(0) { $0 + $1.volume }
        }
        let maxVol = vols.values.max() ?? 1
        return (vols[muscle] ?? 0) / max(maxVol, 1)
    }

    func heatColor(level: Double) -> Color {
        if level == 0   { return Color.white.opacity(0.1) }
        if level < 0.3  { return .yellow }
        if level < 0.7  { return .orange }
        return .red
    }

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            VStack {
                Picker("Ansicht", selection: $showFront) {
                    Text("Vorderseite").tag(true); Text("Rückseite").tag(false)
                }.pickerStyle(SegmentedPickerStyle()).padding()
                .onAppear { UISegmentedControl.appearance().selectedSegmentTintColor = .white.withAlphaComponent(0.3) }

                Spacer()

                if showFront {
                    VStack(spacing: 5) {
                        Circle().fill(Color.white.opacity(0.1)).frame(width: 50, height: 50)
                        Capsule().fill(heatColor(level: heatLevel(for: "Schultern"))).frame(width: 140, height: 30)
                        HStack(spacing: 10) {
                            Capsule().fill(heatColor(level: heatLevel(for: "Arme"))).frame(width: 30, height: 120)
                            VStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 10).fill(heatColor(level: heatLevel(for: "Brust"))).frame(width: 70, height: 60)
                                RoundedRectangle(cornerRadius: 10).fill(heatColor(level: heatLevel(for: "Bauch"))).frame(width: 60, height: 55)
                            }
                            Capsule().fill(heatColor(level: heatLevel(for: "Arme"))).frame(width: 30, height: 120)
                        }
                        HStack(spacing: 10) {
                            Capsule().fill(heatColor(level: heatLevel(for: "Beine"))).frame(width: 35, height: 140)
                            Capsule().fill(heatColor(level: heatLevel(for: "Beine"))).frame(width: 35, height: 140)
                        }
                    }
                } else {
                    VStack(spacing: 5) {
                        Circle().fill(Color.white.opacity(0.1)).frame(width: 50, height: 50)
                        Capsule().fill(heatColor(level: heatLevel(for: "Schultern"))).frame(width: 140, height: 30)
                        HStack(spacing: 10) {
                            Capsule().fill(heatColor(level: heatLevel(for: "Arme"))).frame(width: 30, height: 120)
                            RoundedRectangle(cornerRadius: 10).fill(heatColor(level: heatLevel(for: "Rücken"))).frame(width: 70, height: 120)
                            Capsule().fill(heatColor(level: heatLevel(for: "Arme"))).frame(width: 30, height: 120)
                        }
                        HStack(spacing: 10) {
                            Capsule().fill(heatColor(level: heatLevel(for: "Beine"))).frame(width: 35, height: 140)
                            Capsule().fill(heatColor(level: heatLevel(for: "Beine"))).frame(width: 35, height: 140)
                        }
                    }
                }

                Spacer()

                HStack {
                    Circle().fill(Color.white.opacity(0.1)).frame(width: 15, height: 15); Text("Erholt").font(.caption).foregroundColor(.gray)
                    Spacer()
                    Circle().fill(Color.yellow).frame(width: 15, height: 15); Text("Leicht").font(.caption).foregroundColor(.gray)
                    Spacer()
                    Circle().fill(Color.red).frame(width: 15, height: 15); Text("Zerstört").font(.caption).foregroundColor(.gray)
                }.padding().glassStyle().padding()
            }
        }.navigationTitle("Heatmap (7 Tage)").toolbar { Button("Fertig") { presentationMode.wrappedValue.dismiss() } }
    }
}//
//  MuscleHeatmapView.swift
//  Train with Me
//
//  Created by Thomas on 09.05.26.
//

