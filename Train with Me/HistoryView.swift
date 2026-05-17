import SwiftUI

struct HistoryView: View {
    var viewModel: AppViewModel
    @Environment(\.presentationMode) var presentationMode

    private let cal = Calendar.current
    private let daysToShow = 30

    var workoutDays: [(date: Date, volume: Double, muscles: [String], setCount: Int)] {
        let today = cal.startOfDay(for: Date())
        return (0..<daysToShow).compactMap { offset -> (Date, Double, [String], Int)? in
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let sets = viewModel.training.machines.flatMap { m in
                m.sets.filter { cal.isDate($0.date, inSameDayAs: date) }.map { (m, $0) }
            }
            guard !sets.isEmpty else { return nil }
            let volume = sets.reduce(0.0) { $0 + $1.1.volume }
            let muscles = Array(Set(sets.map { $0.0.muscleGroup })).sorted()
            return (date, volume, muscles, sets.count)
        }
    }

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Verlauf")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundColor(.white)
                            Text("Letzte \(daysToShow) Tage")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        Spacer()
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .padding(.horizontal).padding(.top, 24).padding(.bottom, 20)

                    if workoutDays.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 48)).foregroundColor(.white.opacity(0.2))
                            Text("Noch keine Trainings").font(.headline).foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity).padding(.top, 60)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(workoutDays.enumerated()), id: \.element.date) { idx, day in
                                TimelineRow(day: day, isLast: idx == workoutDays.count - 1, accentColor: viewModel.currentTheme.accentColor)
                            }
                        }.padding(.horizontal)
                    }
                }
            }
        }
    }
}

struct TimelineRow: View {
    let day: (date: Date, volume: Double, muscles: [String], setCount: Int)
    let isLast: Bool
    let accentColor: Color

    private let cal = Calendar.current

    var isToday: Bool { cal.isDateInToday(day.date) }
    var isYesterday: Bool { cal.isDateInYesterday(day.date) }

    var dayLabel: String {
        if isToday { return "Heute" }
        if isYesterday { return "Gestern" }
        let f = DateFormatter(); f.dateFormat = "EEEE"; f.locale = Locale(identifier: "de_DE")
        return f.string(from: day.date)
    }

    var dateLabel: String {
        let f = DateFormatter(); f.dateFormat = "d. MMM"; f.locale = Locale(identifier: "de_DE")
        return f.string(from: day.date)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Timeline line + dot
            VStack(spacing: 0) {
                Circle()
                    .fill(isToday ? accentColor : Color.white.opacity(0.3))
                    .frame(width: 10, height: 10)
                    .shadow(color: isToday ? accentColor.opacity(0.6) : .clear, radius: 6)
                    .padding(.top, 18)
                if !isLast {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 28)

            // Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(dayLabel)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(isToday ? accentColor : .white)
                        Text(dateLabel)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(Int(day.volume)) kg")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("\(day.setCount) Sätze")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                // Muscle tags
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(day.muscles, id: \.self) { muscle in
                            Text(muscle)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(isToday ? accentColor : .white.opacity(0.7))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background((isToday ? accentColor : Color.white).opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(14)
            .background(
                ZStack {
                    Color.white.opacity(isToday ? 0.06 : 0.03)
                    if isToday {
                        LinearGradient(colors: [accentColor.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isToday ? accentColor.opacity(0.3) : Color.white.opacity(0.07), lineWidth: 1)
            )
            .padding(.leading, 12)
            .padding(.bottom, isLast ? 32 : 10)
        }
    }
}
