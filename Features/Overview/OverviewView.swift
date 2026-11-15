import CoreData
import SwiftUI

struct OverviewView: View {
    let txs: [MNTransaction]
    let wallets: [MNWallet]
    let categories: [MNCategory]
    let budgets: [MNBudget]
    let onEdit: (MNTransaction) -> Void

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.managedObjectContext) private var ctx

    @State private var cycleAnchor = Date()
    @State private var showBudgetPopover = false
    @State private var showCyclePopover = false

    private var todayKey: String { DayKey.today }
    private var todayTotals: (income: Int64, expense: Int64) { Ledger.day(txs, todayKey) }
    private var todayNet: Int64 { todayTotals.income - todayTotals.expense }
    private var todayBudget: MNBudget? { BudgetStore.budget(budgets, for: todayKey) }
    private var period: Cycle.Period {
        Cycle.make(anchor: cycleAnchor, startDay: settings.monthStartDay)
    }
    private var periodTotals: (income: Int64, expense: Int64) {
        Ledger.range(txs, from: period.startKey, to: period.endKey)
    }
    private var periodNet: Int64 { periodTotals.income - periodTotals.expense }
    private var totalAssets: Int64 { Ledger.totalAssets(txs, wallets: wallets) }
    private var todayItems: [MNTransaction] {
        // 2.0.0：回收站里的账目不出现在今日列表
        txs.filter { $0.day == todayKey && $0.deletedAt == nil }.sorted {
            if $0.occurredAt != $1.occurredAt { return $0.occurredAt > $1.occurredAt }
            return $0.createdAt > $1.createdAt
        }
    }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    todayCard
                    periodCard
                    walletTotalCard

                    SectionHeader(title: "今天 · 每笔收支")
                    if todayItems.isEmpty {
                        emptyToday
                    } else {
                        VStack(spacing: 0) {
                            ForEach(todayItems, id: \.id) { item in
                                Button {
                                    Haptics.soft()
                                    onEdit(item)
                                } label: {
                                    TransactionRow(tx: item)
                                }
                                .pressScale(Motion.cardPressScale)
                                if item.id != todayItems.last?.id {
                                    Divider().padding(.leading, 62)
                                }
                            }
                        }
                        .cardStyle()
                    }
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 130)
            }

            PopupBackdrop(isPresented: showBudgetPopover,
                          onDismiss: { showBudgetPopover = false }) {
                BudgetPopover(
                    spent: todayTotals.expense,
                    budget: todayBudget,
                    onSave: { cents in
                        guard cents > 0 else { return }
                        BudgetStore.set(ctx: ctx, day: todayKey, cents: cents)
                    },
                    onUseYesterday: {
                        let y = yesterdayKey
                        if let b = BudgetStore.budget(budgets, for: y), b.cents > 0 {
                            BudgetStore.set(ctx: ctx, day: todayKey, cents: b.cents)
                        }
                    },
                    onClear: {
                        BudgetStore.set(ctx: ctx, day: todayKey, cents: 0)
                    }
                )
                .offset(y: -40)
            }

            PopupBackdrop(isPresented: showCyclePopover,
                          onDismiss: { showCyclePopover = false }) {
                cyclePopover
            }
        }
    }

    private var yesterdayKey: String {
        DayKey.key(DayKey.calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date())
    }

    // MARK: - 顶部

    private var header: some View {
        HStack(alignment: .center) {
            Text("概览")
                .font(.system(size: 34, weight: .bold))
            Spacer()
            Button {
                Haptics.soft()
                showCyclePopover = true
            } label: {
                Image(systemName: "clock")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 36, height: 36)
            }
            .pressScale(0.88)
        }
    }

    // MARK: - 第一张卡：今日结余 2:1 分栏、中间无界线

    private var todayCard: some View {
        GeometryReader { geo in
            HStack(alignment: .top, spacing: 0) {
                // 左 2/3
                VStack(alignment: .leading, spacing: 6) {
                    Text("今日结余")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(Money.net(todayNet))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.netColor(todayNet))
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("收入 +" + Money.display(todayTotals.income))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.income)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("支出 −" + Money.display(todayTotals.expense))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.expense)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: geo.size.width * 2 / 3, alignment: .leading)

                // 右 1/3：固定槽位
                BudgetBadge(spent: todayTotals.expense,
                            budget: todayBudget) {
                    showBudgetPopover = true
                }
                .frame(width: geo.size.width * 1 / 3 - 10, height: 104)
                .padding(.leading, 10)
            }
        }
        .frame(height: 116)
        .cardStyle()
    }

    // MARK: - 第二张卡：本期（自定义月度起始日）

    private var periodCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("本期")
                    .font(.system(size: 19, weight: .bold))
                Spacer()
                Text(period.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(Money.net(periodNet))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.netColor(periodNet))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            HStack(spacing: 18) {
                Label("收入 +" + Money.display(periodTotals.income), systemImage: "arrow.down.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.income)
                Spacer()
                Label("支出 −" + Money.display(periodTotals.expense), systemImage: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.expense)
            }

            Text("每月 \(settings.monthStartDay) 日起算 · 在「设置」中修改")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .cardStyle()
    }

    // MARK: - 第三张卡：钱包资金总和

    private var walletTotalCard: some View {
        HStack(spacing: 14) {
            IconTile(symbol: "creditcard.fill", color: AppTheme.accent, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("钱包资金总和")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(Money.net(totalAssets))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.netColor(totalAssets))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(wallets.filter { !$0.isArchived }.count) 个钱包")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .cardStyle()
    }

    private var emptyToday: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 30))
                .foregroundStyle(.tertiary)
            Text("今天还没有记一笔")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("点中间的 ＋，三秒记完")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .cardStyle()
    }

    // MARK: - 周期切换小窗（由右上角时钟唤出）

    private var cyclePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("查看周期")
                .font(.system(size: 17, weight: .bold))
            Text(period.title + "　·　每月 \(settings.monthStartDay) 日起算")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button {
                    Haptics.selection()
                    cycleAnchor = Cycle.make(anchor: period.start.addingTimeInterval(-86_400),
                                             startDay: settings.monthStartDay).start
                } label: {
                    Text("上一期")
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Capsule().fill(AppTheme.card2))
                }
                .pressScale()
                Button {
                    Haptics.selection()
                    cycleAnchor = Date()
                } label: {
                    Text("回到本期")
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Capsule().fill(AppTheme.card2))
                }
                .pressScale()
                Button {
                    Haptics.selection()
                    cycleAnchor = period.end
                } label: {
                    Text("下一期")
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Capsule().fill(AppTheme.card2))
                }
                .pressScale()
            }
            .font(.system(size: 13, weight: .medium))
        }
        .padding(18)
        .frame(maxWidth: 330)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(AppTheme.card)
            .shadow(color: .black.opacity(0.4), radius: 24, y: 10))
        .padding(.horizontal, 24)
    }
}
