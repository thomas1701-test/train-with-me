# BYOK Gemini API Key Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the xcconfig-based Gemini API Key with a secure Keychain-backed BYOK system, including an onboarding assistant and settings section, with all AI features hidden when no key is configured.

**Architecture:** A new `KeychainService` enum replaces `Secrets.swift` as the single source of truth for the API key. `AppViewModel.isAIEnabled` (computed from Keychain) drives all feature visibility. An `AIOnboardingView` sheet guides first-time setup; the same flow is accessible from `SettingsView`.

**Tech Stack:** Swift, SwiftUI, iOS Security framework (Keychain), Swift Testing (`@Test`)

---

## File Map

| Action | Path |
|---|---|
| Create | `Train with Me/KeychainService.swift` |
| Create | `Train with Me/AIOnboardingView.swift` |
| Modify | `Train with Me/GeminiService.swift` |
| Modify | `Train with Me/AppViewModel.swift` |
| Modify | `Train with Me/SettingsView.swift` |
| Modify | `Train with Me/ContentView.swift` |
| Modify | `Train with Me/Train_with_MeApp.swift` |
| Delete | `Secrets.swift` |
| Modify | `Train-with-Me-Info.plist` |
| Modify | `Train with MeTests/Train_with_MeTests.swift` |

---

## Task 1: KeychainService

**Files:**
- Create: `Train with Me/KeychainService.swift`
- Modify: `Train with MeTests/Train_with_MeTests.swift`

- [ ] **Step 1: Write failing tests**

Replace the placeholder `example()` test in `Train with MeTests/Train_with_MeTests.swift`:

```swift
import Testing
@testable import Train_with_Me

struct Train_with_MeTests {

    @Test func keychainSaveAndLoad() {
        KeychainService.save("test-key-abc123")
        #expect(KeychainService.load() == "test-key-abc123")
        KeychainService.delete()
    }

    @Test func keychainLoadReturnsNilWhenEmpty() {
        KeychainService.delete()
        #expect(KeychainService.load() == nil)
    }

    @Test func keychainDeleteClearsKey() {
        KeychainService.save("will-be-deleted")
        KeychainService.delete()
        #expect(KeychainService.load() == nil)
    }

    @Test func keychainOverwritesPreviousKey() {
        KeychainService.save("first-key")
        KeychainService.save("second-key")
        #expect(KeychainService.load() == "second-key")
        KeychainService.delete()
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL (type not found)**

In Xcode: Product → Test (⌘U). Expected: 4 failures with "cannot find type 'KeychainService'".

- [ ] **Step 3: Create KeychainService.swift**

Create `Train with Me/KeychainService.swift`:

```swift
import Foundation
import Security

enum KeychainService {
    private static let service = "de.trainingapp.apikey"
    private static let account = "gemini"

    static func save(_ key: String) {
        let data = Data(key.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData] = data
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func load() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

Product → Test (⌘U). Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add "Train with Me/KeychainService.swift" "Train with MeTests/Train_with_MeTests.swift"
git commit -m "feat: KeychainService für sicheres API Key Management"
```

---

## Task 2: GeminiService — Keychain statt Secrets

**Files:**
- Modify: `Train with Me/GeminiService.swift` (line 127)

- [ ] **Step 1: Ersetze `Secrets.geminiKey` durch `KeychainService.load()`**

In `GeminiService.swift`, ersetze die `call(prompt:)` Methode (ab Zeile 126):

```swift
private func call(prompt: String) async -> String {
    guard let key = KeychainService.load()?.trimmingCharacters(in: .whitespacesAndNewlines),
          !key.isEmpty else { return "Kein API Key konfiguriert." }
    do {
        let r = try await GenerativeModel(name: "gemini-2.5-flash", apiKey: key).generateContent(prompt)
        return r.text ?? "Keine Antwort."
    } catch {
        let d = error.localizedDescription.lowercased()
        if d.contains("quota") || d.contains("rate") { return "API-Limit erreicht. Kurz warten." }
        if d.contains("network")                     { return "Keine Internetverbindung." }
        return "KI-Fehler: \(error.localizedDescription)"
    }
}
```

- [ ] **Step 2: Build — expect SUCCESS**

Product → Build (⌘B). Muss fehlerfrei kompilieren.

- [ ] **Step 3: Commit**

```bash
git add "Train with Me/GeminiService.swift"
git commit -m "refactor: GeminiService liest Key aus Keychain statt Secrets"
```

---

## Task 3: AppViewModel — isAIEnabled + Guard

**Files:**
- Modify: `Train with Me/AppViewModel.swift`

- [ ] **Step 1: `isAIEnabled` Property hinzufügen**

In `AppViewModel.swift`, füge nach dem `// MARK: - Preferences`-Block eine neue computed property hinzu (nach Zeile 42):

```swift
// MARK: - AI

var isAIEnabled: Bool { KeychainService.load() != nil }
```

- [ ] **Step 2: `analyzeCompletedWorkout` nur aufrufen wenn KI aktiv**

In `finishWorkout()`, ersetze Zeile 103–105:

```swift
if !todayData.isEmpty {
    Task { await analyzeCompletedWorkout(todaysSets: todayData) }
}
```

durch:

```swift
if !todayData.isEmpty && isAIEnabled {
    Task { await analyzeCompletedWorkout(todaysSets: todayData) }
}
```

- [ ] **Step 3: Build — expect SUCCESS**

Product → Build (⌘B).

- [ ] **Step 4: Commit**

```bash
git add "Train with Me/AppViewModel.swift"
git commit -m "feat: isAIEnabled in AppViewModel, KI-Analyse nur wenn Key vorhanden"
```

---

## Task 4: Secrets.swift und Info.plist aufräumen

**Files:**
- Delete: `Secrets.swift`
- Modify: `Train-with-Me-Info.plist`

- [ ] **Step 1: `Secrets.swift` aus dem Xcode-Projekt löschen**

In Xcode: Rechtsklick auf `Secrets.swift` → "Delete" → "Move to Trash".

Alternativ im Terminal — aber danach muss die `.pbxproj` Referenz auch entfernt werden. Daher **unbedingt via Xcode löschen**.

- [ ] **Step 2: GEMINI_API_KEY aus Info.plist entfernen**

In `Train-with-Me-Info.plist` die beiden Zeilen entfernen:

```xml
<key>GEMINI_API_KEY</key>
<string>$(GEMINI_API_KEY)</string>
```

Die Datei soll danach nur noch `CFBundleIconName` enthalten:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIconName</key>
	<string></string>
</dict>
</plist>
```

- [ ] **Step 3: Build — expect SUCCESS**

Product → Build (⌘B). Falls ein "use of unresolved identifier 'Secrets'" Fehler erscheint, sind noch Referenzen übrig — `grep -r "Secrets\." "Train with Me/"` im Terminal hilft beim Finden.

- [ ] **Step 4: Commit**

```bash
git add Train-with-Me-Info.plist
git commit -m "chore: Secrets.swift entfernt, GEMINI_API_KEY aus Info.plist entfernt"
```

---

## Task 5: AIOnboardingView

**Files:**
- Create: `Train with Me/AIOnboardingView.swift`

- [ ] **Step 1: `AIOnboardingView.swift` erstellen**

Create `Train with Me/AIOnboardingView.swift`:

```swift
import SwiftUI

struct AIOnboardingView: View {
    @Binding var isPresented: Bool
    var onActivated: () -> Void = {}

    @State private var page = 0
    @State private var apiKeyInput = ""
    @State private var showError = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    introPage.tag(0)
                    guidePage.tag(1)
                    keyInputPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)
            }
        }
    }

    // MARK: - Pages

    private var introPage: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.linearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom))
            VStack(spacing: 12) {
                Text("KI-Analysen aktivieren")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Erhalte personalisiertes Feedback zu deinen Workouts, Körperdaten und Trainingsfortschritt — powered by Google Gemini.")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer()
            VStack(spacing: 12) {
                Button(action: { page = 1 }) {
                    Text("Jetzt einrichten")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Button(action: {
                    UserDefaults.standard.set(true, forKey: "hasSeenAIOnboarding")
                    isPresented = false
                }) {
                    Text("Überspringen")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
    }

    private var guidePage: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 12) {
                Text("So bekommst du deinen Key")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Der API Key ist kostenlos. Du brauchst nur ein Google-Konto.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 20) {
                guideStep(number: "1", text: "Google AI Studio öffnen")
                guideStep(number: "2", text: "\"Create API key\" tippen (Google-Konto nötig)")
                guideStep(number: "3", text: "Key kopieren und im nächsten Schritt einfügen")
            }
            .padding(.horizontal, 28)
            Link(destination: URL(string: "https://aistudio.google.com/apikey")!) {
                Label("Google AI Studio öffnen", systemImage: "arrow.up.right")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 28)
            Spacer()
            Button(action: { page = 2 }) {
                Text("Weiter")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
    }

    private var keyInputPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.7))
            VStack(spacing: 8) {
                Text("API Key eingeben")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                Text("Füge deinen kopierten Key hier ein.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
            }
            TextField("AIza...", text: $apiKeyInput)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15)))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 28)
            if showError {
                Text("Bitte einen gültigen Key eingeben (beginnt mit 'AIza').")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.horizontal, 28)
            }
            Spacer()
            Button(action: activate) {
                Text("Aktivieren")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(apiKeyInput.isEmpty ? .white.opacity(0.3) : .black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(apiKeyInput.isEmpty ? Color.white.opacity(0.08) : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(apiKeyInput.isEmpty)
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Helpers

    private func guideStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 32, height: 32)
                .background(Color.white)
                .clipShape(Circle())
            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func activate() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { showError = true; return }
        KeychainService.save(trimmed)
        UserDefaults.standard.set(true, forKey: "hasSeenAIOnboarding")
        onActivated()
        isPresented = false
    }
}
```

- [ ] **Step 2: Build — expect SUCCESS**

Product → Build (⌘B).

- [ ] **Step 3: Commit**

```bash
git add "Train with Me/AIOnboardingView.swift"
git commit -m "feat: AIOnboardingView — 3-Screen Assistent zur Key-Einrichtung"
```

---

## Task 6: SettingsView — KI-Funktionen Abschnitt

**Files:**
- Modify: `Train with Me/SettingsView.swift`

- [ ] **Step 1: State für Key-Bearbeitung hinzufügen**

In `SettingsView`, füge folgende `@State`-Properties nach `showMedicalExport` (Zeile 12) hinzu:

```swift
@State private var showAISetup        = false
@State private var showDeleteAIAlert  = false
```

- [ ] **Step 2: KI-Funktionen Section hinzufügen**

Füge folgenden Block **vor** `GlassSection(title: "Daten")` (nach Zeile 87, nach dem `Arzt & Export` Block) ein:

```swift
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
    AIOnboardingView(isPresented: $showAISetup)
}
.alert("KI deaktivieren?", isPresented: $showDeleteAIAlert) {
    Button("Deaktivieren", role: .destructive) {
        KeychainService.delete()
    }
    Button("Abbrechen", role: .cancel) {}
} message: {
    Text("Der API Key wird gelöscht. KI-Features sind danach nicht mehr sichtbar.")
}
```

- [ ] **Step 3: Build — expect SUCCESS**

Product → Build (⌘B).

- [ ] **Step 4: Commit**

```bash
git add "Train with Me/SettingsView.swift"
git commit -m "feat: KI-Funktionen Abschnitt in Einstellungen"
```

---

## Task 7: ContentView — Feature-Sichtbarkeit

**Files:**
- Modify: `Train with Me/ContentView.swift`

- [ ] **Step 1: SmartStats- und DailySummary-Button ausblenden**

In `ContentView.swift`, im `headerSection`, ersetze die beiden Zeilen (ca. Zeile 142 und 147):

```swift
headerButton("sparkles",             action: { showingSmartStats = true })
```
und
```swift
headerButton("sun.max.fill",         action: { showingDailySummary = true })
```

durch:

```swift
if viewModel.isAIEnabled {
    headerButton("sparkles",     action: { showingSmartStats = true })
}
```
und
```swift
if viewModel.isAIEnabled {
    headerButton("sun.max.fill", action: { showingDailySummary = true })
}
```

- [ ] **Step 2: KI-Analyse Block im EndWorkout-Sheet ausblenden**

In `ContentView.swift`, den gesamten `// AI analysis` VStack-Block (ca. Zeilen 556–584) mit einer Bedingung umschließen:

```swift
if viewModel.isAIEnabled {
    // AI analysis
    VStack(alignment: .leading, spacing: 12) {
        // ... (bestehender Code unverändert)
    }.padding().glassStyle()
}
```

- [ ] **Step 3: Build — expect SUCCESS**

Product → Build (⌘B).

- [ ] **Step 4: Commit**

```bash
git add "Train with Me/ContentView.swift"
git commit -m "feat: KI-Features in ContentView ausblenden wenn kein API Key"
```

---

## Task 8: App Entry Point — Onboarding beim ersten Start

**Files:**
- Modify: `Train with Me/Train_with_MeApp.swift`

- [ ] **Step 1: Onboarding State und Trigger hinzufügen**

In `Train_with_MeApp.swift`, füge nach `@State private var appViewModel = AppViewModel()` hinzu:

```swift
@State private var showAIOnboarding = false
```

Und ersetze den `body`:

```swift
var body: some Scene {
    WindowGroup {
        ContentView()
            .environment(appViewModel)
            .modelContainer(container)
            .sheet(isPresented: $showAIOnboarding) {
                AIOnboardingView(isPresented: $showAIOnboarding)
            }
            .onAppear {
                let seen = UserDefaults.standard.bool(forKey: "hasSeenAIOnboarding")
                if !seen {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showAIOnboarding = true
                    }
                }
            }
    }
}
```

- [ ] **Step 2: Build — expect SUCCESS**

Product → Build (⌘B).

- [ ] **Step 3: Manuell testen**

1. App in Simulator starten (oder Device).
2. Beim ersten Start erscheint nach 0.5s das Onboarding-Sheet.
3. "Überspringen" → Sheet schließt sich, keine KI-Buttons in der Header-Leiste.
4. Einstellungen öffnen → "KI-Funktionen" Abschnitt sichtbar → "KI-Analysen aktivieren" tippen → Onboarding öffnet sich erneut.
5. Einen Test-Key eingeben (z.B. `AIzaTestKey123456789`) → "Aktivieren" → KI-Buttons erscheinen in der Header-Leiste.
6. Einstellungen → "KI deaktivieren" → Buttons verschwinden wieder.

- [ ] **Step 4: Commit**

```bash
git add "Train with Me/Train_with_MeApp.swift"
git commit -m "feat: KI-Onboarding beim ersten App-Start"
```

---

## Task 9: Abschluss

- [ ] **Step 1: Alle Tests laufen lassen**

Product → Test (⌘U). Alle 4 Keychain-Tests müssen grün sein.

- [ ] **Step 2: xcconfig prüfen**

Falls die App über eine `.xcconfig`-Datei gebaut wird und dort `GEMINI_API_KEY = ...` steht, diesen Eintrag ebenfalls entfernen (Build Settings in Xcode prüfen → nach `GEMINI_API_KEY` suchen).

- [ ] **Step 3: Final Commit**

```bash
git add -A
git commit -m "feat: BYOK Gemini API Key — App Store ready"
```
