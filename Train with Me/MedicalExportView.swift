import SwiftUI
import HealthKit

// MARK: - Data Transfer Object

struct ReportWorkout: Identifiable {
    let id = UUID()
    let date: Date
    let activityName: String
    let durationMinutes: Double
    let calories: Double
}

// MARK: - Export UI

struct MedicalExportView: View {
    var viewModel: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var startDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var endDate   = Date()
    @State private var isGenerating = false
    @State private var pdfURL: URL? = nil
    @State private var externalWorkouts: [ReportWorkout] = []

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            VStack(spacing: 0) {
                HStack {
                    Text("Arztbericht").font(.title2.bold()).foregroundColor(.white)
                    Spacer()
                    Button("Schließen") { dismiss() }.foregroundColor(.white)
                }.padding()

                ScrollView {
                    VStack(spacing: 20) {
                        GlassSection(title: "Zeitraum") {
                            VStack(spacing: 12) {
                                DatePicker("Von", selection: $startDate, in: ...endDate, displayedComponents: .date)
                                    .foregroundColor(.white).colorScheme(.dark)
                                Divider().background(Color.white.opacity(0.2))
                                DatePicker("Bis", selection: $endDate, in: startDate..., displayedComponents: .date)
                                    .foregroundColor(.white).colorScheme(.dark)
                            }
                        }

                        InsightBanner(
                            emoji: "��",
                            title: "Was ist enthalten?",
                            message: "Alle Krafttrainings mit Übungen, Gewichten und Sätzen. Cardio-Einheiten aus Apple Health. Aktuelle Körperdaten und Blutdruck.",
                            color: .blue
                        )

                        Button(action: generateReport) {
                            HStack(spacing: 12) {
                                if isGenerating {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "doc.text.magnifyingglass")
                                }
                                Text(isGenerating ? "Erstelle Bericht…" : "Bericht erstellen").font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(isGenerating ? Color.gray.opacity(0.5) : viewModel.currentTheme.accentColor)
                            .cornerRadius(16)
                        }
                        .disabled(isGenerating)

                        if let url = pdfURL {
                            ShareLink(item: url, preview: SharePreview("Trainingsübersicht.pdf",
                                                                        image: Image(systemName: "doc.fill"))) {
                                HStack(spacing: 12) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Bericht teilen").font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.green.opacity(0.8))
                                .cornerRadius(16)
                            }

                            Text("Bericht bereit — tippe oben zum Teilen ✅")
                                .font(.caption).foregroundColor(.green)
                                .multilineTextAlignment(.center)
                        }
                    }.padding()
                }
            }
        }
    }

    // MARK: - Generation

    private func generateReport() {
        isGenerating = true
        pdfURL = nil
        if viewModel.healthKitEnabled {
            viewModel.health.fetchExternalWorkouts(from: startDate, to: endDate) { workouts in
                self.externalWorkouts = workouts.map { w in
                    ReportWorkout(
                        date: w.startDate,
                        activityName: self.viewModel.health.activityName(for: w.workoutActivityType),
                        durationMinutes: w.duration / 60,
                        calories: w.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
                    )
                }
                Task { @MainActor in renderAndSave() }
            }
        } else {
            Task { @MainActor in renderAndSave() }
        }
    }

    @MainActor
    private func renderAndSave() {
        let content = MedicalReportContent(
            startDate: startDate, endDate: endDate,
            machines: viewModel.training.machines,
            externalWorkouts: externalWorkouts,
            systolic: viewModel.latestSystolic, diastolic: viewModel.latestDiastolic,
            currentWeight: viewModel.health.currentWeight,
            bodyFatLast: viewModel.health.bodyFatHistory.last?.value
        )
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2.0
        renderer.proposedSize = ProposedViewSize(width: 595, height: nil)
        guard let image = renderer.uiImage else { isGenerating = false; return }

        let pageRect = CGRect(origin: .zero, size: image.size)
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = pdfRenderer.pdfData { ctx in ctx.beginPage(); image.draw(at: .zero) }

        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Trainingsbericht_\(f.string(from: Date())).pdf")
        try? data.write(to: url)
        pdfURL = url
        isGenerating = false
    }
}

// MARK: - Report Content (rendered to PDF)

struct MedicalReportContent: View {
    let startDate: Date
    let endDate: Date
    let machines: [Machine]
    let externalWorkouts: [ReportWorkout]
    let systolic: Double
    let diastolic: Double
    let currentWeight: Double
    let bodyFatLast: Double?

    private static let df: DateFormatter = { let f = DateFormatter(); f.dateFormat = "dd.MM.yyyy"; return f }()
    private static let sectionFont = Font.system(size: 11, weight: .bold)
    private static let bodyFont    = Font.system(size: 10)
    private static let captionFont = Font.system(size: 9)
    private static let accentColor = Color(red: 0.1, green: 0.4, blue: 0.8)

    // MARK: - Computed Data

    struct DayEntry: Identifiable {
        let id = UUID()
        let date: Date
        let strengthExercises: [(name: String, group: String, sets: [ExerciseSet])]
        let cardioWorkouts: [ReportWorkout]
    }

    var dayEntries: [DayEntry] {
        let cal = Calendar.current
        var strengthMap: [Date: [String: (group: String, sets: [ExerciseSet])]] = [:]
        var cardioMap:   [Date: [ReportWorkout]] = [:]

        for m in machines {
            for s in m.sets where s.date >= startDate && s.date <= endDate {
                let day = cal.startOfDay(for: s.date)
                strengthMap[day, default: [:]][m.id.uuidString, default: (m.muscleGroup, [])].sets.append(s)
                // preserve name
                if strengthMap[day]![m.id.uuidString] != nil {
                    strengthMap[day]![m.id.uuidString]!.sets.sort { $0.date < $1.date }
                }
            }
        }
        // rebuild with machine names
        var strengthByDay: [Date: [(name: String, group: String, sets: [ExerciseSet])]] = [:]
        for m in machines {
            for s in m.sets where s.date >= startDate && s.date <= endDate {
                let day = cal.startOfDay(for: s.date)
                if strengthByDay[day] == nil { strengthByDay[day] = [] }
                if !strengthByDay[day]!.contains(where: { $0.name == m.name }) {
                    let daySets = m.sets.filter { cal.isDate($0.date, inSameDayAs: day) }
                        .sorted { $0.date < $1.date }
                    strengthByDay[day]!.append((name: m.name, group: m.muscleGroup, sets: daySets))
                }
            }
        }

        for w in externalWorkouts {
            let day = cal.startOfDay(for: w.date)
            cardioMap[day, default: []].append(w)
        }

        let allDays = Set(strengthByDay.keys).union(Set(cardioMap.keys))
        return allDays.map { day in
            DayEntry(
                date: day,
                strengthExercises: (strengthByDay[day] ?? []).sorted { $0.name < $1.name },
                cardioWorkouts: cardioMap[day] ?? []
            )
        }.sorted { $0.date > $1.date }
    }

    var totalVolume: Double {
        machines.flatMap { $0.sets }.filter { $0.date >= startDate && $0.date <= endDate }.reduce(0) { $0 + $1.volume }
    }

    var trainedMuscleGroups: [(group: String, sets: Int)] {
        var map: [String: Int] = [:]
        for m in machines {
            let n = m.sets.filter { $0.date >= startDate && $0.date <= endDate }.count
            if n > 0 { map[m.muscleGroup, default: 0] += n }
        }
        return map.map { (group: $0.key, sets: $0.value) }.sorted { $0.sets > $1.sets }
    }

    var trainingDays: Int {
        let cal = Calendar.current
        var days = Set<Date>()
        for m in machines {
            for s in m.sets where s.date >= startDate && s.date <= endDate {
                days.insert(cal.startOfDay(for: s.date))
            }
        }
        for w in externalWorkouts { days.insert(cal.startOfDay(for: w.date)) }
        return days.count
    }

    private func fmt(_ d: Date) -> String { Self.df.string(from: d) }
    private func fmtVol(_ v: Double) -> String {
        v >= 1000 ? String(format: "%.0f.%03.0f", floor(v / 1000), v.truncatingRemainder(dividingBy: 1000)) : String(format: "%.0f", v)
    }
    private func fmtW(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
    }

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            summarySection
            dividerLine
            protocolSection
            footerView
        }
        .frame(width: 595)
        .background(Color.white)
    }

    // MARK: - Header

    var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRAININGSÜBERSICHT").font(.system(size: 18, weight: .bold)).foregroundColor(Self.accentColor)
                    Text("Zeitraum: \(fmt(startDate)) �� \(fmt(endDate))").font(Self.bodyFont).foregroundColor(.gray)
                    Text("Erstellt am: \(fmt(Date()))").font(Self.captionFont).foregroundColor(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Train with Me").font(.system(size: 13, weight: .semibold)).foregroundColor(Self.accentColor)
                    Text("Persönliches Trainingsprotokoll").font(Self.captionFont).foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 28).padding(.vertical, 20)
            Rectangle().fill(Self.accentColor).frame(height: 2)
        }
    }

    // MARK: - Summary

    var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ZUSAMMENFASSUNG").font(Self.sectionFont).foregroundColor(Self.accentColor)
                .padding(.bottom, 2)

            HStack(alignment: .top, spacing: 0) {
                // Left column
                VStack(alignment: .leading, spacing: 6) {
                    summaryRow("Trainingstage im Zeitraum", value: "\(trainingDays)")
                    summaryRow("Gesamtvolumen (Krafttraining)", value: "\(fmtVol(totalVolume)) kg")
                    if trainingDays > 0 && totalVolume > 0 {
                        summaryRow("Ø Volumen pro Trainingstag",
                                   value: "\(fmtVol(totalVolume / Double(trainingDays))) kg")
                    }
                    summaryRow("Cardio-Einheiten (Apple Health)", value: "\(externalWorkouts.count)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right column
                VStack(alignment: .leading, spacing: 6) {
                    if currentWeight > 0 {
                        summaryRow("Körpergewicht", value: "\(fmtW(currentWeight)) kg")
                    }
                    if let fat = bodyFatLast {
                        summaryRow("Körperfett", value: "\(fmtW(fat)) %")
                    }
                    if systolic > 0 {
                        summaryRow("Blutdruck (letzte Messung)",
                                   value: "\(Int(systolic))/\(Int(diastolic)) mmHg")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !trainedMuscleGroups.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trainierte Muskelgruppen:").font(Self.captionFont).foregroundColor(.gray)
                    Text(trainedMuscleGroups.map { "\($0.group) (\($0.sets) Sätze)" }.joined(separator: "  ·  "))
                        .font(Self.bodyFont).foregroundColor(.black)
                }
            }
        }
        .padding(.horizontal, 28).padding(.vertical, 16)
    }

    func summaryRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label + ":").font(Self.captionFont).foregroundColor(.gray)
            Text(value).font(.system(size: 10, weight: .semibold)).foregroundColor(.black)
        }
    }

    // MARK: - Protocol

    var protocolSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TRAININGSPROTOKOLL")
                .font(Self.sectionFont).foregroundColor(Self.accentColor)
                .padding(.horizontal, 28).padding(.top, 16).padding(.bottom, 8)

            ForEach(dayEntries) { entry in
                daySection(entry)
            }
        }
    }

    func daySection(_ entry: DayEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day header
            HStack(spacing: 0) {
                Rectangle().fill(Self.accentColor).frame(width: 3)
                Text(fmt(entry.date)).font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Self.accentColor)
            }

            VStack(alignment: .leading, spacing: 8) {
                // Strength exercises
                if !entry.strengthExercises.isEmpty {
                    ForEach(entry.strengthExercises, id: \.name) { exercise in
                        exerciseBlock(exercise)
                    }
                }

                // Cardio workouts
                ForEach(entry.cardioWorkouts) { w in
                    cardioBlock(w)
                }
            }
            .padding(.horizontal, 28).padding(.vertical, 10)

            Divider().padding(.horizontal, 28)
        }
    }

    func exerciseBlock(_ exercise: (name: String, group: String, sets: [ExerciseSet])) -> some View {
        let strengthSets = exercise.sets.filter { $0.duration == nil }
        let timedSets    = exercise.sets.filter { $0.duration != nil }
        let maxW = strengthSets.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.max() ?? 0
        let vol  = exercise.sets.reduce(0) { $0 + $1.volume }

        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(exercise.name).font(.system(size: 10, weight: .semibold)).foregroundColor(.black)
                Text("(\(exercise.group))").font(Self.captionFont).foregroundColor(.gray)
            }

            if !strengthSets.isEmpty {
                let setStrings = strengthSets.map { s -> String in
                    let w = Double(s.weight.replacingOccurrences(of: ",", with: ".")).map { fmtW($0) } ?? s.weight
                    return "\(w) kg × \(s.reps)"
                }
                Text(setStrings.joined(separator: "  |  "))
                    .font(Self.captionFont).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if maxW > 0 {
                    Text("Max: \(fmtW(maxW)) kg  ·  Volumen: \(fmtVol(vol)) kg")
                        .font(Self.captionFont).foregroundColor(.gray)
                }
            }

            if !timedSets.isEmpty {
                let durs = timedSets.compactMap { $0.duration }.map { s -> String in
                    let sec = Int(s); return sec < 60 ? "\(sec)s" : "\(sec/60):\(String(format: "%02d", sec%60)) min"
                }
                Text("Haltezeiten: " + durs.joined(separator: "  |  "))
                    .font(Self.captionFont).foregroundColor(.secondary)
            }
        }
    }

    func cardioBlock(_ workout: ReportWorkout) -> some View {
        HStack(spacing: 8) {
            Text("♥").font(.system(size: 10)).foregroundColor(.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.activityName).font(.system(size: 10, weight: .semibold)).foregroundColor(.black)
                var parts: [String] = []
                let _ = {
                    let m = Int(workout.durationMinutes)
                    if m > 0 { parts.append("\(m) min") }
                    if workout.calories > 0 { parts.append("\(Int(workout.calories)) kcal") }
                }()
                if !parts.isEmpty {
                    Text(parts.joined(separator: "  ·  "))
                        .font(Self.captionFont).foregroundColor(.secondary)
                }
            }
            Spacer()
            Text("Apple Health").font(Self.captionFont).foregroundColor(.gray)
        }
        .padding(8)
        .background(Color.red.opacity(0.04))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.red.opacity(0.15), lineWidth: 0.5))
    }

    var dividerLine: some View {
        Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 0.5).padding(.horizontal, 28)
    }

    var footerView: some View {
        HStack {
            Text("Train with Me – Persönliches Trainingsprotokoll").font(Self.captionFont).foregroundColor(.gray)
            Spacer()
            Text("Erstellt: \(fmt(Date()))").font(Self.captionFont).foregroundColor(.gray)
        }
        .padding(.horizontal, 28).padding(.vertical, 12)
        .background(Color(white: 0.97))
    }
}
