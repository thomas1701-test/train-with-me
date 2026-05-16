import Foundation
import SwiftData

@Model final class BodyMeasurement {
    var id: UUID
    var date: Date
    var type: String   // "weight" | "waist" | "bodyFat" | "biceps" | "chest" | "thigh"
    var value: Double

    init(date: Date, type: String, value: Double) {
        self.id = UUID()
        self.date = date
        self.type = type
        self.value = value
    }
}
