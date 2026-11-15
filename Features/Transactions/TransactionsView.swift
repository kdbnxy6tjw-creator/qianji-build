import SwiftUI

struct TransactionsView: View {
    let txs: [MNTransaction]
    let wallets: [MNWallet]
    let categories: [MNCategory]
    let onEdit: (MNTransaction) -> Void

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.managedObjectContext) private var ctx
    @State private var toast: String?

    @State private var query = ""
    @State private var walletFilter: UUID?
    @State private var selectedDay: String?
    @State private var monthAnchor = Date()
    @State private var calendarExpanded = true

    private var period: Cycle.Period {
        Cycle.make(anchor: Date(), startDay: settings.monthStartDay)
    }

    private var monthStartKey: String { DayKey.key(MonthMath.monthStart(monthAnchor)) }
    private var monthEndKey: String { DayKey.key(MonthMath.shifted(monthAnchor, by: 1)) }

    private var netByDay: [String: Int64] {
        Ledger.netByDay(txs, month: monthAnchor)
    }

    @State private var pendingDelete: MNTransaction?
    @State private var showDeleteConfirm = false

    private var filtered: [MNTransaction] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return txs.filter { t in
            if t.deletedAt != nil { return false }      // 2.0.0：回收站账目不进列表
            if let w = walletFilter, t.walletId != w { return false }
            if let d = selectedDay, t.day != d { return false }
            if q.isEmpty {
                // 未搜索时，列表跟随日历所在的自然月
                if t.day < monthStartKey || t.day >= monthEndKey { return false }
            } else {
                let hay = (t.categoryName + " " + t.note + " " + t.walletName + " "
                           + Money.display(t.cents) + " " + Money.display(-t.cents)).lowercased()
                if !hay.contains(q) { return false }
            }
            return true
        }
    }

    private var groups: [(key: String, items: [MNTransaction])] {
        Ledger.groupedByDay(filtered)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("交易")
                    .font(.system(size: 34, weight: .bold))

                searchField
                walletChips

                cycleBar

                if calendarExpanded {
                    MonthGrid(anchor: monthAnchor,
                              netByDay: netByDay,
                              selectedDay: selectedDay,
                              onSelect: { key in
                                  withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                      selectedDay = (selectedDay == key) ? nil : key
                                  }
                              },
                              onPrev: { monthAnchor = MonthMath.shifted(monthAnchor, by: -1); selectedDay = nil },
                              onNext: { monthAnchor = MonthMath.shifted(monthAnchor, by: 1); selectedDay = nil })
                        .cardStyle()
                }

                if let selectedDay = selectedDay {
                    HStack {
                        Text("已筛选 " + (DayKey.date(selectedDay).map(DayKey.chineseDate) ?? selectedDay))
                            .font(.caption)
                            .foregroundStyle(AppTheme.accent)
                        Spacer()
                        Button {
                            Haptics.selection()
                            self.selectedDay = nil
                        } label: {
                            Text("清除").font(.caption)
                        }
                        .pressScale()
                    }
                }

                if groups.isEmpty {
                    emptyState
                } else {
                    ForEach(groups.indices, id: \.self) { gi in
                        let group = groups[gi]
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                if let d = DayKey.date(group.key) {
                                    Text(DayKey.weekdayTitle(d) + " \(DayKey.calendar.component(.day, from: d))日")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                let net = Ledger.dayNet(txs, group.key)
                                Text(Money.net(net))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppTheme.netColor(net))
                            }
                            .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                ForEach(group.items, id: \.id) { item in
                                    Button {
                                        Haptics.soft()
                                        onEdit(item)
                                    } label: { TransactionRow(tx: item) }
                                    .buttonStyle(PressScaleStyle(scale: Motion.cardPressScale))
                                    // 2.0.0：从右往左滑呼出删除（按需求不提供长按）
                                    .swipeActions(edge: .trailing,
                                                  allowsFullSwipe: !settings.confirmBeforeDelete) {
                                        Button(role: .destructive) {
                                            requestDelete(item)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                        .tint(AppTheme.expense)
                                    }
                                    if item.id != group.items.last?.id {
                                        Divider().padding(.leading, 62)
                                    }
                                }
                            }
                            .cardStyle()
                        }
                    }
                }
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 130)
        }
        .alert("把这笔账单移进回收站？", isPresented: $showDeleteConfirm) {
            Button("移入回收站", role: .destructive) {
                if let t = pendingDelete {
                    Haptics.warning()
                    TransactionStore.softDelete(ctx: ctx, t)
                    toast = "已移入回收站，可在「设置 → 回收站」找回"
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(deleteConfirmMessage)
        }
        .overlay(alignment: .bottom) {
            if let toast = toast {
                ToastBubble(text: toast)
                    .padding(.bottom, 104)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(Motion.settle, value: toast)
            }
        }
    }

    // MARK: - 删除（2.0.0）

    private func requestDelete(_ t: MNTransaction) {
        if settings.confirmBeforeDelete {
            pendingDelete = t
            showDeleteConfirm = true
        } else {
            Haptics.warning()
            TransactionStore.softDelete(ctx: ctx, t)
            withAnimation(Motion.rowInsert) { toast = "已移入回收站" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(Motion.easeOutSwift) { toast = nil }
            }
        }
    }

    private var deleteConfirmMessage: String {
        switch settings.recycleTTL {
        case .never:
            return "不会立刻消失，会先进回收站，你可以在那里恢复；只有手动清空才会彻底删除。"
        default:
            return "不会立刻消失：\(settings.recycleTTL.title)后自动彻底清除，期间可在回收站恢复。"
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索备注、类别、金额", text: $query)
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    Haptics.tap()
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .pressScale(0.85)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(AppTheme.card2))
    }

    private var walletChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                chip(title: "全部", selected: walletFilter == nil) { walletFilter = nil }
                ForEach(wallets, id: \.id) { w in
                    chip(title: w.name, selected: walletFilter == w.id) { walletFilter = w.id }
                }
            }
        }
    }

    private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(selected ? AppTheme.accent : AppTheme.card2))
        }
        .pressScale(0.92, animation: Motion.snap)
    }

    private var cycleBar: some View {
        Button {
            Haptics.soft()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                calendarExpanded.toggle()
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "calendar")
                    .font(.system(size: 15, weight: .semibold))
                Text("周期 " + period.title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: calendarExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(AppTheme.accent.opacity(0.16))
            )
        }
        .buttonStyle(PressScaleStyle(scale: 0.98))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 30))
                .foregroundStyle(.tertiary)
            Text("这个月还没有符合条件的账单")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("点日历上的日期可以按天筛选")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .cardStyle()
    }
}
