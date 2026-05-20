import SwiftUI
import Charts

// MARK: - Glass Style

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Color.white.opacity(0.04)
                    LinearGradient(
                        colors: [.white.opacity(0.08), .clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
            )
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.22), .white.opacity(0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ), lineWidth: 1
                    )
            )
    }
}

struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    func body(content: Content) -> some View {
        content.shadow(color: color.opacity(0.7), radius: radius / 2, x: 0, y: 0)
               .shadow(color: color.opacity(0.4), radius: radius,     x: 0, y: 0)
    }
}

extension View {
    func glassStyle() -> some View { modifier(GlassCard()) }
    func glow(color: Color, radius: CGFloat = 12) -> some View { modifier(GlowModifier(color: color, radius: radius)) }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionIcon: String = "plus"

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            if let action {
                Button(action: action) {
                    Image(systemName: actionIcon)
                        .font(.callout.bold())
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                }
            }
        }
    }
}

// MARK: - Insight Banner

struct InsightBanner: View {
    let emoji: String
    let title: String
    let message: String
    var footer: String? = nil
    let color: Color

    var body: some View {
        HStack(spacing: 0) {
            // Accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3)
                .padding(.vertical, 4)
            HStack(spacing: 12) {
                Text(emoji).font(.title2).frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                    Text(message)
                        .font(.caption).foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                    if let footer {
                        Text(footer).font(.caption.bold()).foregroundColor(color).padding(.top, 1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
        }
        .padding(.vertical, 14).padding(.trailing, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.18), lineWidth: 1))
    }
}

// MARK: - Glass Section

struct GlassSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
                .tracking(1.2)
            VStack(alignment: .leading) { content }.padding().glassStyle()
        }
    }
}

// MARK: - Input

struct StatInputRow: View {
    let title: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(title).foregroundColor(.white)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.white)
                .padding(5)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

// MARK: - Charts

struct BodyChart: View {
    let title: String
    let data: [ChartDataPoint]
    let color: Color

    @State private var timeRange: ChartTimeRange = .all
    @State private var selectedDate: Date? = nil

    var filteredData: [ChartDataPoint] {
        let now = Date()
        let cal = Calendar.current
        switch timeRange {
        case .week:    return data.filter { $0.date >= cal.date(byAdding: .day,   value: -7,  to: now)! }
        case .month:   return data.filter { $0.date >= cal.date(byAdding: .month, value: -1,  to: now)! }
        case .quarter: return data.filter { $0.date >= cal.date(byAdding: .month, value: -3,  to: now)! }
        case .half:    return data.filter { $0.date >= cal.date(byAdding: .month, value: -6,  to: now)! }
        case .year:    return data.filter { $0.date >= cal.date(byAdding: .year,  value: -1,  to: now)! }
        case .all:     return data
        }
    }

    func closestPoint(to targetDate: Date) -> ChartDataPoint? {
        filteredData.min(by: { abs($0.date.timeIntervalSince(targetDate)) < abs($1.date.timeIntervalSince(targetDate)) })
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title).font(.headline).foregroundColor(.white)
                Spacer()
                Picker("", selection: $timeRange) {
                    ForEach(ChartTimeRange.allCases) { range in Text(range.rawValue).tag(range) }
                }
                .pickerStyle(SegmentedPickerStyle()).frame(width: 220)
                .onAppear {
                    UISegmentedControl.appearance().selectedSegmentTintColor = .white.withAlphaComponent(0.3)
                    UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
                }
            }.padding(.bottom, 5)

            if filteredData.isEmpty {
                Text("Keine Daten in diesem Zeitraum")
                    .font(.caption).foregroundColor(.gray).frame(height: 150).frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(filteredData) { point in
                        LineMark(x: .value("Datum", point.date), y: .value("Wert", point.value))
                            .foregroundStyle(color).interpolationMethod(.catmullRom)
                        PointMark(x: .value("Datum", point.date), y: .value("Wert", point.value))
                            .foregroundStyle(color)
                    }
                    if let selectedDate, let closest = closestPoint(to: selectedDate) {
                        RuleMark(x: .value("Datum", closest.date)).foregroundStyle(Color.gray.opacity(0.5))
                            .annotation(position: .top) {
                                VStack(spacing: 2) {
                                    Text("\(closest.value, specifier: "%.1f")").font(.headline).foregroundColor(.white)
                                    Text(closest.date.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundColor(.gray)
                                }.padding(6).background(.ultraThinMaterial).cornerRadius(8)
                            }
                        PointMark(x: .value("Datum", closest.date), y: .value("Wert", closest.value))
                            .foregroundStyle(.white).symbolSize(100)
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartYAxis { AxisMarks(preset: .extended) { _ in AxisValueLabel().foregroundStyle(.white) } }
                .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(.white) } }
                .frame(height: 200)
            }
        }.padding().glassStyle()
    }
}

// MARK: - Misc

struct DayCell: View {
    let date: Date
    let volume: Double

    var opacity: Double {
        if volume == 0    { return 0.1 }
        if volume < 1000  { return 0.3 }
        if volume < 5000  { return 0.6 }
        return 1.0
    }

    var dayString: String {
        let f = DateFormatter(); f.dateFormat = "d.MM"; return f.string(from: date)
    }

    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 4).fill(Color.green).opacity(opacity).frame(height: 30)
            Text(dayString).font(.caption2).foregroundColor(.white)
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
#if targetEnvironment(simulator)
        picker.sourceType = .photoLibrary
#else
        picker.sourceType = .camera
#endif
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage { parent.image = uiImage }
            picker.dismiss(animated: true)
        }
    }
}

struct ShareView: View {
    let volume: Int
    let muscles: String

    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 20) {
                Text("TRAIN WITH ME").font(.caption).fontWeight(.bold).foregroundColor(.gray).padding(.top, 40)
                Spacer()
                Text("WORKOUT\nCOMPLETE").font(.system(size: 50, weight: .heavy)).foregroundColor(.white).multilineTextAlignment(.center)
                VStack {
                    Text("\(volume) KG").font(.system(size: 60, weight: .bold)).foregroundColor(.green)
                    Text("VOLUMEN").font(.caption).foregroundColor(.gray)
                }.padding().glassStyle()
                if !muscles.isEmpty { Text(muscles).font(.headline).foregroundColor(.white).padding() }
                Spacer()
                Text(Date().formatted(date: .abbreviated, time: .omitted)).foregroundColor(.gray).padding(.bottom, 40)
            }
        }.frame(width: 400, height: 600)
    }
}

// MARK: - VolumeRow

struct VolumeRow: View {
    let group: String
    let sets: Int
    let status: VolumeStatus

    var body: some View {
        HStack(spacing: 10) {
            Text(group)
                .font(.caption).foregroundColor(.white).frame(width: 80, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(status.color.opacity(0.7))
                        .frame(width: geo.size.width * min(Double(sets) / 20.0, 1.0))
                }
            }.frame(height: 8)
            Text("\(sets)").font(.caption2.monospacedDigit()).foregroundColor(status.color).frame(width: 24, alignment: .trailing)
        }
    }
}
