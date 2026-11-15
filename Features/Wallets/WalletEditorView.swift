import CoreData
import SwiftUI

struct WalletEditorView: View {
    let wallet: MNWallet?
    let txs: [MNTransaction]
    let wallets: [MNWallet]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var ctx

    @State private var name: String
    @State private var kind: WalletKind
    @State private var symbol: String
    @State private var colorHex: String
    @State private var initialRaw: String
    @State private var showDeleteConfirm = false
    @State private var showBlocked = false

    init(wallet: MNWallet?, txs: [MNTransaction], wallets: [MNWallet]) {
        self.wallet = wallet
        self.txs = txs
        self.wallets = wallets
        _name = State(initialValue: wallet?.name ?? "")
        _kind = State(initialValue: wallet?.walletKind ?? .cash)
        _symbol = State(initialValue: wallet?.symbol ?? WalletKind.cash.symbol)
        _colorHex = State(initialValue: wallet?.colorHex ?? AppTheme.palette.first!.1)
        _initialRaw = State(initialValue: wallet.map { Money.raw(fromCents: $0.initialCents) } ?? "0,00")
    }

    private var txCount: Int {
        guard let wallet = wallet else { return 0 }
        return WalletStore.transactionCount(txs, walletId: wallet.id)
    }

    private var symbolColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    field("钱包名称") {
                        TextField("例如：工资卡、饭卡", text: $name)
                            .submitLabel(.done)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("类型").font(.caption).foregroundStyle(.secondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                            ForEach(WalletKind.allCases) { k in
                                Button {
                                    Haptics.selection()
                                    kind = k
                                    symbol = k.symbol
                                } label: {
                                    Text(k.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(kind == k ? Color.white : Color.primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .background(Capsule().fill(kind == k ? AppTheme.accent : AppTheme.card2))
                                }
                                .pressScale(0.92, animation: Motion.snap)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("图标").font(.caption).foregroundStyle(.secondary)
                        LazyVGrid(columns: symbolColumns, spacing: 8) {
                            ForEach(AppTheme.iconPool.prefix(24), id: \.self) { s in
                                Button {
                                    Haptics.selection()
                                    symbol = s
                                } label: {
                                    Image(systemName: s)
                                        .font(.system(size: 16))
                                        .foregroundStyle(symbol == s ? Color.white : Color.primary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                .fill(symbol == s ? AppTheme.accent : AppTheme.card2)
                                        )
                                }
                                .pressScale(0.90)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("颜色").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            ForEach(AppTheme.palette.indices, id: \.self) { i in
                                let item = AppTheme.palette[i]
                                Button {
                                    Haptics.selection()
                                    colorHex = item.1
                                } label: {
                                    Circle()
                                        .fill(Color(hex: item.1))
                                        .frame(width: 28, height: 28)
                                        .overlay(Circle().stroke(Color.primary.opacity(colorHex == item.1 ? 0.9 : 0),
                                                                 lineWidth: 2))
                                }
                                .pressScale(0.85)
                            }
                        }
                    }

                    field("初始余额（CNY）") {
                        TextField("0,00", text: $initialRaw)
                            .keyboardType(.decimalPad)
                            .submitLabel(.done)
                    }

                    if let wallet = wallet {
                        HStack {
                            Text("名下账单")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(txCount) 笔")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            if txCount > 0 {
                                Haptics.warning()
                                showBlocked = true
                            } else {
                                Haptics.soft()
                                showDeleteConfirm = true
                            }
                        } label: {
                            Text("删除钱包")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.expense)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(AppTheme.expense.opacity(0.12)))
                        }
                        .pressScale()
                    }
                }
                .frame(maxWidth: 560, alignment: .leading)
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(AppTheme.pageBG.ignoresSafeArea())
            .navigationTitle(wallet == nil ? "新建钱包" : "编辑钱包")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }.foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { save() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("删除钱包？", isPresented: $showDeleteConfirm) {
                Button("删除", role: .destructive) {
                    if let w = wallet {
                        Haptics.warning()
                        WalletStore.delete(ctx: ctx, w)
                        dismiss()
                    }
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("该钱包下没有账单，可以安全删除。")
            }
            .alert("这个钱包还有账单", isPresented: $showBlocked) {
                Button("知道了", role: .cancel) { }
            } message: {
                Text("「\(wallet?.name ?? "")」下还有 \(txCount) 笔账单。请先到「交易」页处理这些账单，再删除钱包，避免总资产对不上。")
            }
        }
    }

    @ViewBuilder
    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content()
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(AppTheme.card2))
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        WalletStore.upsert(ctx: ctx,
                           editing: wallet,
                           name: trimmed,
                           kind: kind,
                           symbol: symbol,
                           colorHex: colorHex,
                           initialCents: Money.cents(fromRaw: initialRaw))
        Haptics.success()
        dismiss()
    }
}
