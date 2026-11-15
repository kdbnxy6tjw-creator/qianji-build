import CoreData
import Foundation

// MARK: - 交易

enum TransactionStore {
    static func upsert(ctx: NSManagedObjectContext,
                       editing: MNTransaction?,
                       kind: TransactionKind,
                       cents: Int64,
                       wallet: MNWallet,
                       category: MNCategory,
                       date: Date,
                       note: String) {
        let t: MNTransaction
        if let editing = editing {
            t = editing
        } else {
            t = NSEntityDescription.insertNewObject(forEntityName: "MNTransaction", into: ctx) as! MNTransaction
            t.id = UUID()
            t.createdAt = Date()
        }
        t.kind = kind.rawValue
        t.cents = cents
        t.walletId = wallet.id
        t.walletName = wallet.name
        t.categoryId = category.id
        // 快照：分类隐藏 / 删除 / 改名后，这笔账永远显示当时的标签
        t.categoryName = category.name
        t.categorySymbol = category.symbol
        t.categoryColorHex = category.colorHex
        t.day = DayKey.key(date)
        t.occurredAt = date
        t.note = note
        // 编辑一笔在回收站里的账单并保存 → 自动从回收站捞回
        t.deletedAt = nil
        PersistenceController.shared.save()
    }

    /// 2.0.0：软删除。账目不消失，移入回收站并记录时间。
    static func softDelete(ctx: NSManagedObjectContext, _ t: MNTransaction, at date: Date = Date()) {
        t.deletedAt = date
        PersistenceController.shared.save()
    }

    /// 2.0.0：从回收站恢复
    static func restore(ctx: NSManagedObjectContext, _ t: MNTransaction) {
        t.deletedAt = nil
        PersistenceController.shared.save()
    }

    /// 2.0.0：回收站内单条彻底删除
    static func purge(ctx: NSManagedObjectContext, _ t: MNTransaction) {
        ctx.delete(t)
        PersistenceController.shared.save()
    }

    /// 2.0.0：清空整个回收站
    static func purgeAll(ctx: NSManagedObjectContext, items: [MNTransaction]) {
        for t in items { ctx.delete(t) }
        PersistenceController.shared.save()
    }

    /// 2.0.0：按全局保留时长清理过期条目。返回被清掉的条数（>0 时调用方刷新 UI）。
    /// 只在进前台时调用，不依赖后台定时。
    @discardableResult
    static func purgeExpired(ctx: NSManagedObjectContext,
                            ttl: RecycleTTL,
                            now: Date = Date()) -> Int {
        guard let seconds = ttl.seconds else { return 0 }
        let req = MNTransaction.fetchRequest()
        req.predicate = NSPredicate(format: "deletedAt != nil AND deletedAt <= %@",
                                    now.addingTimeInterval(-seconds) as NSDate)
        let expired = (try? ctx.fetch(req)) ?? []
        guard !expired.isEmpty else { return 0 }
        for t in expired { ctx.delete(t) }
        PersistenceController.shared.save()
        return expired.count
    }

    /// 彻底删除（v1 遗留路径）：仅设置页"直接删除"用，正常流程走软删除
    static func delete(ctx: NSManagedObjectContext, _ t: MNTransaction) {
        ctx.delete(t)
        PersistenceController.shared.save()
    }
}

// MARK: - 预算（按日期一天一条）

enum BudgetStore {
    static func budget(_ budgets: [MNBudget], for day: String) -> MNBudget? {
        budgets.first { $0.day == day }
    }

    static func set(ctx: NSManagedObjectContext, day: String, cents: Int64) {
        let req = MNBudget.fetchRequest()
        req.predicate = NSPredicate(format: "day == %@", day)
        req.fetchLimit = 1
        let existing = (try? ctx.fetch(req))?.first
        if cents <= 0 {
            if let existing = existing { ctx.delete(existing) }
        } else if let existing = existing {
            existing.cents = cents
            existing.createdAt = Date()
        } else {
            let b = NSEntityDescription.insertNewObject(forEntityName: "MNBudget", into: ctx) as! MNBudget
            b.day = day
            b.cents = cents
            b.createdAt = Date()
        }
        PersistenceController.shared.save()
        NotificationCenter.default.post(name: AppSettings.changedNotification, object: nil)
    }
}

// MARK: - 钱包

enum WalletStore {
    static func upsert(ctx: NSManagedObjectContext,
                       editing: MNWallet?,
                       name: String,
                       kind: WalletKind,
                       symbol: String,
                       colorHex: String,
                       initialCents: Int64) {
        let w: MNWallet
        if let editing = editing {
            w = editing
        } else {
            w = NSEntityDescription.insertNewObject(forEntityName: "MNWallet", into: ctx) as! MNWallet
            w.id = UUID()
            w.sortIndex = Int64((try? ctx.count(for: MNWallet.fetchRequest())) ?? 0)
            w.isArchived = false
            w.createdAt = Date()
        }
        w.name = name
        w.kind = kind.rawValue
        w.symbol = symbol
        w.colorHex = colorHex
        w.initialCents = initialCents
        PersistenceController.shared.save()
    }

    static func transactionCount(_ txs: [MNTransaction], walletId: UUID) -> Int {
        txs.filter { $0.walletId == walletId }.count
    }

    static func delete(ctx: NSManagedObjectContext, _ w: MNWallet) {
        ctx.delete(w)
        PersistenceController.shared.save()
    }

    static func move(ctx: NSManagedObjectContext, wallets: [MNWallet], from: Int, to: Int) {
        guard from >= 0, to >= 0, from < wallets.count, to < wallets.count else { return }
        var order = wallets
        let item = order.remove(at: from)
        order.insert(item, at: min(to, order.count))
        for (i, w) in order.enumerated() { w.sortIndex = Int64(i) }
        PersistenceController.shared.save()
    }
}

// MARK: - 分类

enum CategoryStore {
    static func visible(_ categories: [MNCategory]) -> [MNCategory] {
        categories
            .filter { !$0.isHidden && !$0.isOther }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    static func hidden(_ categories: [MNCategory]) -> [MNCategory] {
        categories
            .filter { $0.isHidden && !$0.isOther }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    static func other(_ categories: [MNCategory]) -> MNCategory? {
        categories.first { $0.isOther }
    }

    /// 录入宫格顺序：可见分类在前，「其他」永远钉在最后
    static func gridItems(_ categories: [MNCategory]) -> [MNCategory] {
        var out = visible(categories)
        if let other = other(categories) { out.append(other) }
        return out
    }

    /// 重排后重新编号，并保证「其他」始终最大
    static func normalizeOrder(ctx: NSManagedObjectContext, categories: [MNCategory]) {
        let movable = categories.filter { !$0.isOther }.sorted { $0.sortIndex < $1.sortIndex }
        for (i, c) in movable.enumerated() { c.sortIndex = Int64(i) }
        if let other = other(categories) { other.sortIndex = Int64(movable.count) }
        PersistenceController.shared.save()
    }

    static func move(ctx: NSManagedObjectContext, categories: [MNCategory], id: UUID, up: Bool) {
        var list = categories.filter { !$0.isOther }.sorted { $0.sortIndex < $1.sortIndex }
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return }
        let target = idx + (up ? -1 : 1)
        guard target >= 0, target < list.count else { return }
        list.swapAt(idx, target)
        for (i, c) in list.enumerated() { c.sortIndex = Int64(i) }
        if let other = other(categories) { other.sortIndex = Int64(list.count) }
        PersistenceController.shared.save()
    }

    static func create(ctx: NSManagedObjectContext,
                       name: String,
                       symbol: String,
                       colorHex: String) {
        let c = NSEntityDescription.insertNewObject(forEntityName: "MNCategory", into: ctx) as! MNCategory
        c.id = UUID()
        c.name = name
        c.symbol = symbol
        c.colorHex = colorHex
        c.isBuiltIn = false
        c.isHidden = false
        c.isOther = false
        c.sortIndex = Int64((try? ctx.count(for: MNCategory.fetchRequest())) ?? 0)
        c.createdAt = Date()
        normalizeOrder(ctx: ctx, categories: (try? ctx.fetch(MNCategory.fetchRequest())) ?? [])
    }

    /// 隐藏 = 放进「其他」的长按气泡；内置分类只允许隐藏，不允许删除
    static func setHidden(ctx: NSManagedObjectContext, _ c: MNCategory, hidden: Bool) {
        c.isHidden = hidden
        PersistenceController.shared.save()
    }

    /// 两种删除方式都不改写任何历史账单（账单存的是快照）
    static func remove(ctx: NSManagedObjectContext, _ c: MNCategory, archive: Bool) {
        if archive {
            c.isHidden = true
            c.isBuiltIn = false
            PersistenceController.shared.save()
        } else {
            ctx.delete(c)
            PersistenceController.shared.save()
        }
        let all = (try? ctx.fetch(MNCategory.fetchRequest())) ?? []
        normalizeOrder(ctx: ctx, categories: all)
    }
}
