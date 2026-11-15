import CoreData
import SwiftUI

/// 账目回收站（SemVer 2.0.0 新增）。
/// 从「设置」点进来的二级页：上面是保留时长设置，下面是被删账目列表。
/// 删除动作只把账目挪进这里（`deletedAt` 打时间戳），彻底消失有两种途径：
/// 1. 进前台时按全局保留时长清理过期条目；
/// 2. 用户在这里手动恢复 / 单条彻底删除 / 一键清空。
struct RecycleBinView: View {
    let txs: [MNTransaction]

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var showClearConfirm = false
    @State private var pendingPurge: MNTransaction?
    @State private var showPurgeConfirm = false
    @State private var toast: String?

    private var items: [MNTransaction] { RecycleStore.trashed(txs) }

    private var soonestExpiryText: String {
        guard settings.recycleTTL != .never, let first = items.first else {
            return settings.recycleTTL.subtitle
        }
        return RecycleStore.expiryText(of: first, ttl: settings.recycleTTL)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                ttlCard
                listSection
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(AppTheme.pageBG.ignoresSafeArea())
        .navigationTitle("回收站")
        .navigationBarTitleDisplayMode(.inline)
        .alert("清空回收站？", isPresented: $showClearConfirm) {
            Button("全部彻底删除", role: .destructive) {
                Haptics.warning()
                TransactionStore.purgeAll(ctx: ctx, items: items)
                showToast("回收站已清空")
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("这里共 \(items.count) 笔账目会被永久删除，无法找回。清空不影响回收站之外的账本数据。")
        }
        .alert("彻底删除这笔账单？", isPresented: $showPurgeConfirm) {
            Button("永久删除", role: .destructive) {
                if let t = pendingPurge {
                    Haptics.warning()
                    TransactionStore.purge(ctx: ctx, t)
                    showToast("已彻底删除")
                }
                pendingPurge = nil
            }
            Button("取消", role: .cancel) { pendingPurge = nil }
        } message: {
            Text("删掉之后就真的没有了，不能从回收站找回。")
        }
        .overlay(alignment: .bottom) {
            if let toast = toast {
                ToastBubble(text: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(Motion.settle, value: toast)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: - 顶部说明

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.expense.opacity(0.14))
                Image(systemName: "trash")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(AppTheme.expense)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(items.isEmpty ? "回收站是空的" : "\(items.count) 笔账目在回收站")
                    .font(.system(size: 16, weight: .semibold))
                Text(items.isEmpty
                     ? "在交易列表从右往左滑一笔账目，它就会先落到这里"
                     : soonestExpiryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(AppTheme.card))
    }

    // MARK: - 保留时长（全局唯一设置）

    private var ttlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("自动彻底清除")
                    .font(.system(size: 16, weight: .semibold))
                Text("对回收站内所有账目生效；每次打开 App 时检查一次")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(RecycleTTL.allCases) { ttl in
                ttlRow(ttl)
            }

            Text("计时从你把它滑进回收站的那一刻开始。改成更长的时间不会让已过期的账目回来。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(AppTheme.card))
    }

    private func ttlRow(_ ttl: RecycleTTL) -> some View {
        let selected = settings.recycleTTL == ttl
        return Button {
            guard !selected else { return }
            Haptics.selection()
            withAnimation(Motion.snap) { settings.recycleTTL = ttl }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(selected ? AppTheme.accent : Color.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(ttl.title)
                        .font(.system(size: 14, weight: selected ? .semibold : .regular))
                    Text(ttl.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GlassCapsule(active: selected, growsContent: false, cornerRadius: 14) { EmptyView() }
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .pressScale(0.99, animation: Motion.snap)
    }

    // MARK: - 列表

    @ViewBuilder
    private var listSection: some View {
        if items.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "tray")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text("没有可恢复的账目")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .cardStyle()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("已删除的账目")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Button {
                        Haptics.warning()
                        showClearConfirm = true
                    } label: {
                        Text("清空回收站")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.expense)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(AppTheme.expense.opacity(0.12)))
                    }
                    .pressScale(0.92, animation: Motion.snap)
                }
                .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    ForEach(items, id: \.id) { t in
                        row(t)
                        if t.id != items.last?.id {
                            Divider().padding(.leading, 62)
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    private func row(_ t: MNTransaction) -> some View {
        let expired = RecycleStore.isExpired(t, ttl: settings.recycleTTL)

        return HStack(spacing: 12) {
            IconTile(symbol: t.categorySymbol, color: t.categoryTint, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(t.categoryName)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(t.walletName)
                    Text("·")
                    Text(RecycleStore.deletedDateText(t))
                    if !t.note.isEmpty {
                        Text("·")
                        Text(t.note).lineLimit(1)
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)

                Text(RecycleStore.expiryText(of: t, ttl: settings.recycleTTL))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(expired ? AppTheme.expense : Color.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 6) {
                Text(Money.signed(t.cents, t.txKind))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.moneyColor(t.txKind))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(spacing: 6) {
                    rowButton("恢复", icon: "arrow.uturn.backward") {
                        Haptics.success()
                        TransactionStore.restore(ctx: ctx, t)
                        showToast("已恢复到账本")
                    }
                    rowButton("删除", icon: "xmark", destructive: true) {
                        pendingPurge = t
                        showPurgeConfirm = true
                    }
                }
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 2)
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
    }

    private func rowButton(_ title: String,
                           icon: String,
                           destructive: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(destructive ? AppTheme.expense : AppTheme.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule().fill((destructive ? AppTheme.expense : AppTheme.accent).opacity(0.12))
            )
        }
        .pressScale(0.88, animation: Motion.snap)
    }

    private func showToast(_ text: String) {
        withAnimation(Motion.rowInsert) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(Motion.easeOutSwift) { toast = nil }
        }
    }
}
