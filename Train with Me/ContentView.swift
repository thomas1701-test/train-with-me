import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppViewModel.self) var viewModel
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddGroupAlert  = false
    @State private var newGroupName          = ""
    @State private var showingHistory        = false
    @State private var showingSettings       = false
    @State private var showEndWorkoutAlert   = false
    @State private var showingBodyStats      = false
    @State private var showingCreateRoutine  = false
    @State private var showingSmartStats     = false
    @State private var showingHeatmap        = false
    @State private var showingPRDashboard    = false
    @State private var showingCalendar       = false
    @State private var showingGamification   = false
    @State private var showingDailySummary   = false
    @State private var showingLiveWorkout    = false
    @State private var groupToRename: String? = nil
    @State private var newRenameName         = ""
    @State private var streakMilestone: String? = nil

    init() {
        let a = UINavigationBarAppearance()
        a.configureWithTransparentBackground()
        a.titleTextAttributes      = [.foregroundColor: UIColor.white]
        a.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance   = a
        UINavigationBar.appearance().compactAppearance    = a
        UINavigationBar.appearance().scrollEdgeAppearance = a
    }

    var body: some View {
        NavigationView {
            ZStack {
                viewModel.currentTheme.backgroundView
                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
                        heroCard
                        workoutButtonSection
                        recoverySection
                        trainingIntelligenceSection
                        routinesSection
                        librarySection
                    }.padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingHistory)       { HistoryView(viewModel: viewModel) }
            .sheet(isPresented: $showingSettings)      { SettingsView(viewModel: viewModel) }
            .sheet(isPresented: $showingBodyStats)     { BodyStatsView(viewModel: viewModel) }
            .sheet(isPresented: $showingCreateRoutine) { CreateRoutineView(viewModel: viewModel) }
            .sheet(isPresented: $showingSmartStats)    { SmartStatsView(viewModel: viewModel) }
            .sheet(isPresented: $showingHeatmap)       { MuscleHeatmapView(viewModel: viewModel) }
            .sheet(isPresented: $showEndWorkoutAlert)  { EndWorkoutSheet(viewModel: viewModel, isPresented: $showEndWorkoutAlert) }
            .sheet(isPresented: $showingPRDashboard)   { PRDashboardView(viewModel: viewModel) }
            .sheet(isPresented: $showingCalendar)      { WorkoutCalendarView(viewModel: viewModel) }
            .sheet(isPresented: $showingGamification)  { NavigationView { GamificationView(viewModel: viewModel) } }
            .sheet(isPresented: $showingDailySummary)  { DailySummaryView(viewModel: viewModel) }
            .sheet(isPresented: $showingLiveWorkout)   { LiveWorkoutView(viewModel: viewModel) }
            .alert("Neue Kategorie", isPresented: $showingAddGroupAlert) {
                TextField("Name", text: $newGroupName)
                Button("Hinzufügen") { if !newGroupName.isEmpty { viewModel.training.addMuscleGroup(name: newGroupName); newGroupName = "" } }
                Button("Abbrechen", role: .cancel) { }
            }
            .alert("Kategorie umbenennen", isPresented: Binding(get: { groupToRename != nil }, set: { if !$0 { groupToRename = nil } })) {
                TextField("Neuer Name", text: $newRenameName)
                Button("Speichern") { if let old = groupToRename, !newRenameName.isEmpty { viewModel.training.renameMuscleGroup(oldName: old, newName: newRenameName) }; groupToRename = nil }
                Button("Abbrechen", role: .cancel) { groupToRename = nil }
            }
            .alert("Fehler", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: { Text(viewModel.errorMessage ?? "") }
            .alert(streakMilestone ?? "", isPresented: Binding(get: { streakMilestone != nil }, set: { if !$0 { streakMilestone = nil } })) {
                Button("💪 Los geht's!") { streakMilestone = nil }
            }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) {
            if let achievement = viewModel.newlyUnlockedAchievement {
                AchievementUnlockedBanner(achievement: achievement)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                            withAnimation { viewModel.newlyUnlockedAchievement = nil }
                        }
                    }
            }
        }
        .onAppear {
            MigrationService.runIfNeeded(context: modelContext)
            viewModel.configure(modelContext: modelContext)
            streakMilestone = viewModel.training.streakMilestoneMessage
        }
        .onChange(of: viewModel.watch.incomingSet) { _, incoming in
            guard let s = incoming else { return }
            viewModel.handleIncomingWatchSet(machineName: s.machineName, weight: s.weight, reps: s.reps)
            viewModel.watch.incomingSet = nil
        }
        .onChange(of: viewModel.watch.incomingCardioResult) { _, incoming in
            guard let r = incoming else { return }
            viewModel.handleIncomingCardioResult(r)
            viewModel.watch.incomingCardioResult = nil
        }
        .onChange(of: viewModel.watch.liveWorkoutData) { _, new in
            if new != nil && !showingLiveWorkout { showingLiveWorkout = true }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dashboard").font(.largeTitle.bold()).foregroundColor(.white)
                    if viewModel.training.currentStreak > 0 {
                        HStack(spacing: 5) {
                            Text("🔥").font(.caption)
                            Text("\(viewModel.training.currentStreak) Tage Streak")
                                .font(.caption.bold()).foregroundColor(.orange)
                        }
                    }
                }
                Spacer()
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.white).padding(10)
                        .background(.ultraThinMaterial).clipShape(Circle())
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    headerButton("medal.fill",           action: { showingGamification = true })
                    headerButton("calendar.badge.clock", action: { showingCalendar = true })
                    headerButton("trophy.fill",          action: { showingPRDashboard = true })
                    headerButton("flame.fill",           action: { showingHeatmap = true })
                    headerButton("sparkles",             action: { showingSmartStats = true })
                    if viewModel.bodyStatsEnabled {
                        headerButton("figure.arms.open", action: { showingBodyStats = true })
                    }
                    headerButton("calendar",             action: { showingHistory = true })
                    headerButton("sun.max.fill",         action: { showingDailySummary = true })
                    if viewModel.watch.liveWorkoutData != nil {
                        Button(action: { showingLiveWorkout = true }) {
                            HStack(spacing: 5) {
                                Circle().fill(.red).frame(width: 6, height: 6)
                                Text("Live").font(.caption.bold()).foregroundColor(.white)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(.red.opacity(0.25)).clipShape(Capsule())
                            .overlay(Capsule().stroke(.red.opacity(0.5), lineWidth: 1))
                        }
                    }
                }
            }
        }.padding(.horizontal)
    }

    private func headerButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.body).foregroundColor(.white)
                .padding(11)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        let cal = Calendar.current
        let todayVolume = viewModel.training.machines.flatMap { $0.sets }.filter { cal.isDateInToday($0.date) }.reduce(0) { $0 + $1.volume }
        let todaySets   = viewModel.training.machines.flatMap { $0.sets }.filter { cal.isDateInToday($0.date) }.count

        return ZStack(alignment: .bottomLeading) {
            // Background
            RoundedRectangle(cornerRadius: 24)
                .fill(viewModel.currentTheme.accentGradient)
                .opacity(todayVolume > 0 ? 1.0 : 0.35)

            // Decorative circles
            Circle().fill(.white.opacity(0.06)).frame(width: 160).offset(x: 180, y: -40)
            Circle().fill(.white.opacity(0.04)).frame(width: 100).offset(x: 240, y: 20)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(todayVolume > 0 ? "Heute" : "Kein Training heute")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                    if todayVolume > 0 {
                        Text("\(Int(todayVolume))")
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        Text("kg Volumen")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                    } else {
                        Text("Starte dein erstes\nTraining des Tages")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 2)
                    }
                }
                Spacer()
                if todayVolume > 0 {
                    VStack(alignment: .trailing, spacing: 10) {
                        heroStat(value: "\(todaySets)", label: "Sätze")
                        if viewModel.training.currentStreak > 0 {
                            heroStat(value: "\(viewModel.training.currentStreak)", label: "Streak 🔥")
                        }
                        if viewModel.health.lastWorkoutKcal > 0 {
                            heroStat(value: "\(Int(viewModel.health.lastWorkoutKcal))", label: "kcal")
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .shadow(color: viewModel.currentTheme.accentColor.opacity(todayVolume > 0 ? 0.4 : 0.15), radius: 20, x: 0, y: 8)
        .padding(.horizontal)
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
        }
    }

    // MARK: - Recovery

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Erholung")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.training.muscleGroups, id: \.id) { group in
                        let status = viewModel.training.recoveryStatus(for: group.name)
                        VStack(spacing: 6) {
                            Text(status.emoji).font(.title)
                            Text(group.name)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white).lineLimit(1)
                            Text(status.label)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(status.color)
                        }
                        .frame(width: 80, height: 84)
                        .background(
                            ZStack {
                                status.color.opacity(0.10)
                                LinearGradient(colors: [.white.opacity(0.06), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                            }
                        )
                        .cornerRadius(18)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(status.color.opacity(0.35), lineWidth: 1))
                        .shadow(color: status.color.opacity(0.15), radius: 6, x: 0, y: 3)
                    }
                }.padding(.horizontal)
            }
        }
    }

    // MARK: - Training Intelligence

    private var trainingIntelligenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Insights")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundColor(.white)
            if viewModel.training.shouldSuggestDeload {
                InsightBanner(emoji: "😴", title: "Deload empfohlen",
                    message: "Du trainierst seit 2 Wochen sehr intensiv (Ø RPE ≥ 8). Eine leichtere Woche fördert die Regeneration.",
                    color: .orange)
            }
            if viewModel.training.periodizationPhase != .noData {
                InsightBanner(emoji: viewModel.training.periodizationPhase.emoji,
                    title: "Aktuelle Phase: \(viewModel.training.periodizationPhase.title)",
                    message: viewModel.training.periodizationPhase.description,
                    footer: viewModel.training.periodizationPhase.suggestion,
                    color: viewModel.currentTheme.accentColor)
            }
            VolumeCheckView(viewModel: viewModel)
        }
        .padding(.horizontal)
    }

    // MARK: - Workout Button

    private var workoutButtonSection: some View {
        Group {
            if !viewModel.isWorkoutActive {
                Button(action: { withAnimation { viewModel.startWorkout() } }) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Training starten")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(LinearGradient(colors: [.green, Color(red:0.0,green:0.8,blue:0.5)], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(22)
                    .shadow(color: .green.opacity(0.5), radius: 16, x: 0, y: 8)
                }.padding(.horizontal)
            } else {
                Button(action: { viewModel.finishWorkout(); showEndWorkoutAlert = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Training beenden")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(LinearGradient(colors: [Color(red:0.9,green:0.15,blue:0.15), Color(red:1.0,green:0.45,blue:0.0)], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(22)
                    .shadow(color: .red.opacity(0.5), radius: 16, x: 0, y: 8)
                }.padding(.horizontal)
            }
        }
    }

    // MARK: - Routines

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Meine Pläne", action: { showingCreateRoutine = true })
            if viewModel.training.routines.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: "list.bullet.clipboard").font(.title2).foregroundColor(.gray)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kein Plan vorhanden").font(.subheadline.bold()).foregroundColor(.white)
                        Text("Erstelle deinen ersten Trainingsplan").font(.caption).foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05)).cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.training.routines) { routine in
                            NavigationLink(destination: RoutineDetailView(viewModel: viewModel, routine: routine)) {
                                VStack(spacing: 8) {
                                    Image(systemName: "list.bullet.clipboard").font(.largeTitle)
                                        .foregroundColor(viewModel.currentTheme.accentColor)
                                    Text(routine.name).font(.subheadline.bold()).foregroundColor(.white)
                                        .multilineTextAlignment(.center).lineLimit(2)
                                }.frame(width: 130, height: 110).glassStyle()
                            }
                            .contextMenu {
                                Button("Löschen", role: .destructive) {
                                    if let idx = viewModel.training.routines.firstIndex(where: { $0.id == routine.id }) {
                                        viewModel.training.deleteRoutine(at: IndexSet(integer: idx))
                                    }
                                }
                            }
                        }
                    }.padding(.vertical, 4)
                }
            }
        }.padding(.horizontal)
    }

    // MARK: - Library

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Bibliothek", action: { showingAddGroupAlert = true })
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(viewModel.training.muscleGroups, id: \.id) { group in
                    NavigationLink(destination: MachineListView(viewModel: viewModel, muscle: group.name)) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(viewModel.currentTheme.accentColor.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: iconFor(group.name))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(viewModel.currentTheme.accentColor)
                            }
                            Text(group.name)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Circle()
                                .fill(viewModel.training.recoveryStatus(for: group.name).color)
                                .frame(width: 8, height: 8)
                                .shadow(color: viewModel.training.recoveryStatus(for: group.name).color.opacity(0.6), radius: 4)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 14).glassStyle()
                    }
                    .contextMenu {
                        Button("Umbenennen") { groupToRename = group.name; newRenameName = group.name }
                        Button("Löschen", role: .destructive) { viewModel.training.deleteMuscleGroup(name: group.name) }
                    }
                }
            }
        }.padding(.horizontal)
    }

    func iconFor(_ muscle: String) -> String {
        switch muscle.lowercased() {
        case "brust": return "shield.fill"; case "rücken": return "figure.rower"
        case "beine": return "figure.run";  case "arme":   return "dumbbell.fill"
        case "bauch": return "circle.grid.2x2.fill"; case "schultern": return "figure.arms.open"
        case "cardio": return "heart.fill"; default: return "star.fill"
        }
    }
}

// MARK: - VolumeCheckView

struct VolumeCheckView: View {
    var viewModel: AppViewModel
    var volumeGroups: [MuscleGroup] { viewModel.training.muscleGroups.filter { $0.name.lowercased() != "cardio" } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Volumen diese Woche").font(.subheadline.bold()).foregroundColor(.white)
                Spacer()
                Text("Ziel: 10–20 Sätze").font(.caption2).foregroundColor(.white.opacity(0.4))
            }
            ForEach(volumeGroups, id: \.id) { group in
                VolumeRow(group: group.name,
                          sets: viewModel.training.weeklySets(for: group.name),
                          status: viewModel.training.volumeStatus(for: group.name))
            }
            HStack(spacing: 14) {
                legendDot(.red, "Zu wenig"); legendDot(.orange, "Minimal")
                legendDot(.green, "Optimal"); legendDot(.blue, "Viel")
            }.padding(.top, 2)
        }
        .padding(14).background(Color.white.opacity(0.05)).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) { Circle().fill(color).frame(width: 6, height: 6); Text(label).font(.caption2).foregroundColor(.white.opacity(0.4)) }
    }
}

// MARK: - EndWorkoutSheet

struct EndWorkoutSheet: View {
    var viewModel: AppViewModel
    @Binding var isPresented: Bool

    @State private var showVolume = false

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            ScrollView {
                VStack(spacing: 24) {
                    // Hero
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 52))
                            .foregroundColor(viewModel.currentTheme.accentColor)
                            .symbolEffect(.bounce, options: .nonRepeating)
                            .shadow(color: viewModel.currentTheme.accentColor.opacity(0.5), radius: 16)
                            .padding(.top, 28)

                        Text("Training beendet!")
                            .font(.system(.title, design: .rounded, weight: .black))
                            .foregroundColor(.white)

                        if let summary = viewModel.sessionSummaryMessage {
                            Text(summary)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.white.opacity(0.55))
                                .multilineTextAlignment(.center)
                        }
                    }

                    // Volume hero number
                    let todayVolume = viewModel.training.machines.flatMap { $0.sets }
                        .filter { Calendar.current.isDateInToday($0.date) }
                        .reduce(0) { $0 + $1.volume }

                    if todayVolume > 0 {
                        VStack(spacing: 4) {
                            Text(showVolume ? "\(Int(todayVolume))" : "0")
                                .font(.system(size: 64, weight: .black, design: .rounded))
                                .foregroundColor(viewModel.currentTheme.accentColor)
                                .glow(color: viewModel.currentTheme.accentColor, radius: 16)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: showVolume)
                            Text("kg Volumen heute")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(viewModel.currentTheme.accentColor.opacity(0.08))
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(viewModel.currentTheme.accentColor.opacity(0.2), lineWidth: 1))
                    }

                    // Health stats
                    let hasKcal = viewModel.health.lastWorkoutKcal > 0
                    let hasHR   = viewModel.health.lastWorkoutAvgHR != nil
                    if hasKcal || hasHR {
                        HStack(spacing: 12) {
                            if hasKcal {
                                endStat(icon: "flame.fill", value: "\(Int(viewModel.health.lastWorkoutKcal))", label: "kcal", color: .orange)
                            }
                            if let avg = viewModel.health.lastWorkoutAvgHR {
                                endStat(icon: "heart.fill", value: "\(Int(avg))", label: "Ø bpm", color: .red)
                            }
                            if let max = viewModel.health.lastWorkoutMaxHR {
                                endStat(icon: "heart.circle.fill", value: "\(Int(max))", label: "Max bpm", color: .pink)
                            }
                        }
                    }

                    // Share card
                    if let img = viewModel.shareImage {
                        VStack(spacing: 12) {
                            Image(uiImage: img).resizable().scaledToFit()
                                .frame(height: 240).cornerRadius(16)
                                .shadow(color: .black.opacity(0.4), radius: 12)
                            ShareLink(item: Image(uiImage: img), preview: SharePreview("Training", image: Image(uiImage: img))) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Teilen")
                                }
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(viewModel.currentTheme.accentGradient)
                                .cornerRadius(16)
                                .shadow(color: viewModel.currentTheme.accentColor.opacity(0.4), radius: 10, x: 0, y: 4)
                            }
                        }.padding().glassStyle()
                    }

                    // AI analysis
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(viewModel.currentTheme.accentColor)
                                .symbolEffect(.pulse, options: .repeating)
                            Text("KI Trainingsanalyse")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        if viewModel.isAnalyzingWorkout {
                            HStack(spacing: 12) {
                                ProgressView().tint(.white)
                                Text("Analysiere...")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                            }.padding(.vertical, 8)
                        } else if viewModel.workoutAnalysis.isEmpty {
                            Text("Keine Daten für eine Analyse.")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(.subheadline, design: .rounded))
                        } else {
                            Text(viewModel.workoutAnalysis)
                                .foregroundColor(.white.opacity(0.7))
                                .font(.system(.subheadline, design: .rounded))
                                .lineSpacing(5)
                        }
                    }.padding().glassStyle()

                    Button(action: { isPresented = false }) {
                        Text("Schließen")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.white.opacity(0.35))
                            .padding(.bottom, 24)
                    }
                }.padding(.horizontal)
            }
        }
        .onAppear { showVolume = true }
    }

    private func endStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.5), radius: 6)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2), lineWidth: 1))
    }
}
