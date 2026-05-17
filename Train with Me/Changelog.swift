import Foundation

struct ChangelogEntry {
    let version: String
    let date: String
    let changes: [String]
}

enum Changelog {
    static let currentVersion = "1.1.0"

    static let entries: [ChangelogEntry] = [
        ChangelogEntry(
            version: "1.1.0",
            date: "17.05.2026",
            changes: [
                "Architektur-Refactoring: monolithischer ViewModel aufgeteilt in fokussierte Services",
                "Körpermessungen & Muskelgruppen jetzt vollständig in SwiftData",
                "Cardio: Dauer und Kalorien werden korrekt als eigene Felder gespeichert",
                "Gemini API-Key aus dem Quellcode entfernt (xcconfig)",
                "Changelog in den Einstellungen hinzugefügt"
            ]
        ),
        ChangelogEntry(
            version: "1.0.0",
            date: "16.05.2026",
            changes: [
                "Erste Version",
                "Training loggen mit Sätzen, Gewicht und Wiederholungen",
                "Muskelgruppen und Geräte verwalten",
                "Statistiken, Streak und Achievements",
                "Apple Health Integration",
                "Apple Watch Unterstützung",
                "KI-Trainingsanalyse mit Gemini",
                "Körperdaten erfassen",
                "Backup & CSV-Export"
            ]
        ),
    ]
}
