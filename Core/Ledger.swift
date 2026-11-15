import Foundation

/// 纯函数统计层：所有金额计算都从这里走，视图不自己算账。
enum Ledger {
    /// 2.0.0：统计口径统一过滤回收站。回收站里的账目不算收入、不算支出、不算余额，
    /// 也不进日历网格 —— 视觉上等同于"已移出账本"，但还能从回收站捞回来。
    static func totals(_ txs: [MNTransaction],
                       where predicate: (MNTransaction) -> Bool) -> (income: Int64, expense: Int64) {
        var income: Int64 = 0
        var expense: Int64 = 0
        for t in txs where t.deletedAt == nil && predicate(t) {
            if t.txKind == .income { income += t.cents } else { expense += t.cents }
        }
        return (income, expense)
    }

    static func day(_ txs: [MNTransaction], _ key: String) -> (income: Int64, expense: Int64) {
        totals(txs) { $0.day == key }
    }

    static func range(_ txs: [MNTransaction], from: String, to: String) -> (income: Int64, expense: Int64) {
        totals(txs) { $0.day >= from && $0.day < to }
    }

    static func dayNet(_ txs: [MNTransaction], _ key: String) -> Int64 {
        let t = day(txs, key)
        return t.income - t.expense
    }

    static func balance(_ txs: [MNTransaction], walletId: UUID, initial: Int64) -> Int64 {
        var value = initial
        for t in txs where t.deletedAt == nil && t.walletId == walletId {
            value += (t.txKind == .income ? t.cents : -t.cents)
        }
        return value
    }

    /// 钱包资金总和：信用卡可为负，因此直接相加
    static func totalAssets(_ txs: [MNTransaction], wallets: [MNWallet]) -> Int64 {
        wallets.filter { !$0.isArchived }.reduce(Int64(0)) {
            $0 + balance(txs, walletId: $1.id, initial: $1.initialCents)
        }
    }

    /// 自然月内每天的净额，供日历网格使用
    static func netByDay(_ txs: [MNTransaction], month anchor: Date) -> [String: Int64] {
        let start = DayKey.key(MonthMath.monthStart(anchor))
        let end = DayKey.key(MonthMath.shifted(anchor, by: 1))
        var out: [String: Int64] = [:]
        for t in txs where t.deletedAt == nil && t.day >= start && t.day < end {
            out[t.day, default: 0] += (t.txKind == .income ? t.cents : -t.cents)
        }
        return out
    }

    static func groupedByDay(_ txs: [MNTransaction]) -> [(key: String, items: [MNTransaction])] {
        let grouped = Dictionary(grouping: txs.filter { $0.deletedAt == nil }) { $0.day }
        return grouped.keys.sorted(by: >).map { key in
            let items = (grouped[key] ?? []).sorted {
                if $0.occurredAt != $1.occurredAt { return $0.occurredAt > $1.occurredAt }
                return $0.createdAt > $1.createdAt
            }
            return (key, items)
        }
    }
}
