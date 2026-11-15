import Combine
import Foundation

/// 设置项走 UserDefaults（本机）；分类/钱包/账单/预算走 Core Data。
/// 任何改动都发一条通知，RootView 收到后重排本地提醒。
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    static let changedNotification = Notification.Name("qj.settings.changed")

    private let d = UserDefaults.standard

    private enum Key {
        static let defaultKind = "qj.defaultKind"
        static let monthStartDay = "qj.monthStartDay"
        static let categoryLayout = "qj.categoryLayout"
        static let reminderEnabled = "qj.reminderEnabled"
        static let reminderMode = "qj.reminderMode"
        static let reminderHour = "qj.reminderHour"
        static let reminderMinute = "qj.reminderMinute"
        // 2.0.0 新增
        static let showTabLabels = "qj.showTabLabels"
        static let showCategoryLabels = "qj.showCategoryLabels"
        static let confirmBeforeDelete = "qj.confirmBeforeDelete"
        static let recycleTTL = "qj.recycleTTL"
    }

    @Published var defaultKind: TransactionKind { didSet { d.set(defaultKind.rawValue, forKey: Key.defaultKind); notify() } }
    @Published var monthStartDay: Int { didSet { d.set(min(max(monthStartDay, 1), 28), forKey: Key.monthStartDay); notify() } }
    @Published var categoryLayout: CategoryLayout { didSet { d.set(categoryLayout.rawValue, forKey: Key.categoryLayout); notify() } }
    @Published var reminderEnabled: Bool { didSet { d.set(reminderEnabled, forKey: Key.reminderEnabled); notify() } }
    @Published var reminderMode: ReminderMode { didSet { d.set(reminderMode.rawValue, forKey: Key.reminderMode); notify() } }
    @Published var reminderHour: Int { didSet { d.set(reminderHour, forKey: Key.reminderHour); notify() } }
    @Published var reminderMinute: Int { didSet { d.set(reminderMinute, forKey: Key.reminderMinute); notify() } }

    // MARK: - 2.0.0 新增开关

    /// 底栏图标下方的文字：关掉后图标放大，底栏高度不变
    @Published var showTabLabels: Bool { didSet { d.set(showTabLabels, forKey: Key.showTabLabels); notify() } }
    /// ＋页分类宫格下方的类别名：关掉后图标瓦片放大
    @Published var showCategoryLabels: Bool { didSet { d.set(showCategoryLabels, forKey: Key.showCategoryLabels); notify() } }
    /// 右滑删除前是否二次确认（默认开）
    @Published var confirmBeforeDelete: Bool { didSet { d.set(confirmBeforeDelete, forKey: Key.confirmBeforeDelete); notify() } }
    /// 回收站保留时长（全局唯一设置）
    @Published var recycleTTL: RecycleTTL { didSet { d.set(recycleTTL.rawValue, forKey: Key.recycleTTL); notify() } }

    private init() {
        defaultKind = TransactionKind(rawValue: d.string(forKey: Key.defaultKind) ?? "expense") ?? .expense
        let savedDay = d.integer(forKey: Key.monthStartDay)
        monthStartDay = (1...28).contains(savedDay) ? savedDay : 1
        categoryLayout = CategoryLayout(rawValue: d.string(forKey: Key.categoryLayout) ?? "grid2x4") ?? .grid2x4
        reminderEnabled = (d.object(forKey: Key.reminderEnabled) as? Bool) ?? true
        reminderMode = ReminderMode(rawValue: d.string(forKey: Key.reminderMode) ?? "sameDay") ?? .sameDay
        reminderHour = (d.object(forKey: Key.reminderHour) as? Int) ?? 0
        reminderMinute = (d.object(forKey: Key.reminderMinute) as? Int) ?? 5

        showTabLabels = (d.object(forKey: Key.showTabLabels) as? Bool) ?? true
        showCategoryLabels = (d.object(forKey: Key.showCategoryLabels) as? Bool) ?? true
        confirmBeforeDelete = (d.object(forKey: Key.confirmBeforeDelete) as? Bool) ?? true
        recycleTTL = RecycleTTL(rawValue: d.string(forKey: Key.recycleTTL) ?? "days7") ?? .days7
    }

    /// 切换提醒模式时把时间一并复位到约定默认值
    func setReminderMode(_ mode: ReminderMode) {
        reminderMode = mode
        if mode == .sameDay {
            reminderHour = 0
            reminderMinute = 5
        } else {
            reminderHour = 20
            reminderMinute = 0
        }
    }

    func setReminderTime(_ date: Date) {
        let c = DayKey.calendar.dateComponents([.hour, .minute], from: date)
        reminderHour = c.hour ?? 0
        reminderMinute = c.minute ?? 5
    }

    var reminderDate: Date {
        var c = DayKey.calendar.dateComponents([.year, .month, .day], from: Date())
        c.hour = reminderHour
        c.minute = reminderMinute
        return DayKey.calendar.date(from: c) ?? Date()
    }

    var reminderTimeString: String {
        String(format: "%02d:%02d", reminderHour, reminderMinute)
    }

    private func notify() {
        NotificationCenter.default.post(name: Self.changedNotification, object: nil)
    }
}

/// 回收站保留时长。全局唯一设置，不做逐条计时。
enum RecycleTTL: String, CaseIterable, Identifiable {
    case days3
    case days7
    case days30
    case never

    var id: String { rawValue }

    var title: String {
        switch self {
        case .days3:  return "3 天"
        case .days7:  return "7 天"
        case .days30: return "30 天"
        case .never:  return "不自动清理"
        }
    }

    var subtitle: String {
        switch self {
        case .days3:  return "删除 3 天后彻底清除"
        case .days7:  return "删除 7 天后彻底清除"
        case .days30: return "删除 30 天后彻底清除"
        case .never:  return "一直留着，只在你手动清空时消失"
        }
    }

    /// nil 表示永不过期
    var seconds: TimeInterval? {
        switch self {
        case .days3:  return 3 * 86_400
        case .days7:  return 7 * 86_400
        case .days30: return 30 * 86_400
        case .never:  return nil
        }
    }

    /// 给定删除时间，算出彻底清除的时刻；永不清理返回 nil
    func expiry(from deletedAt: Date) -> Date? {
        guard let s = seconds else { return nil }
        return deletedAt.addingTimeInterval(s)
    }
}
