import SwiftUI

/// 兼容别名：2.0.0 起统一走 `PressScaleStyle`（见 Motion.swift），
/// 这里保留同名类型只为让未迁移的调用点继续可编译，内部已转发到新实现。
@available(*, deprecated, message: "改用 PressScaleStyle / .pressScale()")
struct ScaleButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = Motion.pressScale

    func makeBody(configuration: Configuration) -> some View {
        PressScaleStyle(scale: pressedScale).makeBody(configuration: configuration)
    }
}

struct CardBackground: ViewModifier {
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppTheme.card)
            )
    }
}

extension View {
    func cardStyle(radius: CGFloat = 20) -> some View {
        modifier(CardBackground(radius: radius))
    }

    /// 让整块区域可点（含透明处）
    func hitArea() -> some View {
        self.contentShape(Rectangle())
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }
}

/// 分类 / 钱包图标瓦片
struct IconTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 42
    var selected: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(color.opacity(selected ? 0.28 : 0.18))
            Image(systemName: symbol)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(selected ? AppTheme.accent : color)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .stroke(AppTheme.accent.opacity(selected ? 0.9 : 0), lineWidth: 2)
        )
    }
}

/// 点空白处关闭的浮层容器（起泡弹窗 / 预算长按窗共用）
struct PopupBackdrop<Content: View>: View {
    let isPresented: Bool
    let onDismiss: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            if isPresented {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)
                    .transition(.opacity)

                content()
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.86).combined(with: .opacity),
                            removal: .scale(scale: 0.94).combined(with: .opacity)
                        )
                    )
            }
        }
        .animation(Motion.settle, value: isPresented)
    }
}
