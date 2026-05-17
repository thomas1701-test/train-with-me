import Foundation
import Observation
import GoogleGenerativeAI

@Observable
final class GeminiService {

    var isLoading = false
    var lastResponse = "Tippe auf 'Analysieren', um Feedback zu erhalten."

    // MARK: - Public API

    func analyzeBodyStats(
        weightHistory: [ChartDataPoint], waistHistory: [ChartDataPoint],
        bodyFatHistory: [ChartDataPoint], systolic: Double, diastolic: Double,
        machines: [Machine]
    ) async {
        guard !isLoading else { return }
        isLoading = true; lastResponse = ""
        var prompt = "Du bist ein Fitness-Coach. Analysiere diese Daten kurz auf Deutsch (6-8 Sätze):\n\n"
        if let w  = weightHistory.last?.value  { prompt += "- Gewicht: \(String(format: "%.1f", w)) kg\n" }
        if let wa = waistHistory.last?.value   { prompt += "- Bauch: \(String(format: "%.1f", wa)) cm\n" }
        if let f  = bodyFatHistory.last?.value { prompt += "- Körperfett: \(String(format: "%.1f", f)) %\n" }
        if systolic > 0 { prompt += "- Blutdruck: \(Int(systolic))/\(Int(diastolic)) mmHg\n" }
        prompt += "\nTraining (30 Tage):\n" + buildTrainingContext(machines: machines, days: 30)
        lastResponse = await call(prompt: prompt)
        isLoading = false
    }

    func analyzeWorkout(
        todaysSets: [(machine: Machine, sets: [ExerciseSet])],
        allMachines: [Machine]
    ) async -> String {
        let cal          = Calendar.current
        let today        = Date()
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: today))!
        var prompt = buildWorkoutPrompt(todaysSets: todaysSets, today: today, sevenDaysAgo: sevenDaysAgo, allMachines: allMachines)
        let intensityCtx = buildIntensityContext(machines: allMachines, days: 28)
        if !intensityCtx.isEmpty { prompt += "\n\nINTENSITÄT (letzte 4 Wochen, RPE/RIR):\n\(intensityCtx)" }
        return await call(prompt: prompt)
    }

    // MARK: - Prompt Builders

    private func buildTrainingContext(machines: [Machine], days: Int) -> String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        var ctx = ""
        for m in machines {
            let recent = m.sets.filter { $0.date > cutoff }; guard !recent.isEmpty else { continue }
            if m.muscleGroup.lowercased() == "cardio" {
                let min = recent.compactMap { $0.duration ?? Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.reduce(0, +)
                ctx += "- \(m.name): \(String(format: "%.0f", min)) min\n"
            } else {
                let maxW = recent.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.max() ?? 0
                let reps = recent.compactMap { Int($0.reps) }.reduce(0, +)
                ctx += "- \(m.name) (\(m.muscleGroup)): Max \(fmt(maxW)) kg, \(reps) Wdh\n"
            }
        }
        return ctx.isEmpty ? "Keine Daten." : ctx
    }

    private func buildWorkoutPrompt(todaysSets: [(machine: Machine, sets: [ExerciseSet])],
                                    today: Date, sevenDaysAgo: Date, allMachines: [Machine]) -> String {
        let df = DateFormatter(); df.dateFormat = "dd.MM.yyyy"
        var p = "Du bist Fitness-Coach. Analysiere das heutige Training vs. letzte 7 Tage. Strukturiere in: 1.💪 Heute 2.📈 Vergleich 3.🎯 Empfehlung.\n\nHEUTE (\(df.string(from: today))):\n"
        for item in todaysSets {
            let maxW = item.sets.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.max() ?? 0
            let vol  = item.sets.reduce(0) { $0 + $1.volume }
            p += "- \(item.machine.name): Max \(fmt(maxW)) kg, Vol \(Int(vol)) kg\n"
        }
        p += "\nVORWOCHE:\n"
        let cal = Calendar.current
        for machine in allMachines where todaysSets.map({ $0.machine.id }).contains(machine.id) {
            let prev = machine.sets.filter { $0.date >= sevenDaysAgo && !cal.isDateInToday($0.date) }
            guard !prev.isEmpty else { continue }
            let maxW = prev.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.max() ?? 0
            p += "- \(machine.name): Max \(fmt(maxW)) kg\n"
        }
        return p
    }

    private func buildIntensityContext(machines: [Machine], days: Int) -> String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        var lines: [String] = []
        for m in machines {
            let rpes = m.sets.filter { $0.date > cutoff }.compactMap { $0.rpe }
            guard !rpes.isEmpty else { continue }
            let avgRPE = Double(rpes.reduce(0, +)) / Double(rpes.count)
            let rirs   = m.sets.filter { $0.date > cutoff }.compactMap { $0.rir }
            var line   = "- \(m.name) (\(m.muscleGroup)): Ø RPE \(String(format: "%.1f", avgRPE))/10"
            if !rirs.isEmpty { line += ", Ø RIR \(String(format: "%.1f", Double(rirs.reduce(0,+)) / Double(rirs.count)))" }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - API Call

    private func call(prompt: String) async -> String {
        let key = Secrets.geminiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.contains("YOUR_") else { return "Kein gültiger API Key." }
        do {
            let r = try await GenerativeModel(name: "gemini-2.5-flash", apiKey: key).generateContent(prompt)
            return r.text ?? "Keine Antwort."
        } catch {
            let d = error.localizedDescription.lowercased()
            if d.contains("quota") || d.contains("rate") { return "API-Limit erreicht. Kurz warten." }
            if d.contains("network")                     { return "Keine Internetverbindung." }
            return "KI-Fehler: \(error.localizedDescription)"
        }
    }

    private func fmt(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
    }
}
