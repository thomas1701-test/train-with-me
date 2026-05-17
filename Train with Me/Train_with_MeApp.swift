import SwiftUI
import SwiftData

@main
struct Train_with_MeApp: App {
    let container: ModelContainer
    @State private var appViewModel = AppViewModel()

    init() {
        let schema = Schema([
            Machine.self,
            ExerciseSet.self,
            Routine.self,
            BodyMeasurement.self,
            MuscleGroup.self
        ])
        let config = ModelConfiguration(schema: schema)
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Existing store is incompatible — delete it and start fresh.
            // Data was never persisting anyway (silent in-memory fallback).
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            for ext in ["store", "store-shm", "store-wal"] {
                try? FileManager.default.removeItem(at: support.appendingPathComponent("default.\(ext)"))
            }
            do {
                container = try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("SwiftData konnte nicht erstellt werden: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appViewModel)
                .modelContainer(container)
        }
    }
}
