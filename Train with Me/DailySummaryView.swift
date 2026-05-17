import SwiftUI

struct DailySummaryView: View {
    var viewModel: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var aiText: String = ""
    @State private var isGenerating = false

    private let cal = Calendar.current

    // MARK: - Today's Data

    var todayMachines: [(machine: Machine, sets: [ExerciseSet])] {
        viewModel.training.machines.compactMap { m in
            let s = m.sets.filter { cal.isDateInToday($0.date) }
            return s.isEmpty ? nil : (m, s)
        }
    }

    var totalVolume: Double {
        let strengthMachines = todayMachines.filter { $0.machine.muscleGroup.lowercased() != "cardio" }
        let sets = strengthMachines.flatMap { $0.sets }.filter { $0.duration == nil }
        return sets.reduce(0) { $0 + $1.volume }
    }

    var totalSets: Int {
        todayMachines.flatMap { $0.sets }.count
    }

    var muscles: [String] {
        Array(Set(todayMachines.map { $0.machine.muscleGroup })).sorted()
    }

    var workoutDuration: String {
        guard let start = viewModel.workoutStartDate else { return "--" }
        let min = Int(Date().timeIntervalSince(start) / 60)
        return "\(min) min"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tageszusammenfassung").font(.title2.bold()).foregroundColor(.white)
                        Text(formattedToday()).font(.caption).foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    Button("Fertig") { dismiss() }.foregroundColor(.white)
                }.padding()

                if todayMachines.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 48)).foregroundColor(.white.opacity(0.3))
                        Text("Noch kein Training heute").font(.headline).foregroundColor(.white.opacity(0.6))
                        Text("Starte ein Training und komm abends zurück.")
                            .font(.caption).foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }.padding()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            statsGrid
                            exerciseList
                            aiSection
                        }.padding()
                    }
                }
            }
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        GlassSection(title: "Heutiger Überblick") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCell(icon: "dumbbell.fill",    label: "Volumen",    value: "\(Int(totalVolume)) kg", color: .green)
                StatCell(icon: "list.number",      label: "Sätze",      value: "\(totalSets)",          color: .blue)
                StatCell(icon: "flame.fill",       label: "Kalorien",   value: kcalText,                color: .orange)
                StatCell(icon: "heart.fill",       label: "Ø Herzfrq.", value: hrText,                  color: .red)
            }
            if !muscles.isEmpty {
                Divider().background(Color.white.opacity(0.15))
                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption).foregroundColor(.white.opacity(0.4))
                    Text(muscles.joined(separator: "  ·  "))
                        .font(.caption).foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
        }
    }

    private var kcalText: String {
        let k = viewModel.health.lastWorkoutKcal
        return k > 0 ? "\(Int(k)) kcal" : "--"
    }

    private var hrText: String {
        if let hr = viewModel.health.lastWorkoutAvgHR { return "\(Int(hr)) bpm" }
        return "--"
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        GlassSection(title: "Übungen") {
            VStack(spacing: 10) {
                ForEach(todayMachines, id: \.machine.id) { item in
                    HStack(alignment: .top, spacing: 12) {
                        let isCardio = item.machine.muscleGroup.lowercased() == "cardio"
                        Image(systemName: isCardio ? "figure.run" : "dumbbell.fill")
                            .font(.caption).foregroundColor(.white.opacity(0.5))
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.machine.name)
                                .font(.subheadline.bold()).foregroundColor(.white)
                            Text(setsSummary(item.sets, isCardio: isCardio))
                                .font(.caption).foregroundColor(.white.opacity(0.6))
                                .lineLimit(2)
                        }
                        Spacer()
                        if isCardio {
                            let totalMin = item.sets.compactMap { $0.duration }.reduce(0, +)
                            if totalMin > 0 {
                                Text("\(Int(totalMin)) min")
                                    .font(.caption.bold()).foregroundColor(.orange)
                            }
                        } else {
                            let vol = item.sets.filter { $0.duration == nil }.reduce(0) { $0 + $1.volume }
                            if vol > 0 {
                                Text("\(Int(vol)) kg")
                                    .font(.caption.bold()).foregroundColor(.green)
                            }
                        }
                    }
                    if item.machine.id != todayMachines.last?.machine.id {
                        Divider().background(Color.white.opacity(0.1))
                    }
                }
            }
        }
    }

    private func setsSummary(_ sets: [ExerciseSet], isCardio: Bool = false) -> String {
        if isCardio {
            let totalMin = sets.compactMap { $0.duration }.reduce(0, +)
            let kcal = sets.compactMap { $0.calories }.reduce(0, +)
            var parts: [String] = []
            if totalMin > 0 { parts.append("\(Int(totalMin)) min") }
            if kcal > 0 { parts.append("\(Int(kcal)) kcal") }
            return parts.joined(separator: "  ·  ")
        }
        let strength = sets.filter { $0.duration == nil }
        let timed    = sets.filter { $0.duration != nil }
        var parts: [String] = []
        if !strength.isEmpty {
            let maxW = strength.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.max() ?? 0
            if maxW > 0 { parts.append("\(strength.count) Sätze · Max \(maxW.formatted()) kg") }
            else { parts.append("\(strength.count) Sätze") }
        }
        if !timed.isEmpty {
            let best = timed.compactMap { $0.duration }.max() ?? 0
            let sec = Int(best)
            parts.append("Best: \(sec < 60 ? "\(sec)s" : "\(sec/60):\(String(format: "%02d", sec%60)) min")")
        }
        return parts.joined(separator: "  ·  ")
    }

    // MARK: - AI Section

    private var aiSection: some View {
        GlassSection(title: "KI-Motivation") {
            VStack(spacing: 12) {
                if aiText.isEmpty && !isGenerating {
                    Button(action: generateAISummary) {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                            Text("Zusammenfassung generieren")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(12)
                    }
                } else if isGenerating {
                    HStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("Analysiere dein Training…").font(.caption).foregroundColor(.white.opacity(0.6))
                    }.frame(maxWidth: .infinity)
                } else {
                    Text(aiText)
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.easeIn, value: aiText)

                    Button(action: generateAISummary) {
                        Label("Neu generieren", systemImage: "arrow.clockwise")
                            .font(.caption).foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func generateAISummary() {
        guard !isGenerating else { return }
        isGenerating = true
        aiText = ""
        Task {
            let result = await viewModel.gemini.generateDailySummary(
                todayData: todayMachines,
                totalVolume: totalVolume,
                muscles: muscles,
                streak: viewModel.training.currentStreak,
                avgHR: viewModel.health.lastWorkoutAvgHR,
                kcal: viewModel.health.lastWorkoutKcal > 0 ? viewModel.health.lastWorkoutKcal : nil
            )
            await MainActor.run {
                aiText = result
                isGenerating = false
            }
        }
    }

    private func formattedToday() -> String {
        let f = DateFormatter()
        f.dateStyle = .full
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: Date())
    }
}

// MARK: - Stat Cell

struct StatCell: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.6), radius: 4)
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
            }
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            ZStack {
                color.opacity(0.08)
                LinearGradient(colors: [.white.opacity(0.05), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        )
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2), lineWidth: 1))
    }
}
