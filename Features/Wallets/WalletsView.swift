import CoreData
import SwiftUI

struct WalletRoute: Identifiable {
    let id = UUID()
    let wallet: MNWallet?
}

enum WalletSort: String, CaseIterable {
    case custom
    case balance
    case name
    var title: String {
        switch self {
        case .custom: return "自定义顺序"
        case .balance: return "按余额"
        case .name: return "按名称"
        }
    }
}

struct WalletsView: View {
    let txs: [MNTransaction]
    let wallets: [MNWallet]
    let onEdit: (MNTransaction) -> Void

    @Environment(\.managedObjectContext) private var ctx
    @EnvironmentObject private var settings: AppSettings

    @State private var sortMode: WalletSort = .custom
    @State private var editor: WalletRoute?

    private var totalAssets: Int64 { Ledger.totalAssets(txs, wallets: wallets) }

    private var sorted: [MNWallet] {
        switch sortMode {
        case .custom:
            return wallets.sorted { $0.sortIndex < $1.sortIndex }
        case .balance:
            return wallets.sorted {
                Ledger.balance(txs, walletId: $0.id, initial: $0.initialCents) >
                Ledger.balance(txs, walletId: $1.id, initial: $1.initialCents)
            }
        case .name:
            return wallets.sorted { $0.name < $1.name }
        }
    }

    private let groups: [(String, [WalletKind])] = [
        ("现金和电子钱包", [.cash, .ewallet]),
        ("银行账户", [.bank]),
        ("信用卡", [.credit])
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center) {
                    Text("钱包")
                        .font(.system(size: 34, weight: .bold))
                    Spacer()
                    Button {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sortMode = WalletSort.allCases[
                                (WalletSort.allCases.firstIndex(of: sortMode)! + 1) % WalletSort.allCases.count
                            ]
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 34, height: 34)
                    }
                    .pressScale(0.88)
                    Button {
                        Haptics.press()
                        editor = WalletRoute(wallet: nil)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 34, height: 34)
                    }
                    .pressScale(0.88)
                }

                HStack {
                    Text("总资产")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Money.net(totalAssets))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.netColor(totalAssets))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .cardStyle()

                Text(sortMode.title)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)

                ForEach(groups.indices, id: \.self) { gi in
                    let group = groups[gi]
                    let items = sorted.filter { group.1.contains($0.walletKind) }
                    if !items.isEmpty {
                        SectionHeader(title: group.0)
                        VStack(spacing: 0) {
                            ForEach(items, id: \.id) { w in
                                Button {
                                    Haptics.soft()
                                    editor = WalletRoute(wallet: w)
                                } label: {
                                    walletRow(w)
                                }
                                .pressScale(Motion.cardPressScale)
                                if w.id != items.last?.id {
                                    Divider().padding(.leading, 62)
                                }
                            }
                        }
                        .cardStyle()
                    }
                }

                if wallets.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 30)).foregroundStyle(.tertiary)
                        Text("还没有钱包")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("点右上角 ＋ 建一个")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 34)
                    .cardStyle()
                }
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 130)
        }
        .sheet(item: $editor) { route in
            WalletEditorView(wallet: route.wallet, txs: txs, wallets: wallets)
        }
    }

    @ViewBuilder
    private func walletRow(_ w: MNWallet) -> some View {
        let balance = Ledger.balance(txs, walletId: w.id, initial: w.initialCents)
        HStack(spacing: 12) {
            IconTile(symbol: w.symbol, color: w.tint, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(w.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                Text(w.walletKind.title + (w.isArchived ? " · 已归档" : ""))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            Text(Money.net(balance))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.netColor(balance))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 9)
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
    }
}
