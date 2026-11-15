import CoreData
import Foundation
import SwiftUI

// MARK: - 轻量枚举（全部以字符串落库，避免 Core Data 数值枚举迁移问题）

enum TransactionKind: String, CaseIterable, Identifiable {
    case expense
    case income
    var id: String { rawValue }
    var title: String { self == .expense ? "支出" : "收入" }
}

enum WalletKind: String, CaseIterable, Identifiable {
    case cash
    case bank
    case ewallet
    case credit

    var id: String { rawValue }
    var title: String {
        switch self {
        case .cash: return "现金"
        case .bank: return "银行账户"
        case .ewallet: return "电子钱包"
        case .credit: return "信用卡"
        }
    }
    var groupTitle: String {
        switch self {
        case .cash, .ewallet: return "现金和电子钱包"
        case .bank: return "银行账户"
        case .credit: return "信用卡"
        }
    }
    var symbol: String {
        switch self {
        case .cash: return "banknote"
        case .bank: return "building.columns.fill"
        case .ewallet: return "apps.iphone"
        case .credit: return "creditcard.fill"
        }
    }
}

enum CategoryLayout: String, CaseIterable, Identifiable {
    case grid2x4
    case scroll1x6
    var id: String { rawValue }
    var title: String { self == .grid2x4 ? "2 × 4 宫格" : "1 × 6 横滑" }
}

enum ReminderMode: String, CaseIterable, Identifiable {
    case sameDay
    case dayBefore
    var id: String { rawValue }
    var title: String { self == .sameDay ? "当天 00:05" : "提前一天 20:00" }
}

// MARK: - 托管对象（模型用代码构建，见 Persistence.swift）

@objc(MNWallet)
class MNWallet: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var kind: String
    @NSManaged var symbol: String
    @NSManaged var colorHex: String
    @NSManaged var initialCents: Int64
    @NSManaged var sortIndex: Int64
    @NSManaged var isArchived: Bool
    @NSManaged var createdAt: Date

    var walletKind: WalletKind { WalletKind(rawValue: kind) ?? .cash }
    var tint: Color { Color(hex: colorHex) }
}

@objc(MNCategory)
class MNCategory: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var symbol: String
    @NSManaged var colorHex: String
    @NSManaged var isBuiltIn: Bool
    @NSManaged var isHidden: Bool
    @NSManaged var isOther: Bool
    @NSManaged var sortIndex: Int64
    @NSManaged var createdAt: Date

    var tint: Color { Color(hex: colorHex) }
}

@objc(MNTransaction)
class MNTransaction: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var kind: String
    @NSManaged var cents: Int64
    @NSManaged var walletId: UUID
    /// 钱包名快照：钱包被改名/删除后，历史账单仍显示当时的名字
    @NSManaged var walletName: String
    @NSManaged var categoryId: UUID
    /// 分类名/图标/颜色快照：隐藏或删除分类后，历史账单依旧显示原标签
    @NSManaged var categoryName: String
    @NSManaged var categorySymbol: String
    @NSManaged var categoryColorHex: String
    @NSManaged var day: String          // yyyy-MM-dd，本地日历
    @NSManaged var occurredAt: Date
    @NSManaged var note: String
    @NSManaged var createdAt: Date
    /// 2.0.0 新增：非 nil 表示已在回收站，值为移入回收站的时间。
    /// 可选属性 → Core Data 轻量迁移可自动补 nil，老数据零风险。
    @NSManaged var deletedAt: Date?

    var txKind: TransactionKind { TransactionKind(rawValue: kind) ?? .expense }
    var categoryTint: Color { Color(hex: categoryColorHex) }
    var isDeleted: Bool { deletedAt != nil }
}

@objc(MNBudget)
class MNBudget: NSManagedObject {
    @NSManaged var day: String
    @NSManaged var cents: Int64
    @NSManaged var createdAt: Date
}

// MARK: - fetchRequest（手写子类需要自己提供）

extension MNWallet {
    @nonobjc class func fetchRequest() -> NSFetchRequest<MNWallet> {
        NSFetchRequest<MNWallet>(entityName: "MNWallet")
    }
}
extension MNCategory {
    @nonobjc class func fetchRequest() -> NSFetchRequest<MNCategory> {
        NSFetchRequest<MNCategory>(entityName: "MNCategory")
    }
}
extension MNTransaction {
    @nonobjc class func fetchRequest() -> NSFetchRequest<MNTransaction> {
        NSFetchRequest<MNTransaction>(entityName: "MNTransaction")
    }
}
extension MNBudget {
    @nonobjc class func fetchRequest() -> NSFetchRequest<MNBudget> {
        NSFetchRequest<MNBudget>(entityName: "MNBudget")
    }
}
