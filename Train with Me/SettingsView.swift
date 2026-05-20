import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var showExporter    = false
    @State private var showImporter    = false
    @State private var backupDocument  = BackupDocument(fileURL: URL(fileURLWithPath: ""))
    @State private var showSuccessAlert = false
    @State private var durationString  = ""
    @State private var showMedicalExport = false
    @State private var showAISetup        = false
    @State private var showDeleteAIAlert  = false

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            ScrollView {
                VStack(spacing: 20) {

                    GlassSection(title: "Design") {
                        Picker("Design", selection: $viewModel.currentTheme) {
                            ForEach(AppTheme.allCases) { theme in Text(theme.rawValue).tag(theme) }
                        }.pickerStyle(SegmentedPickerStyle())
                        .onAppear {
                            UISegmentedControl.appearance().selectedSegmentTintColor = .white.withAlphaComponent(0.3)
                        }
                    }

                    GlassSection(title: "Funktionen") {
                        Toggle("Pausen-Timer", isOn: $viewModel.timerEnabled).foregroundColor(.white)
                        if viewModel.timerEnabled {
                            HStack {
                                Text("Dauer (s)").foregroundColor(.white)
                                Spacer()
                                TextField("90", text: $durationString)
                                    .keyboardType(.numberPad).foregroundColor(.white).multilineTextAlignment(.trailing)
                                    .onChange(of: durationString) { _, val in
                                        if let d = Double(val) { viewModel.timerDuration = d }
                                    }
                            }
                        }
                    }

                    GlassSection(title: "Integrationen & Gesundheit") {
                        Toggle("Apple Health Sync", isOn: $viewModel.healthKitEnabled).foregroundColor(.white)
                            .onChange(of: viewModel.healthKitEnabled) { _, enabled in
                                if enabled {
                                    viewModel.health.requestAuthorization { success in
                                        if !success { viewModel.healthKitEnabled = false }
                                    }
                                }
                            }
                        Toggle("Körperdaten erfassen", isOn: $viewModel.bodyStatsEnabled).foregroundColor(.white)
                            .onChange(of: viewModel.bodyStatsEnabled) { _, enabled in
                                if enabled {
                                    viewModel.health.requestAuthorization { success in
                                        if !success { viewModel.bodyStatsEnabled = false }
                                    }
                                }
                            }
                        Toggle("Blutdruck erfassen", isOn: $viewModel.bloodPressureEnabled).foregroundColor(.white)
                        Button(action: {
                            viewModel.backup.importCardioFromHealth(training: viewModel.training, health: viewModel.health) {
                                showSuccessAlert = true
                            }
                        }) {
                            Label("Cardio aus Health importieren", systemImage: "heart.text.square")
                                .foregroundColor(.white)
                        }
                    }

                    GlassSection(title: "Apple Watch") {
                        Button(action: {
                            viewModel.syncMachinesToWatch()
                            viewModel.backup.message = "Daten an Uhr gesendet! ⌚️"
                            showSuccessAlert = true
                        }) {
                            Label("Uhr manuell synchronisieren", systemImage: "applewatch").foregroundColor(.white)
                        }
                    }

                    GlassSection(title: "Arzt & Export") {
                        Button(action: { showMedicalExport = true }) {
                            Label("Arztbericht erstellen", systemImage: "doc.text.magnifyingglass")
                                .foregroundColor(.white)
                        }
                    }

                    GlassSection(title: "KI-Funktionen") {
                        if viewModel.isAIEnabled {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("KI aktiv")
                                    .foregroundColor(.white)
                                Spacer()
                                if let key = KeychainService.load() {
                                    let masked = String(key.prefix(8)) + "••••••••" + String(key.suffix(4))
                                    Text(masked)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                            Divider().background(Color.white.opacity(0.2))
                            Button(action: { showAISetup = true }) {
                                Label("Key ändern", systemImage: "key.fill")
                                    .foregroundColor(.white)
                            }
                            Divider().background(Color.white.opacity(0.2))
                            Button(action: { showDeleteAIAlert = true }) {
                                Label("KI deaktivieren", systemImage: "xmark.circle")
                                    .foregroundColor(.red.opacity(0.8))
                            }
                        } else {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.white.opacity(0.5))
                                Text("KI nicht eingerichtet")
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                            }
                            Divider().background(Color.white.opacity(0.2))
                            Button(action: { showAISetup = true }) {
                                Label("KI-Analysen aktivieren", systemImage: "arrow.right.circle")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .sheet(isPresented: $showAISetup) {
                        AIOnboardingView(isPresented: $showAISetup, onActivated: { viewModel.notifyAIKeyChanged() })
                    }
                    .alert("KI deaktivieren?", isPresented: $showDeleteAIAlert) {
                        Button("Deaktivieren", role: .destructive) {
                            KeychainService.delete()
                            viewModel.notifyAIKeyChanged()
                        }
                        Button("Abbrechen", role: .cancel) {}
                    } message: {
                        Text("Der API Key wird gelöscht. KI-Features sind danach nicht mehr sichtbar.")
                    }

                    GlassSection(title: "Daten") {
                        Button(action: {
                            if let url = viewModel.backup.createBackupFile(training: viewModel.training, health: viewModel.health) {
                                backupDocument = BackupDocument(fileURL: url)
                                showExporter = true
                            }
                            // Fehler wird automatisch via viewModel.errorMessage angezeigt
                        }) {
                            Label("Backup exportieren", systemImage: "square.and.arrow.up").foregroundColor(.white)
                        }

                        Divider().background(Color.white)

                        Button(action: { showImporter = true }) {
                            Label("Backup importieren", systemImage: "square.and.arrow.down").foregroundColor(.white)
                        }

                        Divider().background(Color.white)

                        if let url = viewModel.backup.generateCSV(machines: viewModel.training.machines) {
                            ShareLink(item: url, preview: SharePreview("Training.csv")) {
                                Label("CSV Export", systemImage: "tablecells").foregroundColor(.white)
                            }
                        }
                    }
                    GlassSection(title: "Changelog") {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(Changelog.entries, id: \.version) { entry in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("v\(entry.version)")
                                            .font(.subheadline.bold()).foregroundColor(.white)
                                        Spacer()
                                        Text(entry.date)
                                            .font(.caption).foregroundColor(.white.opacity(0.5))
                                    }
                                    ForEach(entry.changes, id: \.self) { change in
                                        HStack(alignment: .top, spacing: 8) {
                                            Text("•").foregroundColor(.white.opacity(0.4)).font(.caption)
                                            Text(change).font(.caption).foregroundColor(.white.opacity(0.7))
                                        }
                                    }
                                }
                                if entry.version != Changelog.entries.last?.version {
                                    Divider().background(Color.white.opacity(0.15))
                                }
                            }
                        }
                    }

                }.padding()
            }
        }
        .navigationTitle("Einstellungen")
        .toolbar { Button("Fertig") { presentationMode.wrappedValue.dismiss() } }
        .onAppear { durationString = String(format: "%.0f", viewModel.timerDuration) }
        .fileExporter(isPresented: $showExporter, document: backupDocument, contentType: .json, defaultFilename: "Backup") { result in
            switch result {
            case .success:
                viewModel.backup.message = "Backup erfolgreich exportiert!"
                showSuccessAlert = true
            case .failure(let error):
                viewModel.errorMessage = "Export fehlgeschlagen: \(error.localizedDescription)"
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else {
                    viewModel.errorMessage = "Backup-Datei konnte nicht gelesen werden."
                    return
                }
                viewModel.backup.restoreBackupData(data, training: viewModel.training, health: viewModel.health, healthKitEnabled: viewModel.healthKitEnabled)
                if viewModel.backup.message?.contains("✅") == true { showSuccessAlert = true }
            case .failure(let error):
                viewModel.errorMessage = "Datei konnte nicht geöffnet werden: \(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $showMedicalExport) { MedicalExportView(viewModel: viewModel) }
        // Erfolgs-Alert (getrennt vom Fehler-Alert in ContentView)
        .alert("Erfolg", isPresented: $showSuccessAlert) {
            Button("OK") { showSuccessAlert = false }
        } message: {
            Text(viewModel.backup.message ?? "")
        }
    }
}
