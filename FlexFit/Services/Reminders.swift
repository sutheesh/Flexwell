import Foundation
import UserNotifications
import FlexFitEngine

/// The daily check-in the user picked in onboarding ("When should I check in?"), worded in their tone.
enum Reminders {
    static let id = "daily-checkin"

    static func schedule(time: ReminderTime, tone: CoachTone) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard let hour = time.hour else { return }
        guard (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true else { return }

        let content = UNMutableNotificationContent()
        content.title = "FlexFit"
        content.body = message(tone)
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: 0), repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func message(_ tone: CoachTone) -> String {
        switch tone {
        case .direct: "Check in: energy first, then today's session."
        case .warm: "How's your energy today? Your plan will fit around it."
        case .hard: "No skipping today. Tell me your energy and I'll hand you a session you can finish."
        }
    }
}
