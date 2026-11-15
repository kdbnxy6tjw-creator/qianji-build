import Foundation

/// 回收站只读查询层（写操作在 TransactionStore）。
/// 所有列表数据源都必须先过 `live(_:)`，避免回收站里的账目混进统计与列表。
enum RecycleStore {
    /// 未被删除的账目（正常业务口径）
    static func live(_ txs: [MNTransaction]) -> [MNTransaction] {
        txs.filter { $0.deletedAt == nil }
    }

    /// 回收站内的账目，按移入时间倒序（最近删的排最前）
    static func trashed(_ txs: [MNTransaction]) -> [MNTransaction] {
        txs.filter { $0.deletedAt != nil }
            .sorted { a, b in
                let da = a.deletedAt ?? .distantPast
                let db = b.deletedAt ?? .distantPast
                if da != db { return da > db }
                return a.createdAt > b.createdAt
            }
    }

    static func count(_ txs: [MNTransaction]) -> Int {
        txs.reduce(0) { $0 + ($1.deletedAt == nil ? 0 : 1) }
    }

    /// 彻底清除时刻；永不清理返回 nil
    static func expiry(of t: MNTransaction, ttl: RecycleTTL) -> Date? {
        guard let deletedAt = t.deletedAt else { return nil }
        return ttl.expiry(from: deletedAt)
    }

    /// 过期文案：已过期 / 剩 X 天 / 剩 X 小时 / 永不清理
    static func expiryText(of t: MNTransaction, ttl: RecycleTTL, now: Date = Date()) -> String {
        guard let date = expiry(of: t, ttl: ttl) else { return "不自动清理" }
        let left = date.timeIntervalSince(now)
        if left <= 0 { return "即将彻底清除" }
        let days = Int(left / 86_400)
        if days >= 1 { return "剩 \(days) 天彻底清除" }
        let hours = max(1, Int(left / 3600))
        return "剩 \(hours) 小时彻底清除"
    }

    /// 是否已在过期线上（用于标红）
    static func isExpired(_ t: MNTransaction, ttl: RecycleTTL, now: Date = Date()) -> Bool {
        guard let date = expiry(of: t, ttl: ttl) else { return false }
        return date <= now
    }

    /// 移入回收站的日期文案
    static func deletedDateText(_ t: MNTransaction) -> String {
        guard let d = t.deletedAt else { return "" }
        return DayKey.chineseDate(d) + " " + DayKey.time(d)
    }
}
