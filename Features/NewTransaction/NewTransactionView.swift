import CoreData
import SwiftUI

struct NewTransactionView: View {
    let editing: MNTransaction?
    let wallets: [MNWallet]
    let categories: [MNCategory]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var ctx
    @EnvironmentObject private var settings: AppSettings

    @State private var kind: TransactionKind
    @State private var raw: String
    @State private var selectedCategoryID: UUID?
    @State private var walletID: UUID?
    @State private var date: Date
    @State private var note: String
    @State private var showHiddenBubble = false
    @State private var showDeleteConfirm = false
    @State private var showIncompleteHint = false
    @FocusState private var noteFocused: Bool

    init(editing: MNTransaction?,
         defaultKind: TransactionKind,
         wallets: [MNWallet],
         categories: [MNCategory]) {
        self.editing = editing
        self.wallets = wallets
        self.categories = categories
        _kind = State(initialValue: editing?.txKind ?? defaultKind)
        _raw = State(initialValue: editing.map { Money.raw(fromCents: $0.cents) } ?? "")
        _selectedCategoryID = State(initialValue: editing?.categoryId
                                    ?? CategoryStore.gridItems(categories).first?.id)
        _walletID = State(initialValue: editing?.walletId ?? wallets.first?.id)
        _date = State(initialValue: editing?.occurredAt ?? Date())
        _note = State(initialValue: editing?.note ?? "")
    }

    private var selectedCategory: MNCategory? {
        categories.first { $0.id == selectedCategoryID }
    }
    private var selectedWallet: MNWallet? {
        wallets.first { $0.id == walletID }
    }
    private var canSave: Bool {
        Money.cents(fromRaw: raw) > 0 && selectedCategory != nil && selectedWallet != nil
    }

    var body: some View {
        ZStack {
            AppTheme.pageBG.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                // 可上下滑动区
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        amountRow
                        if showIncompleteHint {
                            Text("还差一步：填金额、选分类和钱包后才能保存")
                                .font(.caption)
                                .foregroundStyle(AppTheme.expense)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity)
                        }
                        if let c = selectedCategory, c.isHidden {
                            Text("当前分类：\(c.name)（已隐藏，账单仍按原名称记录）")
                                .font(.caption)
                                .foregroundStyle(AppTheme.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        CategoryGrid(categories: categories,
                                     layout: settings.categoryLayout,
                                     selectedID: selectedCategoryID,
                                     onSelect: { c in
                                         Haptics.selection()
                                         showIncompleteHint = false
                                         selectedCategoryID = c.id
                                     },
                                     onOtherLongPress: {
                                         Haptics.longPress()
                                         showHiddenBubble = true
                                     })
                        walletRow
                        dateRow
                        noteRow
                        if editing != nil { deleteButton }
                    }
                    .frame(maxWidth: 620, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 14)
                }

                Divider().opacity(0.12)

                // 常驻区：键盘 + 两个不相连的胶囊
                AmountKeypad(raw: $raw)
                BottomActionBar(kind: $kind, enabled: canSave, onSave: save)
            }

            PopupBackdrop(isPresented: showHiddenBubble,
                          onDismiss: { showHiddenBubble = false }) {
                HiddenCategoryBubble(hidden: CategoryStore.hidden(categories)) { c in
                    Haptics.selection()
                    selectedCategoryID = c.id
                    showHiddenBubble = false
                }
            }
        }
        .onAppear { Haptics.prepareKeypad() }   // 键盘高频输入前预热，降低首次延迟
        .onChange(of: raw) { _ in
            if Money.cents(fromRaw: raw) > 0 { showIncompleteHint = false }
        }
    }

    // MARK: - 顶部

    private var topBar: some View {
        HStack {
            Button("取消") { dismiss() }
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.accent)
                .pressScale(0.92, animation: Motion.snap)
            Spacer()
            Text(editing == nil ? "新交易" : "编辑交易")
                .font(.system(size: 17, weight: .bold))
            Spacer()
            Color.clear.frame(width: 44, height: 30)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    // MARK: - 金额

    private var amountRow: some View {
        HStack(alignment: .center) {
            Button {
                Haptics.selection()
                kind = (kind == .expense) ? .income : .expense
            } label: {
                Image(systemName: "plusminus")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
            }
            .pressScale(0.88)

            Spacer(minLength: 4)

            Text((raw.isEmpty ? "0" : raw) + " CNY")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.moneyColor(kind))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Spacer(minLength: 4)
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.vertical, 6)
    }

    // MARK: - 钱包 / 日期 / 备注

    private var walletRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text("钱包")
                .font(.system(size: 15))
            Spacer()
            Menu {
                ForEach(wallets, id: \.id) { w in
                    Button {
                        Haptics.selection()
                        showIncompleteHint = false
                        walletID = w.id
                    } label: {
                        Label(w.name, systemImage: w.symbol)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: selectedWallet?.symbol ?? "questionmark.circle")
                        .foregroundStyle(selectedWallet?.tint ?? Color.secondary)
                    Text(selectedWallet?.name ?? "选择钱包")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(AppTheme.card2))
    }

    private var dateRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text("日期")
                .font(.system(size: 15))
            Spacer()
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "zh_CN"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(AppTheme.card2))
    }

    private var noteRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            TextField("备注（选填）", text: $note)
                .font(.system(size: 15))
                .submitLabel(.done)
                .focused($noteFocused)
                .onSubmit { noteFocused = false }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(AppTheme.card2))
    }

    private var deleteButton: some View {
        Button {
            if settings.confirmBeforeDelete {
                showDeleteConfirm = true
            } else if let t = editing {
                Haptics.warning()
                TransactionStore.softDelete(ctx: ctx, t)
                dismiss()
            }
        } label: {
            Text("删除这笔账单")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.expense)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(AppTheme.expense.opacity(0.12)))
        }
        .pressScale()
        .alert("把这笔账单移进回收站？", isPresented: $showDeleteConfirm) {
            Button("移入回收站", role: .destructive) {
                if let t = editing {
                    Haptics.warning()       // 破坏性操作，留一记警示
                    TransactionStore.softDelete(ctx: ctx, t)
                    dismiss()
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text(deleteMessage)
        }

    private var deleteMessage: String {
        switch settings.recycleTTL {
        case .never:
            return "不会立刻消失，会先进回收站，之后可在「设置 → 回收站」恢复或手动清空。"
        default:
            return "不会立刻消失：\(settings.recycleTTL.title)后自动彻底清除，期间可在回收站恢复。"
        }
    }
    }

    // MARK: - 保存

    private func save() {
        guard let category = selectedCategory,
              let wallet = selectedWallet,
              Money.cents(fromRaw: raw) > 0 else {
            Haptics.warning()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showIncompleteHint = true
            }
            return
        }
        let cents = Money.cents(fromRaw: raw)
        TransactionStore.upsert(ctx: ctx,
                                editing: editing,
                                kind: kind,
                                cents: cents,
                                wallet: wallet,
                                category: category,
                                date: date,
                                note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        Haptics.success()                   // 全 app 唯一的"完成"确认
        dismiss()
    }
}
