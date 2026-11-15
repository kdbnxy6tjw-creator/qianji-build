import Foundation
import UIKit

/// 统一触感层。
///
/// 分工按 Apple 的语义来，避免"处处都震"：
/// - `selection` → **状态/选项变了**：切底栏、切收支、选分类、选日期、改顺序
/// - `tap / press / longPress / soft` → **按到了某个东西**：键盘、加号、长按起泡、列表项
/// - `success / warning / error` → **有结果了**：账单保存、预算设置、删除、无效操作
///
/// 说明：
/// - 模拟器没有触感，真机才有；
/// - 用户在「iOS 设置 → 声音与触感 → 系统触感」里关掉后，系统会自动静默，无需额外开关；
/// - 工程里因此**不新增设置项**，保持之前定稿的设置页结构；
/// - 所有 API 都是 iOS 13+，16.3.1 上稳；不用 Core Haptics，避免引入额外 entitlements。
enum Haptics {

    // 静态持有并预热：UIFeedbackGenerator 在 prepare() 之后延迟最低，
    // 键盘这种连续输入场景尤其明显。
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// App 启动时预热一次
    static func prepareAll() {
        onMain {
            lightGenerator.prepare()
            mediumGenerator.prepare()
            softGenerator.prepare()
            selectionGenerator.prepare()
            notificationGenerator.prepare()
        }
    }

    /// 页面即将高频交互前可再预热（如打开 ＋ 页）
    static func prepareKeypad() {
        onMain {
            lightGenerator.prepare()
            selectionGenerator.prepare()
        }
    }

    // MARK: - 状态改变

    /// 选项/状态切换：轻到几乎只是"咔"一下
    static func selection() {
        onMain {
            selectionGenerator.selectionChanged()
            selectionGenerator.prepare()
        }
    }

    // MARK: - 物理按压

    /// 键盘按键：带节流，快速连按不会糊成一串
    static func tap() {
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastTapAt >= minTapInterval else { return }
        lastTapAt = now
        onMain {
            lightGenerator.impactOccurred()
            lightGenerator.prepare()
        }
    }

    /// 明确按下一个控件（加号、保存胶囊等）
    static func press() {
        onMain {
            mediumGenerator.impactOccurred()
            mediumGenerator.prepare()
        }
    }

    /// 长按触发浮层：比 press 更"实"一点，作为手势被识别的确认
    static func longPress() {
        onMain {
            mediumGenerator.impactOccurred(intensity: 0.85)
            mediumGenerator.prepare()
        }
    }

    /// 最轻的一档：列表项点开、折叠展开
    static func soft() {
        onMain {
            softGenerator.impactOccurred()
            softGenerator.prepare()
        }
    }

    // MARK: - 结果确认

    /// 真正完成一件事：账单已保存、预算已设置、备份已导出
    static func success() {
        onMain {
            notificationGenerator.notificationOccurred(.success)
            notificationGenerator.prepare()
        }
    }

    /// 破坏性 / 需要留神：删除、清除预算
    static func warning() {
        onMain {
            notificationGenerator.notificationOccurred(.warning)
            notificationGenerator.prepare()
        }
    }

    /// 操作失败 / 校验不通过
    static func error() {
        onMain {
            notificationGenerator.notificationOccurred(.error)
            notificationGenerator.prepare()
        }
    }

    // MARK: - 内部

    private static var lastTapAt: TimeInterval = 0
    private static let minTapInterval: TimeInterval = 0.035

    private static func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}
