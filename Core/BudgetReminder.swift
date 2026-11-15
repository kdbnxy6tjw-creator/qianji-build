import Foundation
import UserNotifications

/// 本地通知：未来 7 天逐日排一次性提醒，排之前检查那天是否已设预算（已设不发）。
/// 采用「重排」而不是 repeating trigger，这样"已设不发"可以精确成立。
enum BudgetReminder {
    static let prefix = "qj.budget."

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error = error {
                print("[QianJi] 通知授权失败：\(error.localizedDescription)")
            }
        }
    }

    static func rebuild(settings: AppSettings, budgetDays: Set<String>) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let stale = requests.filter { $0.identifier.hasPrefix(prefix) }.map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: stale)

            guard settings.reminderEnabled else { return }

            let cal = DayKey.calendar
            let now = Date()

            for offset in 0..<7 {
                guard let target = cal.date(byAdding: .day, value: offset, to: now) else { continue }
                let key = DayKey.key(target)
                if budgetDays.contains(key) { continue }

                let fireBase: Date
                if settings.reminderMode == .sameDay {
                    fireBase = target
                } else {
                    fireBase = cal.date(byAdding: .day, value: -1, to: target) ?? target
                }
                guard let fire = cal.date(bySettingHour: settings.reminderHour,
                                          minute: settings.reminderMinute,
                                          second: 0,
                                          of: fireBase),
                      fire > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "该设预算啦"
                content.body = settings.reminderMode == .sameDay
                    ? "今天还没设置支出预算，点开「钱迹」设一下吧。"
                    : "明天还没设置支出预算，现在设一下吧。"
                content.sound = .default

                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(identifier: prefix + key,
                                                    content: content,
                                                    trigger: trigger)
                center.add(request) { error in
                    if let error = error {
                        print("[QianJi] 排提醒失败：\(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
