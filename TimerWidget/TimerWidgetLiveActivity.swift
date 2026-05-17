import ActivityKit
import WidgetKit
import SwiftUI

struct TimerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            // Das Design für den Sperrbildschirm (Lockscreen)
            HStack {
                VStack(alignment: .leading) {
                    Text("Satz-Pause")
                        .font(.headline)
                        .foregroundColor(.green)
                    Text("Bereit machen für den nächsten Satz!")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Text("\(context.state.timeRemaining)s")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(15)

        } dynamicIsland: { context in
            // Das Design für die Dynamic Island oben am Bildschirmrand
            DynamicIsland {
                // Wenn man lange auf die Island drückt (Aufgeklappt)
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundColor(.green)
                        Text("Pause")
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.timeRemaining)s")
                        .font(.title2.bold())
                        .foregroundColor(.green)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(
                        value: Double(context.attributes.totalTime - context.state.timeRemaining),
                        total: Double(context.attributes.totalTime)
                    )
                    .tint(.green)
                    .padding(.horizontal)
                }
            } compactLeading: {
                // Kleine Island links (zugeklappt)
                Image(systemName: "timer")
                    .foregroundColor(.green)
            } compactTrailing: {
                // Kleine Island rechts (zugeklappt)
                Text("\(context.state.timeRemaining)")
                    .foregroundColor(.green)
                    .bold()
            } minimal: {
                // Ganz kleine Island (wenn noch was anderes aktiv ist)
                Text("\(context.state.timeRemaining)")
                    .foregroundColor(.green)
            }
        }
    }
}
