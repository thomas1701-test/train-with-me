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
                    VStack(spacing: 24) {
                        headerSection
                        recoverySection
                        trainingIntelligenceSection
                        workoutButtonSection
                        routinesSection
                        librarySection
                    }.padding(.bottom, 24)
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
                }
            }
        }.padding(.horizontal)
    }

    private func headerButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.body).foregroundColor(.white)
                .padding(11).background(.ultraThinMaterial).clipShape(Circle())
        }
    }

    // MARK: - Recovery

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Erholung").font(.title3.bold()).foregroundColor(.white)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.training.muscleGroups, id: \.id) { group in
                        let status = viewModel.training.recoveryStatus(for: group.name)
                        VStack(spacing: 5) {
                            Text(status.emoji).font(.title2)
                            Text(group.name).font(.caption2.bold()).foregroundColor(.white).lineLimit(1)
                            Text(status.label).font(.caption2).foregroundColor(status.color)
                        }
                        .frame(width: 76, height: 76)
                        .background(status.color.opacity(0.12)).cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(status.color.opacity(0.4), lineWidth: 1))
                    }
                }
            }
        }.padding(.horizontal)
    }

    // MARK: - Training Intelligence

    private var trainingIntelligenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Insights").font(.title3.bold()).foregroundColor(.white)
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
        }.padding(.horizontal)
    }

    // MARK: - Workout Button

    private var workoutButtonSection: some View {
        Group {
            if !viewModel.isWorkoutActive {
                Button(action: { withAnimation { viewModel.startWorkout() } }) {
                    HStack(spacing: 10) { Image(systemName: "play.fill"); Text("Training starten") }
                        .font(.title3.bold()).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(20).shadow(color: .green.opacity(0.4), radius: 12, x: 0, y: 6)
                }.padding(.horizontal)
            } else {
                Button(action: { viewModel.finishWorkout(); showEndWorkoutAlert = true }) {
                    HStack(spacing: 10) { Image(systemName: "stop.fill"); Text("Training beenden") }
                        .font(.title3.bold()).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(20).shadow(color: .red.opacity(0.4), radius: 12, x: 0, y: 6)
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
                            Image(systemName: iconFor(group.name)).font(.title3)
                                .foregroundColor(viewModel.currentTheme.accentColor).frame(width: 28)
                            Text(group.name).font(.subheadline.bold()).foregroundColor(.white)
                            Spacer()
                            Circle().fill(viewModel.training.recoveryStatus(for: group.name).color)
                                .frame(width: 9, height: 9)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 16).glassStyle()
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

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Training beendet!").font(.largeTitle.bold()).foregroundColor(.white)
                        Text(viewModel.sessionSummaryMessage ?? "").foregroundColor(.white.opacity(0.6)).multilineTextAlignment(.center)
                        // Health stats row
                        HStack(spacing: 20) {
                            if viewModel.health.lastWorkoutKcal > 0 {
                                Label("\(Int(viewModel.health.lastWorkoutKcal)) kcal", systemImage: "flame.fill")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.orange)
                            }
                            if let avg = viewModel.health.lastWorkoutAvgHR {
                                Label("\(Int(avg)) bpm", systemImage: "heart.fill")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.red)
                            }
                            if let max = viewModel.health.lastWorkoutMaxHR {
                                Label("max \(Int(max))", systemImage: "heart.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red.opacity(0.7))
                            }
                        }
                        .padding(.top, 4)
                    }.padding(.top, 24)
                    if let img = viewModel.shareImage {
                        VStack(spacing: 12) {
                            Image(uiImage: img).resizable().scaledToFit().frame(height: 260).cornerRadius(16).shadow(radius: 10)
                            ShareLink(item: Image(uiImage: img), preview: SharePreview("Training", image: Image(uiImage: img))) {
                                Label("Teilen", systemImage: "square.and.arrow.up").font(.headline).foregroundColor(.white)
                                    .frame(maxWidth: .infinity).padding().background(Color.blue.opacity(0.8)).cornerRadius(16)
                            }
                        }.padding().glassStyle()
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sparkles").foregroundColor(viewModel.currentTheme.accentColor)
                            Text("KI Trainingsanalyse").font(.headline).foregroundColor(.white)
                            Spacer()
                        }
                        if viewModel.isAnalyzingWorkout {
                            HStack(spacing: 12) {
                                ProgressView().tint(.white)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Analysiere...").foregroundColor(.white).font(.subheadline)
                                    Text("Vergleiche mit letzten 7 Tagen").foregroundColor(.white.opacity(0.6)).font(.caption)
                                }
                            }.padding(.vertical, 8)
                        } else if viewModel.workoutAnalysis.isEmpty {
                            Text("Keine Daten für eine Analyse.").foregroundColor(.white.opacity(0.6)).font(.subheadline)
                        } else {
                            Text(viewModel.workoutAnalysis).foregroundColor(.white.opacity(0.6)).font(.subheadline).lineSpacing(5)
                        }
                    }.padding().glassStyle()
                    Button(action: { isPresented = false }) {
                        Text("Schließen").foregroundColor(.white.opacity(0.4)).font(.subheadline).padding(.bottom, 20)
                    }
                }.padding(.horizontal)
            }
        }
    }
}
