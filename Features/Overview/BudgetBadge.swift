import SwiftUI

/// 首卡右侧 1/3 的固定槽位。只做状态显示，不另开卡片、不随左侧数字宽度移动。
struct BudgetBadge: View {
    let spent: Int64
    let budget: MNBudget?
    let onLongPress: () -> Void

    private var hasBudget: Bool { (budget?.cents ?? 0) > 0 }

    private var ratio: Double {
        guard let b = budget, b.cents > 0 else { return 0 }
        return Double(spent) / Double(b.cents)
    }

    private var percentText: String {
        String(format: "%.0f%%", ratio * 100)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.card2)

            // 整块底色按 ratio 连续插值（绿 → 黄 → 红），不是四段硬切
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(hasBudget
                      ? AppTheme.budgetTint(ratio).opacity(0.14)
                      : AppTheme.expense.opacity(0.16))

            // 连续渐变进度：整条渐变铺满宽度，再按已用比例裁切显示
            GeometryReader { geo in
                let fill = CGFloat(min(max(ratio, 0), 1)) * geo.size.width
                AppTheme.budgetGradient
                    .frame(width: geo.size.width, height: geo.size.height)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: fill)
                    }
            }
            .opacity(hasBudget ? 0.42 : 0)

            VStack(alignment: .leading, spacing: 3) {
                Text("今日预算")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                if hasBudget {
                    Text(Money.display(budget!.cents))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)

                    Text(percentText + " · " + AppTheme.budgetTier(ratio))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.budgetTint(ratio))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    if ratio > 1 {
                        Text("超 " + Money.display(spent - budget!.cents))
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.expense)
                            .lineLimit(1)
                    }
                } else {
                    Text("未设预算")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.expense)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("长按设置")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.expense.opacity(0.85))
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(hasBudget ? AppTheme.budgetTint(ratio).opacity(0.35)
                                 : AppTheme.expense.opacity(0.5),
                        lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.40) {
            Haptics.longPress()          // 手势被识别的确认
            onLongPress()
        }
        .accessibilityLabel(hasBudget ? "今日预算已用 \(percentText)" : "未设置今日预算，长按设置")
    }
}

/// 长按后浮起的设置小窗：显示今日支出、已用比例，并就地设置预算（不跳设置页）
struct BudgetPopover: View {
    let spent: Int64
    let budget: MNBudget?
    let onSave: (Int64) -> Void
    let onUseYesterday: () -> Void
    let onClear: () -> Void

    @State private var input: String = ""
    @FocusState private var focused: Bool

    private var ratio: Double {
        guard let b = budget, b.cents > 0 else { return 0 }
        return Double(spent) / Double(b.cents)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("今日预算")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                if (budget?.cents ?? 0) > 0 {
                    Text(AppTheme.budgetTier(ratio))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.budgetTint(ratio))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AppTheme.budgetTint(ratio).opacity(0.18)))
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日支出").font(.caption).foregroundStyle(.secondary)
                    Text(Money.display(spent))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.expense)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("已用").font(.caption).foregroundStyle(.secondary)
                    Text((budget?.cents ?? 0) > 0
                         ? String(format: "%.0f%%", ratio * 100)
                         : "—")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle((budget?.cents ?? 0) > 0
                                         ? AppTheme.budgetTint(ratio)
                                         : AppTheme.expense)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                TextField("预算金额", text: $input)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { focused = false }
                    .textFieldStyle(.roundedBorder)
                Button {
                    let cents = Money.cents(fromRaw: input)
                    if cents > 0 {
                        Haptics.success()
                        onSave(cents)
                        input = ""
                        focused = false
                    } else {
                        Haptics.warning()
                    }
                } label: {
                    Text("设置")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(AppTheme.accent))
                }
                .pressScale()
            }

            HStack(spacing: 10) {
                Button {
                    Haptics.selection()
                    onUseYesterday()
                } label: {
                    Text("沿用昨日").font(.system(size: 13))
                }
                .pressScale()
                Spacer()
                Button {
                    Haptics.warning()
                    onClear()
                } label: {
                    Text("清除今日预算")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.expense)
                }
                .pressScale()
            }

            Text("点空白处关闭")
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
        .onAppear {
            if let b = budget, b.cents > 0 { input = Money.raw(fromCents: b.cents) }
        }
    }
}
