import Foundation

struct ChangelogEntry {
    let version: String
    let date: String
    let changes: [String]
}

enum Changelog {
    static let currentVersion = "1.3.0"

    static let entries: [ChangelogEntry] = [
        ChangelogEntry(
            version: "1.3.0",
            date: "17.05.2026",
            changes: [
                "Unterstützungsgewicht-Feature: Geräte als Unterstützungsgerät markierbar",
                "Weniger Unterstützung = Fortschritt (invertierte PR-Logik)",
                "Toggle in TrainingView, kein x-Mal-aktivieren nötig",
                "PR-Dashboard zeigt Minimalgewicht statt 1RM für Unterstützungsgeräte",
                "Progressions-Banner gibt passende Hinweise (Gewicht reduzieren)"
            ]
        ),
        ChangelogEntry(
            version: "1.2.0",
            date: "17.05.2026",
            changes: [
                "HealthKit-Integration massiv erweitert: Kalorien, Herzfrequenz & Trainingsmetadaten",
                "Verbrauchte Kalorien werden nach dem Training in Apple Health eingetragen",
                "Herzfrequenz (Ø und Max) wird vom Apple Watch abgerufen und angezeigt",
                "Trainingseinheit enthält Übungsnamen, Muskelgruppen und Satzanzahl",
                "Zusammenfassung nach Training zeigt Kalorien und Herzfrequenz direkt an"
            ]
        ),
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
