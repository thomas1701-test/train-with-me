import Foundation
import SwiftData

@Model final class MuscleGroup {
    var id: UUID
    var name: String
    var sortIndex: Int

    init(name: String, sortIndex: Int) {
        self.id = UUID()
        self.name = name
        self.sortIndex = sortIndex
    }
}
