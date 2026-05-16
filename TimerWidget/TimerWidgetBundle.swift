//
//  TimerWidgetBundle.swift
//  TimerWidget
//
//  Created by Thomas on 19.02.26.
//

import WidgetKit
import SwiftUI

@main
struct TimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimerWidget()
        TimerWidgetControl()
        TimerWidgetLiveActivity()
    }
}
