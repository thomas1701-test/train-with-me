# Design: BYOK Gemini API Key — App Store Vorbereitung

**Datum:** 2026-05-20  
**Status:** Approved

## Ziel

Die App soll im Apple App Store veröffentlicht werden. Der bisherige Gemini API Key (xcconfig → Info.plist) ist im IPA extrahierbar und damit unsicher. KI-Analyse-Features bleiben erhalten, werden aber über das BYOK-Modell (Bring Your Own Key) freigeschaltet.

## Entscheidungen

- **Modell:** BYOK — Nutzer hinterlegen ihren eigenen Gemini API Key
- **Zielgruppe:** Allgemeinpublikum (kein technisches Vorwissen voraussetzen)
- **Ohne Key:** KI-Features komplett ausgeblendet (kein Schloss, kein Hinweis im UI)
- **Setup:** Onboarding-Assistent beim ersten Start + dauerhaft in den Einstellungen

## Architektur

### KeychainService (neu)

Einfache Wrapper-Klasse für sicheres Speichern des API Keys im iOS Keychain.

```swift
KeychainService
  ├── save(key: String)
  ├── load() -> String?
  └── delete()
```

### Secrets.swift (entfernen)

`Secrets.swift` und die xcconfig-Variable `GEMINI_API_KEY` werden vollständig entfernt. Der Key kommt ab sofort ausschließlich aus dem Keychain.

### GeminiService (anpassen)

`call(prompt:)` liest den Key via `KeychainService.load()` statt `Secrets.geminiKey`. Gibt der Keychain `nil` zurück, wird kein API-Call gemacht.

### AppViewModel (anpassen)

Neue berechnete Property als einzige Wahrheitsquelle:

```swift
var isAIEnabled: Bool { KeychainService.load() != nil }
```

## Onboarding-Assistent

Wird einmalig beim ersten App-Start angezeigt (gesteuert via `UserDefaults`-Flag `hasSeenAIOnboarding`). Besteht aus drei Screens:

**Screen 1 — Einstieg**
- Titel: "KI-Analysen aktivieren"
- Kurzbeschreibung der KI-Features (Workout-Analyse, Body Stats, Tages-Zusammenfassung)
- Buttons: "Jetzt einrichten" / "Überspringen"

**Screen 2 — Anleitung**
Drei nummerierte Schritte mit Icons:
1. Google AI Studio öffnen (Link-Button → öffnet `aistudio.google.com` in Safari)
2. Kostenlosen API Key erstellen (Google-Konto erforderlich)
3. Key kopieren und hier einfügen

**Screen 3 — Key eingeben**
- Großes Textfeld, paste-optimiert
- "Aktivieren"-Button (disabled solange Feld leer)
- Bei Erfolg: kurze Bestätigungsmeldung, Sheet schließt sich, KI-Features erscheinen sofort

Der Assistent ist jederzeit über **Einstellungen → KI-Funktionen** erneut aufrufbar.

## Einstellungen — KI-Funktionen (neu)

Neuer Abschnitt in den bestehenden App-Einstellungen:

- **Status:** "KI aktiv" / "Nicht eingerichtet"
- **Key anzeigen:** maskiert (z.B. `AIza••••••••••••XyZ`)
- **Key ändern:** öffnet Eingabe-Sheet
- **Key löschen:** mit Bestätigungs-Dialog, KI-Features verschwinden danach sofort

## Feature-Sichtbarkeit

| Feature | Ohne Key | Mit Key |
|---|---|---|
| SmartStatsView (Body-Analyse) | Tab/Button ausgeblendet | Normal sichtbar |
| Workout-Analyse (EndWorkout) | Abschnitt ausgeblendet | Normal sichtbar |
| DailySummary KI-Text | Abschnitt ausgeblendet | Normal sichtbar |

Steuerung ausschließlich über `AppViewModel.isAIEnabled`. Keine Locks, keine Hinweistexte im ausgeblendeten Zustand.

## App Store Compliance

- Kein API Key im App Bundle (xcconfig/Info.plist)
- Keychain-Speicherung entspricht Apple-Richtlinien
- BYOK ist App-Store-konform; keine In-App-Purchase-Pflicht da keine eigene Monetarisierung
- Datenschutz: Der Key verlässt das Gerät nur für direkte Gemini-API-Calls (keine eigene Infrastruktur)
