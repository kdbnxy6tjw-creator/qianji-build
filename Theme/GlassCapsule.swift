import SwiftUI

/// Q 弹玻璃胶囊（SemVer 2.0.0 新增）。
///
/// 目标手感：接近 iOS 27 App Store 底栏的选中态——按下去本体**缩小**、上层那层
/// 磨砂玻璃**放大**，像被挤出一块Q弹的胶质；抬手弹回并冲过一点再收住。
///
/// 明确不做的事（按需求定稿）：
/// - 不做液态玻璃的折射 / 扭曲 / 背景取样位移，只用 `Material` 磨砂 + 描边；
/// - 不依赖 iOS 17+ 的 `glassEffect`，iOS 16.3.1 上完全可用；
/// - 底栏高度不因为选中态放大而改变（放大只作用在内容层，外层槽位固定）。
struct GlassCapsule<Content: View>: View {
    /// 是否处于选中/按下状态
    let active: Bool
    /// 选中时是否连带放大内容层（底栏选中项要，普通按下按钮不要）
    var growsContent: Bool = true
    /// 形状圆角；传 .infinity 即胶囊
    var cornerRadius: CGFloat = .infinity
    /// 未选中时的底衬；nil 表示完全透明
    var idleFill: Color? = nil
    @ViewBuilder var content: () -> Content

    /// 上层玻璃相对本体放大的倍数：按下时比本体更"鼓"一点，形成挤压错位
    private let overlayGrow: CGFloat = 1.10

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            // 本体：按下缩小
            shape
                .fill(active ? Color.primary.opacity(0.10) : (idleFill ?? .clear))
                .overlay(shape.strokeBorder(Color.primary.opacity(active ? 0.10 : 0.06),
                                            lineWidth: 0.8))
                .scaleEffect(active ? Motion.glassPressScale : 1.0)
                .animation(Motion.pop, value: active)

            // 上层磨砂玻璃：按下放大 + 淡入，比本体更鼓 → 挤压感
            shape
                .fill(.ultraThinMaterial)
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .white.opacity(0.55), location: 0.0),
                                .init(color: .white.opacity(0.06), location: 0.45),
                                .init(color: .white.opacity(0.0),  location: 0.55),
                                .init(color: .black.opacity(0.16), location: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing),
                        lineWidth: 1.0)
                )
                .shadow(color: .black.opacity(active ? 0.16 : 0.0),
                        radius: active ? 8 : 0, y: active ? 4 : 0)
                .scaleEffect(active ? overlayGrow : 0.94)
                .opacity(active ? 1.0 : 0.0)
                .animation(Motion.pop, value: active)

            // 内容：跟随本体，选中态额外放大一点（图标变大，文字由调用方决定是否显示）
            content()
                .scaleEffect(active && growsContent ? Motion.glassSelectedScale : 1.0)
                .animation(Motion.pop, value: active)
        }
    }
}

/// 选中态高亮层：给底栏这类"常驻选中"的控件用，active 由外部状态驱动而不是按压。
struct GlassHighlight: ViewModifier {
    let active: Bool
    var cornerRadius: CGFloat = .infinity

    func body(content: Content) -> some View {
        content.background(
            GlassCapsule(active: active, cornerRadius: cornerRadius) { EmptyView() }
        )
    }
}

extension View {
    /// 选中态玻璃高亮（底栏、分段控件）
    func glassHighlight(_ active: Bool, cornerRadius: CGFloat = .infinity) -> some View {
        modifier(GlassHighlight(active: active, cornerRadius: cornerRadius))
    }
}
