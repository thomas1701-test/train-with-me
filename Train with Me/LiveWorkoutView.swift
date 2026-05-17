import SwiftUI

struct LiveWorkoutView: View {
    var viewModel: AppViewModel
    @Environment(\.dismiss) var dismiss

    private var data: LiveWorkoutData? { viewModel.watch.liveWorkoutData }

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            if let d = data {
                VStack(spacing: 0) {
                    header(d)
                    ScrollView {
                        VStack(spacing: 14) {
                            speedSection(d)
                            distanceHRSection(d)
                            caloriesSection(d)
                        }.padding()
                    }
                }
            } else {
                noWorkoutView
            }
        }
        .onChange(of: viewModel.watch.liveWorkoutData) { _, new in
            if new == nil { dismiss() }
        }
    }

    // MARK: - Header

    private func header(_ d: LiveWorkoutData) -> some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 8) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                        .overlay(Circle().fill(.red.opacity(0.4)).frame(width: 14, height: 14))
                    Text("LIVE").font(.caption.bold()).foregroundColor(.red)
                }
                Spacer()
                Button("Schließen") { dismiss() }.foregroundColor(.white.opacity(0.6))
            }
            HStack(spacing: 12) {
                Image(systemName: d.activityIcon)
                    .font(.title2).foregroundColor(.white)
                Text(d.activityName)
                    .font(.title2.bold()).foregroundColor(.white)
                Spacer()
                Text(formatElapsed(d.elapsedSeconds))
                    .font(.title2.monospacedDigit().bold()).foregroundColor(.green)
            }
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.4))
    }

    // MARK: - Sections

    private func speedSection(_ d: LiveWorkoutData) -> some View {
        GlassSection(title: "Geschwindigkeit") {
            VStack(spacing: 14) {
                // Current speed — big and prominent
                VStack(spacing: 2) {
                    Text(formatSpeed(d.currentSpeedKmh))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                    Text("km/h aktuell").font(.caption).foregroundColor(.white.opacity(0.5))
                }
                Divider().background(Color.white.opacity(0.1))
                HStack(spacing: 0) {
                    speedCell(label: "Ø Tempo",    value: formatSpeed(d.avgSpeedKmh),    color: .white)
                    Divider().background(Color.white.opacity(0.15)).frame(height: 40)
                    speedCell(label: "Max Tempo",  value: formatSpeed(d.maxSpeedKmh),    color: .orange)
                    Divider().background(Color.white.opacity(0.15)).frame(height: 40)
                    speedCell(label: "Ø Pace",     value: formatPace(d.currentPaceMinKm), color: .white)
                }
            }
        }
    }

    private func speedCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.title3.bold()).foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.white.opacity(0.5))
        }.frame(maxWidth: .infinity)
    }

    private func distanceHRSection(_ d: LiveWorkoutData) -> some View {
        HStack(spacing: 14) {
            // Distance
            GlassSection(title: "Strecke") {
                VStack(spacing: 2) {
                    Text(formatDistance(d.distanceMeters))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("km").font(.caption).foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
            }
            // Heart rate
            GlassSection(title: "Herzfrequenz") {
                VStack(spacing: 8) {
                    HStack(alignment: .bottom, spacing: 4) {
                        Text(d.currentHR > 0 ? "\(Int(d.currentHR))" : "--")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.red)
                        Text("bpm").font(.caption).foregroundColor(.white.opacity(0.5))
                            .padding(.bottom, 6)
                    }
                    HStack(spacing: 12) {
                        VStack(spacing: 1) {
                            Text(d.avgHR > 0 ? "\(Int(d.avgHR))" : "--")
                                .font(.caption.bold()).foregroundColor(.white)
                            Text("Ø").font(.caption2).foregroundColor(.white.opacity(0.4))
                        }
                        VStack(spacing: 1) {
                            Text(d.maxHR > 0 ? "\(Int(d.maxHR))" : "--")
                                .font(.caption.bold()).foregroundColor(.orange)
                            Text("Max").font(.caption2).foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func caloriesSection(_ d: LiveWorkoutData) -> some View {
        GlassSection(title: "Kalorien") {
            HStack {
                Image(systemName: "flame.fill").font(.title2).foregroundColor(.orange)
                Text(d.calories > 0 ? "\(Int(d.calories)) kcal" : "-- kcal")
                    .font(.title2.bold()).foregroundColor(.white)
                Spacer()
            }
        }
    }

    // MARK: - Empty state

    private var noWorkoutView: some View {
        VStack(spacing: 16) {
            Image(systemName: "applewatch.slash")
                .font(.system(size: 48)).foregroundColor(.white.opacity(0.3))
            Text("Kein aktives Workout").font(.headline).foregroundColor(.white.opacity(0.6))
            Text("Starte ein Cardio-Training auf der Apple Watch.")
                .font(.caption).foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
            Button("Schließen") { dismiss() }
                .font(.subheadline).foregroundColor(.white.opacity(0.5))
                .padding(.top, 8)
        }.padding()
    }

    // MARK: - Formatters

    private func formatElapsed(_ s: Int) -> String {
        let h = s / 3600; let m = (s % 3600) / 60; let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    private func formatSpeed(_ kmh: Double) -> String {
        kmh < 0.5 ? "0.0" : String(format: "%.1f", kmh)
    }

    private func formatDistance(_ m: Double) -> String {
        String(format: "%.2f", m / 1000)
    }

    private func formatPace(_ minKm: Double) -> String {
        guard minKm > 0 else { return "--:--" }
        let min = Int(minKm); let sec = Int((minKm - Double(min)) * 60)
        return String(format: "%d:%02d", min, sec)
    }
}
