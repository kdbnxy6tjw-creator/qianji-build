import CoreData
import SwiftUI

enum SettingRow: String, CaseIterable, Identifiable {
    case defaultKind
    case monthStart
    case budget
    case categoryLayout
    var id: String { rawValue }
}

struct SettingsView: View {
    let txs: [MNTransaction]
    let wallets: [MNWallet]
    let categories: [MNCategory]
    let budgets: [MNBudget]

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.managedObjectContext) private var ctx

    @State private var expanded: SettingRow?
    @State private var budgetTarget = 0        // 0 = 今天，1 = 明天
    @State private var budgetInput = ""
    @FocusState private var budgetFocused: Bool

    private var targetKey: String {
        DayKey.key(DayKey.calendar.date(byAdding: .day, value: budgetTarget, to: Date()) ?? Date())
    }
    private var targetBudget: MNBudget? { BudgetStore.budget(budgets, for: targetKey) }
    private var yesterdayKey: String {
        DayKey.key(DayKey.calendar.date(byAdding: .day, value: budgetTarget - 1, to: Date()) ?? Date())
    }
    private var todayExpense: Int64 { Ledger.day(txs, DayKey.today).expense }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("设置")
                        .font(.system(size: 34, weight: .bold))

                    // 1. 默认收支
                    settingRow(title: "默认记账类型",
                               subtitle: "点 ＋ 打开时先落在收入还是支出",
                               value: settings.defaultKind.title,
                               row: .defaultKind) {
                        HStack(spacing: 10) {
                            ForEach(TransactionKind.allCases) { k in
                                Button {
                                    settings.defaultKind = k
                                } label: {
                                    Text(k.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(settings.defaultKind == k ? Color.white : Color.primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule().fill(settings.defaultKind == k
                                                           ? AppTheme.moneyColor(k)
                                                           : AppTheme.card2)
                                        )
                                }
                                .pressScale()
                            }
                        }
                    }

                    // 2. 月度起始日（行内完成，不跳页）
                    settingRow(title: "月度起始日",
                               subtitle: "「本期」按这个日子切分，不对自然月日历造成影响",
                               value: "每月 \(settings.monthStartDay) 日",
                               row: .monthStart) {
                        VStack(alignment: .leading, spacing: 12) {
                            Stepper(value: $settings.monthStartDay, in: 1...28) {
                                Text("每月 \(settings.monthStartDay) 日起算")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            HStack(spacing: 8) {
                                ForEach([1, 5, 10, 15, 25], id: \.self) { d in
                                    Button("\(d) 日") {
                                        settings.monthStartDay = d
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(settings.monthStartDay == d ? Color.white : Color.primary)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Capsule().fill(settings.monthStartDay == d
                                                               ? AppTheme.accent : AppTheme.card2))
                                    .pressScale(0.90)
                                }
                            }
                            Text("限定 1–28 日，避免 2 月出现非法日期。")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }

                    // 3. 当日预算 + 提醒（全部行内完成）
                    settingRow(title: "当日预算与提醒",
                               subtitle: "金额随意增减；每天定时或提前一天提醒你设置",
                               value: targetBudget.map { Money.display($0.cents) + " CNY" } ?? "未设置",
                               row: .budget) {
                        budgetDetail
                    }

                    // 4. 分类排列
                    settingRow(title: "分类排列",
                               subtitle: "＋页分类宫格的展示方式",
                               value: settings.categoryLayout.title,
                               row: .categoryLayout) {
                        Picker("排列方式", selection: $settings.categoryLayout) {
                            ForEach(CategoryLayout.allCases) { l in
                                Text(l.title).tag(l)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // 5. 外观（2.0.0 新增：文字显隐 + 删除确认）
                    appearanceSection

                    // 6. 回收站（2.0.0 新增的二级页入口）
                    NavigationLink {
                        RecycleBinView(txs: txs)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text("回收站")
                                        .font(.system(size: 16, weight: .semibold))
                                    if recycleCount > 0 {
                                        Text("\(recycleCount)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(AppTheme.expense))
                                    }
                                }
                                Text("删除的账目先落在这里，可恢复或彻底清除")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(AppTheme.card))
                    }
                    .foregroundStyle(.primary)
                    .pressScale(Motion.cardPressScale)

                    // 7. 分类管理（跳二级页）
                    NavigationLink {
                        CategoryManageView(categories: categories)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("分类管理")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("隐藏内置分类、新建自定义分类、调整顺序")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(AppTheme.card))
                    }
                    .foregroundStyle(.primary)
                    .pressScale(Motion.cardPressScale)

                    Divider().padding(.vertical, 6)

                    BackupSection(txs: txs, wallets: wallets,
                                  categories: categories, budgets: budgets)

                    Text("钱迹 · v2.0.0 · iOS 16.0+ · 纯本地，无账号、无广告、无追踪")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 130)
            }
            .background(AppTheme.pageBG.ignoresSafeArea())
        }
        .onAppear { syncBudgetInput() }
        .onChange(of: budgetTarget) { _ in
            Haptics.selection()
            syncBudgetInput()
        }
        // 设置项变化：统一给一记"状态已改变"，避免每个控件里重复触发
        .onChange(of: settings.defaultKind) { _ in Haptics.selection() }
        .onChange(of: settings.monthStartDay) { _ in Haptics.selection() }
        .onChange(of: settings.categoryLayout) { _ in Haptics.selection() }
        .onChange(of: settings.reminderEnabled) { _ in Haptics.selection() }
        .onChange(of: settings.showTabLabels) { _ in Haptics.selection() }
        .onChange(of: settings.showCategoryLabels) { _ in Haptics.selection() }
        .onChange(of: settings.confirmBeforeDelete) { _ in Haptics.selection() }
    }

    // MARK: - 外观（2.0.0）

    private var recycleCount: Int { RecycleStore.count(txs) }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("外观与手感")
                        .font(.system(size: 16, weight: .semibold))
                    Text("关掉文字后图标自动放大，底栏高度不变")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
            }
            .padding(16)

            Divider().padding(.leading, 16)

            VStack(spacing: 14) {
                Toggle(isOn: $settings.showTabLabels) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("显示底栏文字")
                        Text("关掉后只剩图标，图标会放大一号")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .tint(AppTheme.accent)

                Toggle(isOn: $settings.showCategoryLabels) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("显示＋页类别文字")
                        Text("关掉后分类宫格只剩图标瓦片，瓦片会放大一号")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .tint(AppTheme.accent)

                Divider()

                Toggle(isOn: $settings.confirmBeforeDelete) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("删除前二次确认")
                        Text("关掉后右滑直接把账目移进回收站，不再弹确认框")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .tint(AppTheme.accent)
            }
            .font(.system(size: 14))
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(AppTheme.card))
    }

    // MARK: - 预算行展开内容

    private var budgetDetail: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("设置对象", selection: $budgetTarget) {
                Text("今天").tag(0)
                Text("明天").tag(1)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                TextField("预算金额（CNY）", text: $budgetInput)
                    .keyboardType(.decimalPad)
                    .focused($budgetFocused)
                    .submitLabel(.done)
                    .onSubmit { budgetFocused = false }
                    .textFieldStyle(.roundedBorder)
                Button {
                    let cents = Money.cents(fromRaw: budgetInput)
                    if cents > 0 {
                        Haptics.success()
                        BudgetStore.set(ctx: ctx, day: targetKey, cents: cents)
                        budgetFocused = false
                    } else {
                        Haptics.warning()
                    }
                } label: {
                    Text("设置")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Capsule().fill(AppTheme.accent))
                }
                .pressScale()
            }

            HStack(spacing: 12) {
                Button {
                    Haptics.selection()
                    if let b = BudgetStore.budget(budgets, for: yesterdayKey), b.cents > 0 {
                        BudgetStore.set(ctx: ctx, day: targetKey, cents: b.cents)
                        syncBudgetInput()
                    }
                } label: {
                    Text("沿用昨日").font(.system(size: 13))
                }
                .pressScale(0.92, animation: Motion.snap)
                Spacer()
                Button {
                    Haptics.warning()
                    BudgetStore.set(ctx: ctx, day: targetKey, cents: 0)
                    budgetInput = ""
                } label: {
                    Text("清除")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.expense)
                }
                .pressScale(0.92, animation: Motion.snap)
            }

            Text(statusLine)
                .font(.caption)
                .foregroundStyle(targetBudget == nil ? AppTheme.expense : Color.secondary)

            Divider()

            Toggle("每天提醒我设置预算", isOn: $settings.reminderEnabled)
                .font(.system(size: 14))
                .tint(AppTheme.accent)

            VStack(alignment: .leading, spacing: 6) {
                Text("提醒方式").font(.caption).foregroundStyle(.secondary)
                Picker("提醒方式", selection: Binding(
                    get: { settings.reminderMode },
                    set: { Haptics.selection(); settings.setReminderMode($0) }
                )) {
                    ForEach(ReminderMode.allCases) { m in
                        Text(m.title).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!settings.reminderEnabled)
            }

            DatePicker("提醒时间", selection: Binding(
                get: { settings.reminderDate },
                set: { settings.setReminderTime($0) }
            ), displayedComponents: .hourAndMinute)
                .font(.system(size: 14))
                .disabled(!settings.reminderEnabled)

            Text("默认：当天模式 00:05 提醒设当天；提前一天模式 20:00 提醒设明天。对应日期已设预算就不发。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusLine: String {
        if let b = targetBudget {
            let ratio = b.cents > 0 ? Double(todayExpense) / Double(b.cents) : 0
            return "今日已支出 " + Money.display(todayExpense)
                + " CNY · 已用 " + String(format: "%.0f%%", ratio * 100)
                + " · " + AppTheme.budgetTier(ratio)
        }
        return "未设置预算：首页预算块会显示红色，点空白处可关闭长按小窗。"
    }

    private func syncBudgetInput() {
        if let b = targetBudget {
            budgetInput = Money.raw(fromCents: b.cents)
        } else {
            budgetInput = ""
        }
    }

    // MARK: - 通用行

    @ViewBuilder
    private func settingRow<Content: View>(title: String,
                                           subtitle: String,
                                           value: String,
                                           row: SettingRow,
                                           @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.soft()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                    expanded = (expanded == row) ? nil : row
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Text(value)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                        .lineLimit(1)
                    Image(systemName: expanded == row ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .pressScale(Motion.cardPressScale)

            if expanded == row {
                Divider().padding(.top, 12)
                content()
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(AppTheme.card))
    }
}
