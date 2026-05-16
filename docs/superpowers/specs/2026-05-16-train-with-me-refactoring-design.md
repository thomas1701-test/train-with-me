# Train with Me — Refactoring Design Spec

**Date:** 2026-05-16  
**Scope:** Architectural refactoring — same features, same design, best practices  
**iOS Target:** 17+ (SwiftData, @Observable, Swift Charts already in use)

---

## Goals

- Eliminate the monolithic `FitnessViewModel` (~750 lines, all responsibilities mixed)
- Consolidate data storage: everything into SwiftData (end UserDefaults for model data)
- Remove hardcoded API key from source control
- Fix cardio semantic misuse (`weight`/`reps` used for minutes/calories)
- Clean up empty files and duplicate code
- Keep all features and UI design 100% identical

## Non-Goals

- No new features
- No visual design changes
- No Clean Architecture / Repository pattern (out of scope)
- No test suite (not in scope for this refactoring)

---

## 1. Folder Structure

```
Train with Me/
├── App/
│   ├── Train_with_MeApp.swift
│   └── AppViewModel.swift
├── Models/
│   ├── Machine.swift
│   ├── ExerciseSet.swift
│   ├── Routine.swift
│   ├── BodyMeasurement.swift       ← new
│   └── MuscleGroup.swift           ← new
├── Services/
│   ├── TrainingService.swift
│   ├── HealthService.swift
│   ├── GeminiService.swift
│   ├── BackupService.swift
│   └── WatchService.swift
├── Views/
│   ├── Dashboard/
│   │   ├── ContentView.swift
│   │   ├── RecoverySection.swift
│   │   ├── VolumeCheckView.swift
│   │   └── WorkoutButtonSection.swift
│   ├── Training/
│   │   ├── MachineListView.swift
│   │   ├── TrainingView.swift
│   │   └── IntensitySheet.swift
│   ├── Stats/
│   │   ├── SmartStatsView.swift
│   │   ├── PRDashboardView.swift
│   │   ├── MuscleHeatmapView.swift
│   │   ├── WorkoutCalendarView.swift
│   │   └── HistoryView.swift
│   ├── Gamification/
│   │   └── GamificationView.swift
│   ├── BodyStats/
│   │   └── BodyStatsView.swift
│   ├── Routines/
│   │   ├── CreateRoutineView.swift
│   │   └── RoutineDetailView.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Shared/
│       ├── UIComponents.swift
│       └── ImageCache.swift
├── Resources/
│   ├── Assets.xcassets
│   ├── Secrets.xcconfig            ← gitignored
│   └── Secrets.xcconfig.template   ← in repo (placeholder only)
└── Support/
    ├── Secrets.swift
    ├── TimerAttributes.swift
    ├── NotificationManager.swift
    └── MigrationService.swift      ← new
```

Files to delete: `Untitled.swift` (empty)

---

## 2. AppViewModel

`AppViewModel` is a slim `@Observable` coordinator. It owns references to all services and holds only UI state that is shared across multiple views.

**Responsibilities:**
- Workout session state: `isWorkoutActive`, `workoutStartDate`
- Global UI feedback: `errorMessage`, `importExportMessage`, `sessionSummaryMessage`
- Achievement banner: `newlyUnlockedAchievement`
- Share image: `shareImage`, `workoutAnalysis`, `isAnalyzingWorkout`
- Theme: `currentTheme` (persisted via UserDefaults — intentional, it's a preference)
- Timer settings: `timerEnabled`, `timerDuration` (UserDefaults — preferences, not model data)

**Does NOT own:**
- Machine/routine lists (owned by `TrainingService`)
- Body measurements (owned by `HealthService` / queried via SwiftData)
- Muscle groups (owned by `TrainingService`)

Views receive individual services as environment objects or via `AppViewModel` accessors. No view talks to more than 2 services directly.

---

## 3. Services

All services are `@Observable` classes. They receive a `ModelContext` via `configure(modelContext:)` on first use, called from `Train_with_MeApp`.

### TrainingService

Owns all training-domain logic.

**Data:** Fetches and mutates `Machine`, `ExerciseSet`, `Routine`, `MuscleGroup` from SwiftData.

**Responsibilities:**
- CRUD: machines, sets, routines, muscle groups
- `progressiveOverloadSuggestion(for:)` → `OverloadSuggestion?`
- `recoveryStatus(for:)` → `RecoveryStatus`
- `volumeStatus(for:)` / `weeklySets(for:)` → volume intelligence
- `shouldSuggestDeload` / `periodizationPhase` → training intelligence
- `currentStreak`, `longestStreak`, `totalTrainingDays` → streak
- XP system: `totalXP`, `currentLevelIndex`, `levelTitle`, `levelProgress`, `xpToNextLevel`
- `achievements` / `checkNewAchievements()`
- `personalRecords` → `[PersonalRecord]`
- `muscleShare` / `weeklyTrend` → stats
- `trainingCalendarData(weeks:)` / `volumeForDay(_:)` → calendar
- Image management: `saveImage`, `deleteImageFile`
- `syncNeeded` publisher → triggers `WatchService` sync

### HealthService

Wraps all HealthKit interactions. Replaces `HealthManager.swift`.

**Responsibilities:**
- `requestAuthorization(completion:)`
- `saveWorkout(startDate:endDate:totalVolume:)`
- `saveQuantity(typeIdentifier:value:unit:)`
- `saveBloodPressure(systolic:diastolic:)`
- `fetchHistory(for:unit:completion:)` → `[ChartDataPoint]`
- `fetchLatestWeight(completion:)`
- `fetchCardioWorkouts(completion:)` → `[HKWorkout]`
- `activityName(for:)` → `String`

### GeminiService

Isolates all AI calls and prompt construction.

**Responsibilities:**
- `analyzeBodyStats(context: BodyStatsContext) async -> String`
- `analyzeWorkout(today: [(Machine, [ExerciseSet])], machines: [Machine]) async -> String`
- Private: `buildBodyStatsPrompt`, `buildWorkoutPrompt`, `buildIntensityContext`
- Private: `callGemini(prompt:) async throws -> String`
- Private: `validateAPIKey() -> String?`
- Error mapping: quota, network, generic → user-facing German strings

### BackupService

Handles all data export and import. Receives `ModelContext` + references to `TrainingService`.

**Responsibilities:**
- `createBackupFile(machines:routines:muscleGroups:bodyData:) -> URL?`
- `restoreBackup(from url: URL, into context: ModelContext)`
- `generateCSV(machines:) -> URL?`
- Supports current JSON backup format + legacy format for backward compatibility
- Image file bundling in backup

### WatchService

Manages `WCSession`.

**Responsibilities:**
- `WCSessionDelegate` conformance
- `syncMachines(_ machines: [Machine], muscleGroups: [String])`
- Receives incoming sets → calls `TrainingService.addSet(...)`
- `AppViewModel` listens to `incomingSet` publisher

---

## 4. Data Models

### ExerciseSet (updated)

```swift
@Model final class ExerciseSet {
    var id: UUID
    var weight: String      // strength: kg as string; cardio: kept for migration compat
    var reps: String        // strength: rep count; cardio: kept for migration compat
    var date: Date
    var rpe: Int?
    var rir: Int?
    var duration: Double?   // cardio: minutes (nil for strength)
    var calories: Double?   // cardio: kcal (nil for strength)
}
```

Computed properties (`volume`, `oneRepMax`, `intensityScore`) remain unchanged.  
Cardio display logic uses `duration`/`calories` when non-nil, falls back to `weight`/`reps` for pre-migration data.

### BodyMeasurement (new SwiftData model)

```swift
@Model final class BodyMeasurement {
    var id: UUID
    var date: Date
    var type: MeasurementType   // enum: weight, waist, bodyFat, biceps, chest, thigh
    var value: Double
}

enum MeasurementType: String, Codable {
    case weight, waist, bodyFat, biceps, chest, thigh
}
```

Replaces six separate `[ChartDataPoint]` arrays in UserDefaults.

### MuscleGroup (new SwiftData model)

```swift
@Model final class MuscleGroup {
    var id: UUID
    var name: String
    var sortIndex: Int
}
```

Replaces `[String]` array in UserDefaults. `TrainingService` exposes `var muscleGroups: [MuscleGroup]` sorted by `sortIndex`.

### Unchanged models

`Machine`, `Routine` — no structural changes.

---

## 5. API Key via xcconfig

**`Secrets.xcconfig`** (gitignored):
```
GEMINI_API_KEY = AIzaSy...your_real_key...
```

**`Secrets.xcconfig.template`** (in repo):
```
GEMINI_API_KEY = YOUR_GEMINI_KEY_HERE
```

**Xcode project:** `Secrets.xcconfig` is set as the configuration file for Debug and Release.

**`Info.plist`** gets entry: `GEMINI_API_KEY = $(GEMINI_API_KEY)`

**`Secrets.swift`**:
```swift
enum Secrets {
    static var geminiKey: String {
        Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String ?? ""
    }
}
```

**`.gitignore`** gets `Secrets.xcconfig`.

---

## 6. Migration

`MigrationService` runs once synchronously during app startup, before any view appears.

### Migration steps (in order)

1. **`MuscleGroup` migration** — read `Data_Groups` from UserDefaults → insert `MuscleGroup` rows into SwiftData
2. **`BodyMeasurement` migration** — read `Data_Weight`, `Data_Waist`, `Data_Fat`, `Data_Biceps`, `Data_Chest`, `Data_Thigh` → insert `BodyMeasurement` rows
3. **Cardio set migration** — for each `Machine` with `muscleGroup == "Cardio"`, copy `weight` → `duration`, `reps` → `calories` on each `ExerciseSet`
4. **Cleanup** — remove migrated UserDefaults keys; set flag `migration_v2_done = true`

All steps are guarded by the `migration_v2_done` flag. If a step fails, it logs the error and continues — partial migration is better than a crash. UserDefaults keys are only removed after successful write to SwiftData.

---

## 7. Files to Delete / Clean Up

| File | Action |
|------|--------|
| `Untitled.swift` | Delete (empty) |
| `HealthManager.swift` | Replace with `HealthService.swift` |
| `FitnessViewModel.swift` | Replace with `AppViewModel.swift` + services |
| `Models.swift` | Split into individual files under `Models/` |

`HistoryView.swift` has a duplicate file header comment at the end — remove it.

---

## 8. Implementation Order

1. `Secrets.xcconfig` setup (unblocks everything else)
2. New SwiftData models (`BodyMeasurement`, `MuscleGroup`)
3. `MigrationService`
4. `TrainingService` (largest, most views depend on it)
5. `HealthService` (replaces HealthManager)
6. `GeminiService`
7. `WatchService`
8. `BackupService`
9. `AppViewModel` (slim coordinator, wires services together)
10. View reorganization into folder structure
11. Delete obsolete files
12. Update `.gitignore`
