import CoreData
import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - 纯本地备份（导出 JSON / 导入恢复），不经过任何服务器

struct BackupPayload: Codable {
    var version: Int
    var exportedAt: TimeInterval
    var wallets: [BWallet]
    var categories: [BCategory]
    var transactions: [BTransaction]
    var budgets: [BBudget]
    var settings: BSettings
}

struct BWallet: Codable {
    var id: UUID; var name: String; var kind: String; var symbol: String
    var colorHex: String; var initialCents: Int64; var sortIndex: Int64
    var isArchived: Bool; var createdAt: TimeInterval
}
struct BCategory: Codable {
    var id: UUID; var name: String; var symbol: String; var colorHex: String
    var isBuiltIn: Bool; var isHidden: Bool; var isOther: Bool
    var sortIndex: Int64; var createdAt: TimeInterval
}
struct BTransaction: Codable {
    var id: UUID; var kind: String; var cents: Int64
    var walletId: UUID; var walletName: String
    var categoryId: UUID; var categoryName: String
    var categorySymbol: String; var categoryColorHex: String
    var day: String; var occurredAt: TimeInterval; var note: String
    var createdAt: TimeInterval
    var deletedAt: TimeInterval?
}
struct BBudget: Codable {
    var day: String; var cents: Int64; var createdAt: TimeInterval
}
struct BSettings: Codable {
    var defaultKind: String; var monthStartDay: Int; var categoryLayout: String
    var reminderEnabled: Bool; var reminderMode: String
    var reminderHour: Int; var reminderMinute: Int
    var showTabLabels: Bool?; var showCategoryLabels: Bool?
    var confirmBeforeDelete: Bool?; var recycleTTL: String?
}

enum BackupManager {
    static func exportURL(txs: [MNTransaction],
                          wallets: [MNWallet],
                          categories: [MNCategory],
                          budgets: [MNBudget],
                          settings: AppSettings) throws -> URL {
        let p = BackupPayload(
            version: 2,
            exportedAt: Date().timeIntervalSince1970,
            wallets: wallets.map {
                BWallet(id: $0.id, name: $0.name, kind: $0.kind, symbol: $0.symbol,
                        colorHex: $0.colorHex, initialCents: $0.initialCents,
                        sortIndex: $0.sortIndex, isArchived: $0.isArchived,
                        createdAt: $0.createdAt.timeIntervalSince1970)
            },
            categories: categories.map {
                BCategory(id: $0.id, name: $0.name, symbol: $0.symbol, colorHex: $0.colorHex,
                          isBuiltIn: $0.isBuiltIn, isHidden: $0.isHidden, isOther: $0.isOther,
                          sortIndex: $0.sortIndex, createdAt: $0.createdAt.timeIntervalSince1970)
            },
            transactions: txs.map {
                BTransaction(id: $0.id, kind: $0.kind, cents: $0.cents,
                             walletId: $0.walletId, walletName: $0.walletName,
                             categoryId: $0.categoryId, categoryName: $0.categoryName,
                             categorySymbol: $0.categorySymbol,
                             categoryColorHex: $0.categoryColorHex,
                             day: $0.day, occurredAt: $0.occurredAt.timeIntervalSince1970,
                             note: $0.note, createdAt: $0.createdAt.timeIntervalSince1970)
            },
            budgets: budgets.map {
                BBudget(day: $0.day, cents: $0.cents, createdAt: $0.createdAt.timeIntervalSince1970)
            },
            settings: BSettings(defaultKind: settings.defaultKind.rawValue,
                                monthStartDay: settings.monthStartDay,
                                categoryLayout: settings.categoryLayout.rawValue,
                                reminderEnabled: settings.reminderEnabled,
                                reminderMode: settings.reminderMode.rawValue,
                                reminderHour: settings.reminderHour,
                                reminderMinute: settings.reminderMinute)
        )
        let data = try JSONEncoder().encode(p)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("钱迹备份-\(DayKey.today).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func restore(data: Data, ctx: NSManagedObjectContext, settings: AppSettings) throws {
        let p = try JSONDecoder().decode(BackupPayload.self, from: data)

        for name in ["MNTransaction", "MNBudget", "MNWallet", "MNCategory"] {
            let req = NSFetchRequest<NSManagedObject>(entityName: name)
            for object in ((try? ctx.fetch(req)) ?? []) { ctx.delete(object) }
        }

        let existingWalletIDs = Set((try? ctx.fetch(MNWallet.fetchRequest()))?.map { $0.id } ?? [])
        let existingCategoryIDs = Set((try? ctx.fetch(MNCategory.fetchRequest()))?.map { $0.id } ?? [])
        let existingTxIDs = Set((try? ctx.fetch(MNTransaction.fetchRequest()))?.map { $0.id } ?? [])
        let existingBudgetDays = Set((try? ctx.fetch(MNBudget.fetchRequest()))?.map { $0.day } ?? [])

        for w in p.wallets where !existingWalletIDs.contains(w.id) {
            let o = NSEntityDescription.insertNewObject(forEntityName: "MNWallet", into: ctx) as! MNWallet
            o.id = w.id; o.name = w.name; o.kind = w.kind; o.symbol = w.symbol
            o.colorHex = w.colorHex; o.initialCents = w.initialCents; o.sortIndex = w.sortIndex
            o.isArchived = w.isArchived; o.createdAt = Date(timeIntervalSince1970: w.createdAt)
        }
        for c in p.categories where !existingCategoryIDs.contains(c.id) {
            let o = NSEntityDescription.insertNewObject(forEntityName: "MNCategory", into: ctx) as! MNCategory
            o.id = c.id; o.name = c.name; o.symbol = c.symbol; o.colorHex = c.colorHex
            o.isBuiltIn = c.isBuiltIn; o.isHidden = c.isHidden; o.isOther = c.isOther
            o.sortIndex = c.sortIndex; o.createdAt = Date(timeIntervalSince1970: c.createdAt)
        }
        for t in p.transactions where !existingTxIDs.contains(t.id) {
            let o = NSEntityDescription.insertNewObject(forEntityName: "MNTransaction", into: ctx) as! MNTransaction
            o.id = t.id; o.kind = t.kind; o.cents = t.cents
            o.walletId = t.walletId; o.walletName = t.walletName
            o.categoryId = t.categoryId; o.categoryName = t.categoryName
            o.categorySymbol = t.categorySymbol; o.categoryColorHex = t.categoryColorHex
            o.day = t.day; o.occurredAt = Date(timeIntervalSince1970: t.occurredAt)
            o.deletedAt = t.deletedAt.map { Date(timeIntervalSince1970: $0) }
            o.note = t.note; o.createdAt = Date(timeIntervalSince1970: t.createdAt)
        }
        for b in p.budgets where !existingBudgetDays.contains(b.day) {
            let o = NSEntityDescription.insertNewObject(forEntityName: "MNBudget", into: ctx) as! MNBudget
            o.day = b.day; o.cents = b.cents
            o.createdAt = Date(timeIntervalSince1970: b.createdAt)
        }
        PersistenceController.shared.save()

        settings.defaultKind = TransactionKind(rawValue: p.settings.defaultKind) ?? .expense
        settings.monthStartDay = p.settings.monthStartDay
        settings.categoryLayout = CategoryLayout(rawValue: p.settings.categoryLayout) ?? .grid2x4
        settings.reminderEnabled = p.settings.reminderEnabled
        settings.reminderMode = ReminderMode(rawValue: p.settings.reminderMode) ?? .sameDay
        settings.reminderHour = p.settings.reminderHour
        settings.reminderMinute = p.settings.reminderMinute
        settings.showTabLabels = p.settings.showTabLabels ?? true
        settings.showCategoryLabels = p.settings.showCategoryLabels ?? true
        settings.confirmBeforeDelete = p.settings.confirmBeforeDelete ?? true
        settings.recycleTTL = RecycleTTL(rawValue: p.settings.recycleTTL ?? "days7") ?? .days7
        NotificationCenter.default.post(name: AppSettings.changedNotification, object: nil)
    }
}

/// UIKit 分享面板，避开 iOS 16 上 ShareLink 的 Transferable 兼容问题
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct BackupSection: View {
    let txs: [MNTransaction]
    let wallets: [MNWallet]
    let categories: [MNCategory]
    let budgets: [MNBudget]

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.managedObjectContext) private var ctx

    @State private var shareURL: URL?
    @State private var showImporter = false
    @State private var showRestoreConfirm = false
    @State private var pendingData: Data?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    do {
                        shareURL = try BackupManager.exportURL(txs: txs,
                                                               wallets: wallets,
                                                               categories: categories,
                                                               budgets: budgets,
                                                               settings: settings)
                        Haptics.success()
                    } catch {
                        Haptics.error()
                        message = "导出失败：\(error.localizedDescription)"
                    }
                } label: {
                    Label("导出备份", systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .medium))
                }
                .pressScale(0.92, animation: Motion.snap)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Capsule().fill(AppTheme.card2))

                Button {
                    showImporter = true
                } label: {
                    Label("导入备份", systemImage: "square.and.arrow.down")
                        .font(.system(size: 13, weight: .medium))
                }
                .pressScale(0.92, animation: Motion.snap)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Capsule().fill(AppTheme.card2))
            }
            .foregroundStyle(AppTheme.accent)

            Text("数据只存在这台设备的 App 沙盒里，没有账号、没有 iCloud、没有服务器。换机或重装前请先导出备份。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            if let message = message {
                Text(message).font(.caption).foregroundStyle(AppTheme.expense)
            }
        }
        .sheet(item: Binding(get: {
            shareURL.map { ShareRoute(url: $0) }
        }, set: { _ in shareURL = nil })) { route in
            ShareSheet(url: route.url)
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    pendingData = data
                    showRestoreConfirm = true
                } else {
                    Haptics.error()
                    message = "读取文件失败"
                }
            case .failure(let error):
                Haptics.error()
                message = "选择文件失败：\(error.localizedDescription)"
            }
        }
        .alert("用备份覆盖当前数据？", isPresented: $showRestoreConfirm) {
            Button("覆盖并恢复", role: .destructive) {
                if let data = pendingData {
                    do {
                        try BackupManager.restore(data: data, ctx: ctx, settings: settings)
                        Haptics.success()
                        message = "已恢复备份"
                    } catch {
                        Haptics.error()
                        message = "恢复失败：\(error.localizedDescription)"
                    }
                }
                pendingData = nil
            }
            Button("取消", role: .cancel) { pendingData = nil }
        } message: {
            Text("当前设备上的全部钱包、分类、账单和预算会被备份文件替换，操作不可撤销。")
        }
    }
}

struct ShareRoute: Identifiable {
    let id = UUID()
    let url: URL
}
