import SwiftUI

/// 全 app 唯一的动画真源（SemVer 2.0.0 新增）。
///
/// 设计原则：
/// - 所有交互都从这里取参数，视图里**不允许**再手写 `.spring(response:...)` 魔数；
/// - 只有三档弹簧，覆盖「状态切换 / 按压回弹 / 浮层进出」，避免同一 app 里手感不一；
/// - 时长类动画（淡入、位移）统一走 `easeOutSwift`，不做弹簧，避免叠加抖动。
enum Motion {
    /// 状态切换：切底栏、切收支、选分类、选日期。
    /// 偏 Q 弹但收敛快，连续点也不会晃。
    static let snap = Animation.spring(response: 0.34, dampingFraction: 0.62)

    /// 按压回弹：按钮按下缩小 / 抬手弹回，以及玻璃胶囊的缩放。
    /// 比 snap 更弹，抬手时能明显看到「冲过一点再收回」。
    static let pop = Animation.spring(response: 0.30, dampingFraction: 0.55)

    /// 浮层进出：起泡弹窗、二次确认、回收站弹出的卡片。
    /// 阻尼高，不来回晃，只做一次柔和落位。
    static let settle = Animation.spring(response: 0.36, dampingFraction: 0.82)

    /// 纯位移 / 透明度：展开折叠、列表插入删除。
    static let easeOutSwift = Animation.easeOut(duration: 0.22)

    /// 列表项增删的合并动画
    static let rowInsert = Animation.spring(response: 0.32, dampingFraction: 0.86)

    // MARK: - 缩放系数（全 app 统一，不再各处写 0.92 / 0.94 / 0.985）

    /// 普通按钮按下缩放
    static let pressScale: CGFloat = 0.94
    /// 大块卡片 / 列表行按下缩放（几乎不动，只给一点反馈）
    static let cardPressScale: CGFloat = 0.985
    /// 玻璃胶囊本体的按下缩小（配合上层放大，形成"挤压"感）
    static let glassPressScale: CGFloat = 0.92
    /// 选中态玻璃胶囊相对未选中态的常态放大
    static let glassSelectedScale: CGFloat = 1.06
}

/// 统一的「按下缩小 + 弹簧回弹」按钮样式。
/// 替代原先散落在各处的 `ScaleButtonStyle`，保证全 app 手感一致。
struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = Motion.pressScale
    var animation: Animation = Motion.pop

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(animation, value: configuration.isPressed)
    }
}

extension View {
    /// 按下缩放。用于普通按钮。
    func pressScale(_ scale: CGFloat = Motion.pressScale,
                    animation: Animation = Motion.pop) -> some View {
        buttonStyle(PressScaleStyle(scale: scale, animation: animation))
    }

    /// 随某个 Bool 状态做弹簧缩放（选中态放大等）
    func popScale(_ active: Bool,
                  scale: CGFloat = Motion.glassSelectedScale,
                  animation: Animation = Motion.pop) -> some View {
        self.scaleEffect(active ? scale : 1.0).animation(animation, value: active)
    }
}
