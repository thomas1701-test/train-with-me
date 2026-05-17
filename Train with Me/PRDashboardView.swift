import SwiftUI

struct PRDashboardView: View {
    var viewModel: AppViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedGroup = "Alle"

    var groups: [String] { ["Alle"] + viewModel.training.muscleGroupNames() }

    var filteredRecords: [PersonalRecord] {
        selectedGroup == "Alle"
            ? viewModel.training.personalRecords
            : viewModel.training.personalRecords.filter { $0.muscleGroup == selectedGroup }
    }

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🏆 Persönliche Rekorde").font(.title2.bold()).foregroundColor(.white)
                        Text("\(viewModel.training.personalRecords.count) Übungen | \(viewModel.training.totalTrainingDays) Trainingstage")
                            .font(.caption).foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Button("Schließen") { presentationMode.wrappedValue.dismiss() }.foregroundColor(.white)
                }.padding()

                // Streak Banner
                if viewModel.training.currentStreak > 0 {
                    HStack(spacing: 12) {
                        Text("🔥").font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(viewModel.training.currentStreak) Tage Streak").font(.headline).foregroundColor(.white)
                            Text("Bester Streak: \(viewModel.training.longestStreak) Tage").font(.caption).foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        Text("\(viewModel.training.totalTrainingDays) Trainings")
                            .font(.caption).foregroundColor(.white.opacity(0.6))
                    }
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.4), lineWidth: 1))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                // Gruppen-Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(groups, id: \.self) { g in
                            Button(action: { selectedGroup = g }) {
                                Text(g).font(.caption).padding(.horizontal, 14).padding(.vertical, 6)
                                    .background(selectedGroup == g ? viewModel.currentTheme.accentColor : Color.white.opacity(0.1))
                                    .foregroundColor(.white).cornerRadius(20)
                            }
                        }
                    }.padding(.horizontal)
                }.padding(.bottom, 8)

                // Rekorde
                if filteredRecords.isEmpty {
                    Spacer()
                    Text("Noch keine Daten für \(selectedGroup)").foregroundColor(.gray)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(filteredRecords.enumerated()), id: \.element.id) { index, pr in
                                PRRow(pr: pr, rank: index + 1, accentColor: viewModel.currentTheme.accentColor)
                            }
                        }.padding(.horizontal)
                    }
                }
            }
        }
    }
}

struct PRRow: View {
    let pr: PersonalRecord
    let rank: Int
    let accentColor: Color

    var rankEmoji: String {
        switch rank { case 1: return "🥇"; case 2: return "🥈"; case 3: return "🥉"; default: return "\(rank)." }
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(rankEmoji).font(.title2).frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(pr.machineName).font(.headline).foregroundColor(.white)
                Text(pr.muscleGroup).font(.caption).foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundColor(accentColor).font(.caption)
                    Text("1RM: \(Int(pr.bestOneRepMax)) kg").font(.headline).foregroundColor(.white)
                }
                Text("Max: \(formatWeight(pr.maxWeight)) kg × \(pr.maxReps)")
                    .font(.caption).foregroundColor(.white.opacity(0.6))
                Text(pr.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2).foregroundColor(.white.opacity(0.4))
            }
        }
        .padding()
        .glassStyle()
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
    }
}//
//  PRDashboardView.swift
//  Train with Me
//
//  Created by Thomas on 10.05.26.
//

