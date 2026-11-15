import Combine
import CoreData
import SwiftUI
import UIKit

struct EditorRoute: Identifiable {
    let id = UUID()
    let transaction: MNTransaction?
}

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.managedObjectContext) private var ctx

    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "occurredAt", ascending: false)])
    private var txFR: FetchedResults<MNTransaction>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "sortIndex", ascending: true)])
    private var walletFR: FetchedResults<MNWallet>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "sortIndex", ascending: true)])
    private var catFR: FetchedResults<MNCategory>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "day", ascending: true)])
    private var budgetFR: FetchedResults<MNBudget>

    @State private var tab: AppTab = .overview
    @State private var editor: EditorRoute?
    @State private var recycleToast: String?

    private var txs: [MNTransaction] { Array(txFR) }
    private var wallets: [MNWallet] { Array(walletFR) }
    private var categories: [MNCategory] { Array(catFR) }
    private var budgets: [MNBudget] { Array(budgetFR) }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.pageBG.ignoresSafeArea()

            Group {
                switch tab {
                case .overview:
                    OverviewView(txs: txs,
                                 wallets: wallets,
                                 categories: categories,
                                 budgets: budgets,
                                 onEdit: openEditor)
                case .transactions:
                    TransactionsView(txs: txs,
                                     wallets: wallets,
                                     categories: categories,
                                     onEdit: openEditor)
                case .wallets:
                    WalletsView(txs: txs, wallets: wallets, onEdit: openEditor)
                case .settings:
                    SettingsView(txs: txs, wallets: wallets, categories: categories, budgets: budgets)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(tab: $tab) {
                editor = EditorRoute(transaction: nil)
            }
        }
        .overlay(alignment: .bottom) {
            if let recycleToast {
                ToastBubble(text: recycleToast)
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(Motion.settle, value: recycleToast)
            }
        }
        .fullScreenCover(item: $editor) { route in
            NewTransactionView(editing: route.transaction,
                               defaultKind: settings.defaultKind,
                               wallets: wallets,
                               categories: categories)
                .environmentObject(settings)
        }
        .onAppear {
            rebuildReminders()
            purgeExpiredRecycle()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppSettings.changedNotification)) { _ in
            rebuildReminders()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            rebuildReminders()
            // 2.0.0：每次回到前台扫一遍回收站，清掉到期条目（不依赖后台定时）
            purgeExpiredRecycle()
        }
    }

    /// 回收站过期清理：只在真有过期条目时写盘
    private func purgeExpiredRecycle() {
        let purged = TransactionStore.purgeExpired(ctx: ctx, ttl: settings.recycleTTL)
        guard purged > 0 else { return }
        Haptics.warning()
        withAnimation(Motion.rowInsert) { recycleToast = "回收站已自动彻底清除 \(purged) 笔过期账目" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(Motion.easeOutSwift) { recycleToast = nil }
        }
    }

    private func openEditor(_ t: MNTransaction) {
        editor = EditorRoute(transaction: t)
    }

    private func rebuildReminders() {
        BudgetReminder.rebuild(settings: settings,
                               budgetDays: Set(budgets.map { $0.day }))
    }
}
