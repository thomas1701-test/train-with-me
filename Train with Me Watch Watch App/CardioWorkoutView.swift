import SwiftUI
import HealthKit

struct CardioWorkoutView: View {
    @State private var manager = CardioWorkoutManager()
    @State private var showStopConfirm = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !manager.isRunning && !manager.isFinished {
                ActivityPickerView(manager: manager)
            } else if manager.isFinished, let summary = manager.summary {
                CardioSummaryView(summary: summary) {
                    manager.reset()
                }
            } else {
                LiveMetricsView(manager: manager) {
                    showStopConfirm = true
                }
                .confirmationDialog("Training beenden?", isPresented: $showStopConfirm) {
                    Button("Beenden", role: .destructive) { manager.stop() }
                    Button("Weiter", role: .cancel) {}
                }
            }
        }
        .onAppear { manager.requestAuth() }
    }
}

// MARK: - Activity Picker

struct ActivityPickerView: View {
    @Bindable var manager: CardioWorkoutManager

    var body: some View {
        VStack(spacing: 6) {
            Text("Cardio")
                .font(.headline)
                .foregroundColor(.green)

            Picker("Aktivität", selection: $manager.selectedActivityIndex) {
                ForEach(cardioActivities.indices, id: \.self) { i in
                    Label(cardioActivities[i].name, systemImage: cardioActivities[i].icon)
                        .tag(i)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 80)

            Button {
                manager.start()
            } label: {
                Text("Start")
                    .font(.headline)
                    .bold()
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(Color.green)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
    }
}

// MARK: - Live Metrics

struct LiveMetricsView: View {
    let manager: CardioWorkoutManager
    let onStop: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                Text(formatElapsed(manager.elapsedSeconds))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(manager.isPaused ? .orange : .green)
                    .frame(maxWidth: .infinity, alignment: .center)

                Divider().background(Color.white.opacity(0.15))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                    WatchMetricCell(
                        value: String(format: "%.2f", manager.distanceMeters / 1000),
                        unit: "km",
                        icon: "map"
                    )
                    WatchMetricCell(
                        value: formatPace(manager.currentPaceMinKm),
                        unit: "min/km",
                        icon: "clock"
                    )
                    WatchMetricCell(
                        value: String(format: "%.1f", manager.currentSpeedKmh),
                        unit: "km/h aktuell",
                        icon: "speedometer"
                    )
                    WatchMetricCell(
                        value: manager.currentHR > 0 ? "\(Int(manager.currentHR))" : "--",
                        unit: "bpm",
                        icon: "heart.fill",
                        color: .red
                    )
                    WatchMetricCell(
                        value: String(format: "%.0f", manager.calories),
                        unit: "kcal",
                        icon: "flame.fill",
                        color: .orange
                    )
                    WatchMetricCell(
                        value: String(format: "%.1f", manager.maxSpeedKmh),
                        unit: "km/h max",
                        icon: "arrow.up.right"
                    )
                }

                HStack(spacing: 8) {
                    Button {
                        manager.isPaused ? manager.resume() : manager.pause()
                    } label: {
                        Image(systemName: manager.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(Color.orange.opacity(0.85))
                            .cornerRadius(9)
                    }
                    .buttonStyle(.plain)

                    Button(action: onStop) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(Color.red.opacity(0.85))
                            .cornerRadius(9)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
    }

    func formatElapsed(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%02d:%02d", m, sec)
    }

    func formatPace(_ p: Double) -> String {
        guard p > 0 else { return "--:--" }
        let m = Int(p), s = Int((p - Double(m)) * 60)
        return "\(m):\(String(format: "%02d", s))"
    }
}

struct WatchMetricCell: View {
    let value: String
    let unit: String
    let icon: String
    var color: Color = .white

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color.opacity(0.6))
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(unit)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.07))
        .cornerRadius(8)
    }
}

// MARK: - Summary

struct CardioSummaryView: View {
    let summary: CardioSummary
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text(summary.activityName).font(.headline).foregroundColor(.green)
                }

                Divider().background(Color.white.opacity(0.15))

                Group {
                    SummaryMetricRow(label: "Dauer",    value: formatTime(summary.durationSeconds), icon: "clock")
                    SummaryMetricRow(label: "Distanz",  value: String(format: "%.2f km", summary.distanceMeters / 1000), icon: "map")
                    SummaryMetricRow(label: "Ø Pace",   value: formatPace(summary.avgPaceMinKm), icon: "clock.arrow.2.circlepath")
                    SummaryMetricRow(label: "Ø Speed",  value: String(format: "%.1f km/h", summary.avgSpeedKmh), icon: "speedometer")
                    SummaryMetricRow(label: "Max Speed",value: String(format: "%.1f km/h", summary.maxSpeedKmh), icon: "arrow.up.right")
                    SummaryMetricRow(label: "Ø HF",     value: summary.avgHR > 0 ? "\(Int(summary.avgHR)) bpm" : "--", icon: "heart.fill")
                    SummaryMetricRow(label: "Max HF",   value: summary.maxHR > 0 ? "\(Int(summary.maxHR)) bpm" : "--", icon: "heart.fill")
                    SummaryMetricRow(label: "Kalorien", value: String(format: "%.0f kcal", summary.calories), icon: "flame.fill")
                }

                Button(action: onDone) {
                    Text("Fertig")
                        .font(.headline)
                        .bold()
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(Color.green)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
    }

    func formatTime(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0
            ? String(format: "%dh %02dm %02ds", h, m, sec)
            : String(format: "%02d:%02d", m, sec)
    }

    func formatPace(_ p: Double) -> String {
        guard p > 0 else { return "--:--" }
        let m = Int(p), s = Int((p - Double(m)) * 60)
        return "\(m):\(String(format: "%02d", s)) /km"
    }
}

struct SummaryMetricRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.35))
                .frame(width: 14)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}
