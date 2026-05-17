import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    func scheduleTimerNotification(seconds: Double) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let content = UNMutableNotificationContent()
        content.title = "Pause beendet!"
        content.body = "Weiter geht's! 💪"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "RestTimer", content: content, trigger: trigger))
    }
}//
//  NotificationManager.swift
//  Train with Me
//
//  Created by Thomas on 09.05.26.
//

