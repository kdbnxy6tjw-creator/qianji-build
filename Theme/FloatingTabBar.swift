import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case overview
    case transactions
    case wallets
    case settings

    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: return "概览"
        case .transactions: return "交易"
        case .wallets: return "钱包"
        case .settings: return "设置"
        }
    }
    var icon: String {
        switch self {
        case .overview: return "house.fill"
        case .transactions: return "list.bullet"
        case .wallets: return "creditcard.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
}

/// 悬浮胶囊底栏：概览 / 交易 / ＋ / 钱包 / 设置
///
/// 2.0.0 改动：
/// - 选中态换成 Q 弹玻璃胶囊（`GlassCapsule`）：本体缩小、上层磨砂放大，无折射无扭曲；
/// - 设置里可关掉图标下方文字，关掉后图标自动放大填满空间，**底栏高度保持不变**；
/// - 中间 ＋ 按钮沿用同一套玻璃语言，按下同样有挤压回弹。
struct FloatingTabBar: View {
    @Binding var tab: AppTab
    let onAdd: () -> Void

    @EnvironmentObject private var settings: AppSettings

    /// 底栏整体高度锁定：文字显隐都不改变它
    private let barHeight: CGFloat = 58
    /// 有文字时的图标尺寸
    private let iconWithLabel: CGFloat = 19
    /// 隐藏文字后的图标尺寸（放大，但仍在固定高度内）
    private let iconWithoutLabel: CGFloat = 25

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                item(.overview)
                item(.transactions)
                Spacer().frame(width: 74)
                item(.wallets)
                item(.settings)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(height: barHeight)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.barBG)
                    .shadow(color: .black.opacity(0.38), radius: 20, x: 0, y: 10)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
            )

            Button {
                Haptics.press()          // 核心入口，给一记明确的"按下"
                onAdd()
            } label: {
                ZStack {
                    // 底盘：按下时缩小
                    Circle()
                        .fill(AppTheme.accent)
                        .shadow(color: AppTheme.accent.opacity(0.45), radius: 12, x: 0, y: 6)
                    // 上层玻璃：按下时鼓起，形成挤压感（无折射/扭曲）
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle().strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .white.opacity(0.60), location: 0.0),
                                        .init(color: .white.opacity(0.05), location: 0.55),
                                        .init(color: .black.opacity(0.14), location: 1.0)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing),
                                lineWidth: 1.0)
                        )
                        .padding(3)
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 58, height: 58)
            }
            .buttonStyle(AddButtonStyle())
            .offset(y: -15)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func item(_ target: AppTab) -> some View {
        let selected = (tab == target)
        let showLabels = settings.showTabLabels

        Button {
            guard tab != target else { return }   // 重复点当前页不震
            Haptics.selection()
            withAnimation(Motion.snap) {
                tab = target
            }
        } label: {
            VStack(spacing: showLabels ? 4 : 0) {
                Image(systemName: target.icon)
                    .font(.system(size: showLabels ? iconWithLabel : iconWithoutLabel,
                                  weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? AppTheme.accent : Color.secondary)
                    // 图标本身也参与 Q 弹：选中放大一档
                    .scaleEffect(selected ? 1.06 : 1.0)

                if showLabels {
                    Text(target.title)
                        .font(.system(size: 10, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? AppTheme.accent : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)               // 高度锁定：文字显隐不改变底栏尺寸
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle(scale: 0.90, animation: Motion.pop))
        .background(
            // 选中态玻璃胶囊：本体缩小 + 上层磨砂放大（由 GlassCapsule 内部完成）
            GlassCapsule(active: selected, growsContent: true, cornerRadius: 20) { EmptyView() }
                .padding(.horizontal, 2)
        )
        .animation(Motion.pop, value: selected)
        .animation(Motion.snap, value: showLabels)
    }
}

/// ＋ 按钮专用：按下时本体缩小、上层玻璃放大
private struct AddButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Motion.glassPressScale : 1.0)
            .animation(Motion.pop, value: configuration.isPressed)
    }
}
