import CoreData
import Foundation

/// 纯本地 Core Data 栈。
/// 模型用代码构建（而不是 .xcdatamodeld），好处是：工程里全是 .swift 纯文本，
/// 不需要 Xcode 的 model 编译规则 / codegen，未签名打包时零额外配置。
final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    private init() {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "QianJi", managedObjectModel: model)

        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("QianJi.sqlite")

        let desc = NSPersistentStoreDescription(url: url)
        // 2.0.0：MNTransaction 新增可选属性 deletedAt，属于 Core Data 轻量迁移
        // （加可选属性 / 加新实体都在自动迁移能力范围内），老库打开时自动补 nil。
        desc.shouldMigrateStoreAutomatically = true
        desc.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [desc]

        container.loadPersistentStores { _, error in
            if let error = error {
                // 开发期直接暴露问题，避免静默丢数据
                assertionFailure("Core Data 存储加载失败：\(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func save() {
        let ctx = container.viewContext
        guard ctx.hasChanges else { return }
        do {
            try ctx.save()
        } catch {
            print("[QianJi] 保存失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 程序化模型

    private static func attr(_ name: String,
                             _ type: NSAttributeType,
                             optional: Bool = false) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name
        a.attributeType = type
        a.isOptional = optional
        return a
    }

    private static func entity(_ name: String, _ props: [NSPropertyDescription]) -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = name
        e.managedObjectClassName = name   // 与 @objc(MNxxx) 运行时名一致
        e.properties = props
        return e
    }

    static func makeModel() -> NSManagedObjectModel {
        let wallet = entity("MNWallet", [
            attr("id", .UUIDAttributeType),
            attr("name", .stringAttributeType),
            attr("kind", .stringAttributeType),
            attr("symbol", .stringAttributeType),
            attr("colorHex", .stringAttributeType),
            attr("initialCents", .integer64AttributeType),
            attr("sortIndex", .integer64AttributeType),
            attr("isArchived", .booleanAttributeType),
            attr("createdAt", .dateAttributeType)
        ])

        let category = entity("MNCategory", [
            attr("id", .UUIDAttributeType),
            attr("name", .stringAttributeType),
            attr("symbol", .stringAttributeType),
            attr("colorHex", .stringAttributeType),
            attr("isBuiltIn", .booleanAttributeType),
            attr("isHidden", .booleanAttributeType),
            attr("isOther", .booleanAttributeType),
            attr("sortIndex", .integer64AttributeType),
            attr("createdAt", .dateAttributeType)
        ])

        let tx = entity("MNTransaction", [
            attr("id", .UUIDAttributeType),
            attr("kind", .stringAttributeType),
            attr("cents", .integer64AttributeType),
            attr("walletId", .UUIDAttributeType),
            attr("walletName", .stringAttributeType),
            attr("categoryId", .UUIDAttributeType),
            attr("categoryName", .stringAttributeType),
            attr("categorySymbol", .stringAttributeType),
            attr("categoryColorHex", .stringAttributeType),
            attr("day", .stringAttributeType),
            attr("occurredAt", .dateAttributeType),
            attr("note", .stringAttributeType),
            attr("createdAt", .dateAttributeType),
            attr("deletedAt", .dateAttributeType, optional: true)   // 2.0.0 回收站
        ])

        let budget = entity("MNBudget", [
            attr("day", .stringAttributeType),
            attr("cents", .integer64AttributeType),
            attr("createdAt", .dateAttributeType)
        ])

        let model = NSManagedObjectModel()
        model.entities = [wallet, category, tx, budget]
        return model
    }
}

// MARK: - 首次启动种子数据（对齐截图的 8 个内置分类）

enum AppBootstrap {
    static let builtInCategories: [(String, String, String)] = [
        ("退款", "arrow.uturn.left.circle.fill", "#4E8CF7"),
        ("吃饭", "fork.knife", "#8E9AAF"),
        ("出行", "car.fill", "#7C8698"),
        ("日用", "bag.fill", "#8A8F9A"),
        ("看病", "cross.case.fill", "#6E7B8C"),
        ("交易手续费", "arrow.left.arrow.right", "#7F8896"),
        ("余额调整", "slider.horizontal.3", "#6F7A88"),
        ("其他", "ellipsis", "#34C759")
    ]

    static func ensureSeeded() {
        let ctx = PersistenceController.shared.container.viewContext

        if (try? ctx.count(for: MNCategory.fetchRequest())) == 0 {
            for (index, item) in builtInCategories.enumerated() {
                let c = NSEntityDescription.insertNewObject(forEntityName: "MNCategory", into: ctx) as! MNCategory
                c.id = UUID()
                c.name = item.0
                c.symbol = item.1
                c.colorHex = item.2
                c.isBuiltIn = true
                c.isHidden = false
                c.isOther = (item.0 == "其他")
                c.sortIndex = Int64(index)
                c.createdAt = Date()
            }
        }

        if (try? ctx.count(for: MNWallet.fetchRequest())) == 0 {
            let w = NSEntityDescription.insertNewObject(forEntityName: "MNWallet", into: ctx) as! MNWallet
            w.id = UUID()
            w.name = "现金"
            w.kind = WalletKind.cash.rawValue
            w.symbol = "banknote"
            w.colorHex = "#4E8CF7"
            w.initialCents = 0
            w.sortIndex = 0
            w.isArchived = false
            w.createdAt = Date()
        }

        PersistenceController.shared.save()
    }
}
