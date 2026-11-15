import Foundation
import SwiftUI

/// ＋页的分类选择器。两种排列共用同一套顺序，「其他」永远排在最后。
struct CategoryGrid: View {
    let categories: [MNCategory]
    let layout: CategoryLayout
    let selectedID: UUID?
    let onSelect: (MNCategory) -> Void
    let onOtherLongPress: () -> Void

    /// 长按「其他」抬手时 Button 的 tap 可能跟着触发，用标志吞掉，
    /// 否则会「长按起泡」和「单击选中」同时发生（以及震两次）。
    @State private var suppressNextTap = false

    @EnvironmentObject private var settings: AppSettings

    /// 2.0.0：文字关掉后图标放大，填满原来的空间
    private var tileSize: CGFloat { settings.showCategoryLabels ? 46 : 58 }
    private var spacing: CGFloat { settings.showCategoryLabels ? 12 : 14 }

    private var items: [MNCategory] { CategoryStore.gridItems(categories) }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        Group {
            if layout == .grid2x4 {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(items, id: \.id) { c in cell(c) }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing - 2) {
                        ForEach(items, id: \.id) { c in
                            cell(c).frame(width: settings.showCategoryLabels ? 64 : 76)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .animation(Motion.snap, value: settings.showCategoryLabels)
    }

    @ViewBuilder
    private func cell(_ c: MNCategory) -> some View {
        let isSelected = selectedID == c.id
        let showLabels = settings.showCategoryLabels
        Button {
            if suppressNextTap { suppressNextTap = false; return }
            onSelect(c)
        } label: {
            VStack(spacing: showLabels ? 6 : 0) {
                IconTile(symbol: c.symbol, color: c.tint, size: tileSize, selected: false)
                    .scaleEffect(isSelected ? Motion.glassSelectedScale : 1.0)

                if showLabels {
                    Text(c.name)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? AppTheme.accent : Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: showLabels ? 74 : 66)
            .padding(.vertical, 2)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressScaleStyle(scale: 0.92, animation: Motion.pop))
        .background(
            // 2.0.0：选中态换成 Q 弹玻璃胶囊（无折射/扭曲，只有磨砂 + 描边）
            GlassCapsule(active: isSelected, growsContent: false, cornerRadius: 16) { EmptyView() }
        )
        .animation(Motion.pop, value: isSelected)
        .animation(Motion.snap, value: showLabels)
        // 「其他」单击记账，长按起泡弹出被隐藏的分类
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.42).onEnded { _ in
                guard c.isOther else { return }
                suppressNextTap = true
                onOtherLongPress()
                // 万一 Button 的 tap 没跟上来，超时自动解锁，别吞掉下一次正常点击
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    suppressNextTap = false
                }
            }
        )
    }
}

/// 长按「其他」后起泡弹出的隐藏分类菜单
struct HiddenCategoryBubble: View {
    let hidden: [MNCategory]
    let onSelect: (MNCategory) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "ellipsis.circle.fill")
                    .foregroundStyle(AppTheme.accent)
                Text("被隐藏的分类")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }

            if hidden.isEmpty {
                Text("目前没有隐藏的分类。可在「设置 → 分类管理」里隐藏。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(hidden, id: \.id) { c in
                        Button { onSelect(c) } label: {
                            VStack(spacing: 6) {
                                IconTile(symbol: c.symbol, color: c.tint, size: 44)
                                Text(c.name)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PressScaleStyle(scale: 0.92))
                    }
                }
            }

            Text("点空白处关闭 · 选中后仍按原分类名记账")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(18)
        .frame(maxWidth: 330)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.card)
                .shadow(color: .black.opacity(0.4), radius: 24, y: 10)
        )
        .padding(.horizontal, 24)
    }
}
