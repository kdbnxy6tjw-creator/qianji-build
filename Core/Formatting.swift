import Foundation

/// 金额一律以「分」为 Int64 存储；显示用逗号作小数点（14,37 CNY），与截图一致。
enum Money {
    /// 把录入串（如 "14,37" / "100" / "14,"）解析成分
    static func cents(fromRaw raw: String) -> Int64 {
        let clean = raw.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return 0 }
        let parts = clean.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        let yuan = Int64(parts[0]) ?? 0
        var fen: Int64 = 0
        if parts.count > 1 {
            var s = String(parts[1].prefix(2))
            while s.count < 2 { s += "0" }
            fen = Int64(s) ?? 0
        }
        return yuan * 100 + fen
    }

    /// 分 -> 可编辑录入串
    static func raw(fromCents cents: Int64) -> String {
        let v = cents < 0 ? -cents : cents
        return String(format: "%lld,%02lld", v / 100, v % 100)
    }

    /// 分 -> 展示串（负号用 U+2212）
    static func display(_ cents: Int64) -> String {
        let negative = cents < 0
        let v = negative ? -cents : cents
        return String(format: "%@%lld,%02lld", negative ? "−" : "", v / 100, v % 100)
    }

    /// 绿进红出：收入 +、支出 −
    static func signed(_ cents: Int64, kind: TransactionKind) -> String {
        (kind == .income ? "+" : "−") + display(cents) + " CNY"
    }

    static func net(_ cents: Int64) -> String { display(cents) + " CNY" }
}

enum DayKey {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        c.firstWeekday = 1   // 周日起，网格固定 7 列
        return c
    }()

    static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ date: Date) -> String { keyFormatter.string(from: date) }
    static var today: String { key(Date()) }
    static func date(_ key: String) -> Date? { keyFormatter.date(from: key) }

    private static func chineseFormatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = .current
        f.dateFormat = format
        return f
    }

    static func time(_ date: Date) -> String { chineseFormatter("HH:mm").string(from: date) }
    static func chineseDate(_ date: Date) -> String { chineseFormatter("yyyy年M月d日").string(from: date) }

    static func monthDay(_ date: Date) -> String {
        let c = calendar.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 1)月\(c.day ?? 1)日"
    }

    static func weekdayTitle(_ date: Date) -> String {
        let w = calendar.component(.weekday, from: date)
        let names = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
        return names[(w - 1 + 7) % 7]
    }
}

/// 自定义月度周期：每月 startDay 号起算，到次月 startDay 号前一天结束。
/// 起始日限制在 1...28，避免 2 月出现非法日期。
enum Cycle {
    struct Period {
        let start: Date
        let end: Date            // 开区间
        let startKey: String
        let endKey: String
        let title: String
    }

    static func make(anchor: Date, startDay: Int) -> Period {
        let cal = DayKey.calendar
        let start = min(max(startDay, 1), 28)
        let comps = cal.dateComponents([.year, .month, .day], from: anchor)
        var y = comps.year ?? 2026
        var m = comps.month ?? 1
        let d = comps.day ?? 1
        if d < start {
            m -= 1
            if m < 1 { m = 12; y -= 1 }
        }
        var dc = DateComponents()
        dc.calendar = cal
        dc.timeZone = .current
        dc.year = y
        dc.month = m
        dc.day = start
        dc.hour = 0
        dc.minute = 0
        dc.second = 0
        let s = cal.date(from: dc) ?? Date()
        let e = cal.date(byAdding: .month, value: 1, to: s) ?? s.addingTimeInterval(2_592_000)
        let last = cal.date(byAdding: .day, value: -1, to: e) ?? e
        return Period(start: s,
                      end: e,
                      startKey: DayKey.key(s),
                      endKey: DayKey.key(e),
                      title: DayKey.monthDay(s) + " – " + DayKey.monthDay(last))
    }
}

/// 自然月日历（不受自定义起始日影响）
enum MonthMath {
    static func monthStart(_ anchor: Date) -> Date {
        let cal = DayKey.calendar
        let c = cal.dateComponents([.year, .month], from: anchor)
        return cal.date(from: c) ?? anchor
    }

    static func shifted(_ anchor: Date, by months: Int) -> Date {
        DayKey.calendar.date(byAdding: .month, value: months, to: monthStart(anchor)) ?? anchor
    }

    static func title(_ anchor: Date) -> String {
        let c = DayKey.calendar.dateComponents([.year, .month], from: monthStart(anchor))
        return "\(c.year ?? 2026)年\(c.month ?? 1)月"
    }

    /// 首格按周日对齐，空位用 nil 补齐
    static func cells(_ anchor: Date) -> [Date?] {
        let cal = DayKey.calendar
        let first = monthStart(anchor)
        let weekday = cal.component(.weekday, from: first)  // 1 = 周日
        let count = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        var out: [Date?] = Array(repeating: nil, count: max(0, weekday - 1))
        for i in 0..<count {
            out.append(cal.date(byAdding: .day, value: i, to: first))
        }
        while out.count % 7 != 0 { out.append(nil) }
        return out
    }
}
