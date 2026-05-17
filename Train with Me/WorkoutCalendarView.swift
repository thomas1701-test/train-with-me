import SwiftUI

struct WorkoutCalendarView: View {
    var viewModel: AppViewModel
    @Environment(\.presentationMode) var presentationMode

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let dayLabels = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    private let weeks = 16

    private var calendarData: [(date: Date, volume: Double)] { viewModel.training.trainingCalendarData(weeks: weeks) }
    private var maxVolume: Double { calendarData.map(\.volume).max() ?? 1 }

    private var totalVolume: Double { calendarData.map(\.volume).reduce(0,+) }
    private var trainingDays: Int  { calendarData.filter { $0.volume > 0 }.count }

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("📅 Trainingskalender").font(.title2.bold()).foregroundColor(.white)
                        Text("Letzte \(weeks) Wochen").font(.caption).foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Button("Schließen") { presentationMode.wrappedValue.dismiss() }.foregroundColor(.white)
                }.padding()

                // Stats
                HStack(spacing: 0) {
                    statTile(value: "\(trainingDays)", label: "Trainingstage")
                    Divider().background(.white.opacity(0.2)).frame(height: 40)
                    statTile(value: "\(Int(totalVolume / 1000))t", label: "Gesamtvolumen")
                    Divider().background(.white.opacity(0.2)).frame(height: 40)
                    statTile(value: "\(viewModel.currentStreak)🔥", label: "Streak")
                }
                .padding()
                .glassStyle()
                .padding(.horizontal)
                .padding(.bottom, 16)

                // Wochentag-Labels
                HStack(spacing: 4) {
                    ForEach(dayLabels, id: \.self) { d in
                        Text(d).font(.caption2).foregroundColor(.white.opacity(0.5)).frame(maxWidth: .infinity)
                    }
                }.padding(.horizontal)

                // Kalender-Heatmap (GitHub-Style)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        // Offset für ersten Tag der Woche
                        ForEach(0..<leadingOffset(), id: \.self) { _ in
                            Rectangle().fill(Color.clear).aspectRatio(1, contentMode: .fit)
                        }
                        ForEach(calendarData, id: \.date) { entry in
                            CalendarCell(volume: entry.volume, maxVolume: maxVolume,
                                        accentColor: viewModel.currentTheme.accentColor, date: entry.date)
                        }
                    }.padding(.horizontal)

                    // Legende
                    HStack(spacing: 6) {
                        Text("Weniger").font(.caption2).foregroundColor(.white.opacity(0.4))
                        ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(cellColor(intensity: level, accent: viewModel.currentTheme.accentColor))
                                .frame(width: 16, height: 16)
                        }
                        Text("Mehr").font(.caption2).foregroundColor(.white.opacity(0.4))
                    }.padding(.top, 12).padding(.bottom, 24)
                }
            }
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.bold()).foregroundColor(.white)
            Text(label).font(.caption2).foregroundColor(.white.opacity(0.5))
        }.frame(maxWidth: .infinity)
    }

    private func leadingOffset() -> Int {
        guard let first = calendarData.first?.date else { return 0 }
        let weekday = Calendar.current.component(.weekday, from: first)
        return (weekday + 5) % 7  // Montag = 0
    }
}

struct CalendarCell: View {
    let volume: Double
    let maxVolume: Double
    let accentColor: Color
    let date: Date

    @State private var showTooltip = false

    private var intensity: Double {
        volume > 0 ? min(0.2 + (volume / maxVolume) * 0.8, 1.0) : 0
    }
    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(cellColor(intensity: intensity, accent: accentColor))
            .aspectRatio(1, contentMode: .fit)
            .overlay(isToday ? RoundedRectangle(cornerRadius: 3).stroke(.white, lineWidth: 1.5) : nil)
            .onTapGesture { if volume > 0 { showTooltip.toggle() } }
            .popover(isPresented: $showTooltip) {
                VStack(spacing: 4) {
                    Text(date.formatted(date: .abbreviated, time: .omitted)).font(.caption).bold()
                    Text("\(Int(volume)) kg Volumen").font(.caption2)
                }.padding(8).background(Color.black).foregroundColor(.white)
            }
    }
}

private func cellColor(intensity: Double, accent: Color) -> Color {
    intensity == 0
        ? Color.white.opacity(0.08)
        : accent.opacity(0.2 + intensity * 0.8)
}
