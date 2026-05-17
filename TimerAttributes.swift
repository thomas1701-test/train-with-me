import Foundation
import ActivityKit

struct TimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Die Zeit, die dynamisch runterzählt
        var timeRemaining: Int
    }
    
    // Die feste Startzeit (z.B. 90 Sekunden)
    var totalTime: Int
}
