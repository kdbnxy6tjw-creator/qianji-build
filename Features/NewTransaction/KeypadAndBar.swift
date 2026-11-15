import SwiftUI

// MARK: - 常驻数字键盘（带逗号与退格，与截图一致）

struct AmountKeypad: View {
    @Binding var raw: String

    private let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [",", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 8) {
                    ForEach(rows[r], id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        Button {
            Haptics.tap()               // 轻、带节流，连续输入不糊
            append(key)
        } label: {
            Group {
                if key == "⌫" {
                    Image(systemName: "delete.left")
                        .font(.system(size: 21, weight: .medium))
                } else {
                    Text(key)
                        .font(.system(size: 24, weight: .regular, design: .rounded))
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.card2)
            )
        }
        .buttonStyle(PressScaleStyle(scale: 0.92, animation: Motion.snap))
    }

    private func append(_ key: String) {
        if key == "⌫" {
            if !raw.isEmpty { raw.removeLast() }
            return
        }
        if key == "," {
            if !raw.isEmpty && !raw.contains(",") { raw.append(",") }
            return
        }
        if raw.contains(",") {
            let fraction = raw.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            if fraction.count > 1, fraction[1].count >= 2 { return }
        }
        guard raw.count < 12 else { return }
        if raw == "0" {
            raw = (key == "0") ? "0" : key
        } else {
            raw.append(key)
        }
    }
}

// MARK: - 左 2/3：收支胶囊（2.0.0 换成 Q 弹玻璃滑块）

struct KindCapsule: View {
    @Binding var kind: TransactionKind

    var body: some View {
        GeometryReader { geo in
            let inset: CGFloat = 4
            let knobWidth = (geo.size.width - inset * 2) / 2
            let knobHeight = geo.size.height - inset * 2

            ZStack(alignment: .leading) {
                // 槽底
                Capsule(style: .continuous)
                    .fill(AppTheme.card2)
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)

                // 选中半区：Q 弹玻璃胶囊。切换时它会"挤"过去——
                // 本体先缩一点、磨砂层放大一点，落位时冲过再收回（Motion.snap）
                GlassCapsule(active: true, growsContent: false, cornerRadius: .infinity) { EmptyView() }
                    .frame(width: knobWidth, height: knobHeight)
                    .offset(x: inset + (kind == .income ? knobWidth : 0))
                    .animation(Motion.snap, value: kind)

                HStack(spacing: 0) {
                    Text("支出")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(kind == .expense ? AppTheme.expense : Color.secondary)
                        .frame(width: knobWidth)
                        .scaleEffect(kind == .expense ? 1.04 : 1.0)
                    Text("收入")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(kind == .income ? AppTheme.income : Color.secondary)
                        .frame(width: knobWidth)
                        .scaleEffect(kind == .income ? 1.04 : 1.0)
                }
                .padding(.leading, inset)
                .animation(Motion.snap, value: kind)

                // 两半点击区 + 拖拽
                HStack(spacing: 0) {
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { set(.expense) }
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { set(.income) }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onEnded { value in
                        set(value.translation.width > 0 ? .income : .expense)
                    }
            )
        }
    }

    private func set(_ value: TransactionKind) {
        guard kind != value else { return }   // 滑到同一侧不重复震
        Haptics.selection()
        withAnimation(Motion.snap) {
            kind = value
        }
    }
}

// MARK: - 右 1/3：保存胶囊（与左侧不相连）

struct SaveCapsule: View {
    let enabled: Bool
    let action: () -> Void

    /// 2.0.0：点击后做一次"跳一下"的回弹——先缩到 0.90，再冲到 1.05，最后收回 1.0。
    /// 用显式状态机而不是 ButtonStyle，因为按下瞬间就要起跳，抬手后才收回。
    @State private var bump = false

    var body: some View {
        Button {
            Haptics.press()
            withAnimation(Motion.pop) { bump = true }
            // 让"冲过"那一帧出现，再收回
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(Motion.settle) { bump = false }
            }
            action()
        } label: {
            Text("保存")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(enabled ? Color.white : Color.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Capsule(style: .continuous)
                        .fill(enabled ? AppTheme.accent : AppTheme.card2)
                )
                .scaleEffect(bump ? 1.05 : 1.0)
        }
        // 不禁用：条件不满足时也要能点，由 save() 给 warning 触感 + 文字提示，
        // 否则用户按了没任何反应。成功/失败各只给一次反馈，不与 press 叠加。
        .buttonStyle(PressScaleStyle(scale: Motion.glassPressScale))
    }
}

/// 两个不相连胶囊，中间留缝；左 2/3、右 1/3
struct BottomActionBar: View {
    @Binding var kind: TransactionKind
    let enabled: Bool
    let onSave: () -> Void

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 10
            let total = geo.size.width - gap
            HStack(spacing: gap) {
                KindCapsule(kind: $kind)
                    .frame(width: total * 2 / 3)
                SaveCapsule(enabled: enabled, action: onSave)
                    .frame(width: total * 1 / 3)
            }
        }
        .frame(height: 54)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
