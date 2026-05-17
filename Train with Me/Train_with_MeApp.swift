import SwiftUI
import SwiftData

@main
struct Train_with_MeApp: App {
    @State private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appViewModel)
                .modelContainer(for: [Machine.self, Routine.self, BodyMeasurement.self, MuscleGroup.self])
        }
    }
}
