import CoreData
import SwiftUI

/// 设置里唯一允许进入二级页面的一项
struct CategoryManageView: View {
    let categories: [MNCategory]

    @Environment(\.managedObjectContext) private var ctx

    @State private var showEditor: CategoryRoute?
    @State private var pendingDelete: MNCategory?
    @State private var showDeleteAlert = false

    private var ordered: [MNCategory] {
        categories.filter { !$0.isOther }.sorted { $0.sortIndex < $1.sortIndex }
    }
    private var other: MNCategory? { CategoryStore.other(categories) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("内置分类可隐藏、不可删除；隐藏的分类收进「其他」的长按气泡里，随时还能选用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Haptics.press()
                    showEditor = CategoryRoute(category: nil)
                } label: {
                    Label("新建分类", systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(AppTheme.accent))
                }
                .pressScale()

                SectionHeader(title: "分类顺序（＋页按此顺序展示）")

                VStack(spacing: 0) {
                    ForEach(ordered.indices, id: \.self) { i in
                        let c = ordered[i]
                        row(c, isFirst: i == 0, isLast: i == ordered.count - 1)
                        if i != ordered.count - 1 { Divider().padding(.leading, 62) }
                    }
                }
                .cardStyle()

                if let other = other {
                    SectionHeader(title: "固定在最后")
                    HStack(spacing: 12) {
                        IconTile(symbol: other.symbol, color: other.tint, size: 42)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("其他")
                                .font(.system(size: 16, weight: .semibold))
                            Text("既是记账类别，也是隐藏分类的入口（长按）")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "pin.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 9)
                    .cardStyle()
                }

                Text("说明：隐藏或删除分类都不会改写已经记过的账单，它们仍显示当时的分类名和图标。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(20)
            .padding(.bottom, 60)
        }
        .background(AppTheme.pageBG.ignoresSafeArea())
        .navigationTitle("分类管理")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Haptics.soft() }
        .sheet(item: $showEditor) { route in
            CategoryEditorView(category: route.category)
        }
        .alert("删除「\(pendingDelete?.name ?? "")」？", isPresented: $showDeleteAlert) {
            Button("放入其他类型库") {
                Haptics.warning()
                if let c = pendingDelete { CategoryStore.remove(ctx: ctx, c, archive: true) }
                pendingDelete = nil
            }
            Button("直接删除", role: .destructive) {
                Haptics.warning()
                if let c = pendingDelete { CategoryStore.remove(ctx: ctx, c, archive: false) }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("两种做法都不会改写任何历史账单，它们继续按原来的分类名显示。放入其他类型库后仍可在「其他」的长按气泡里选用。")
        }
    }

    @ViewBuilder
    private func row(_ c: MNCategory, isFirst: Bool, isLast: Bool) -> some View {
        HStack(spacing: 10) {
            IconTile(symbol: c.symbol, color: c.tint, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(c.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(c.isBuiltIn ? "内置" : "自建")
                    if c.isHidden { Text("· 已隐藏，在「其他」里") }
                }
                .font(.system(size: 11))
                .foregroundStyle(c.isHidden ? AppTheme.accent : Color.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button {
                Haptics.selection()
                CategoryStore.move(ctx: ctx, categories: categories, id: c.id, up: true)
            } label: { arrow("chevron.up", enabled: !isFirst) }
            .disabled(isFirst)
            .pressScale(0.85)

            Button {
                Haptics.selection()
                CategoryStore.move(ctx: ctx, categories: categories, id: c.id, up: false)
            } label: { arrow("chevron.down", enabled: !isLast) }
            .disabled(isLast)
            .pressScale(0.85)

            Button {
                Haptics.selection()
                CategoryStore.setHidden(ctx: ctx, c, hidden: !c.isHidden)
            } label: {
                Image(systemName: c.isHidden ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(c.isHidden ? AppTheme.accent : Color.secondary)
                    .frame(width: 28, height: 28)
            }
            .pressScale(0.85)

            if c.isBuiltIn {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24)
            } else {
                Button {
                    showEditor = CategoryRoute(category: c)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 28)
                }
                .pressScale(0.85)

                Button {
                    pendingDelete = c
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.expense)
                        .frame(width: 24, height: 28)
                }
                .pressScale(0.85)
            }
        }
        .padding(.vertical, 7)
    }

    private func arrow(_ name: String, enabled: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(enabled ? Color.secondary : Color.secondary.opacity(0.35))
            .frame(width: 24, height: 28)
    }
}

struct CategoryRoute: Identifiable {
    let id = UUID()
    let category: MNCategory?
}

/// 新建 / 编辑自建分类：名称 + 图标 + 颜色
struct CategoryEditorView: View {
    let category: MNCategory?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var ctx

    @State private var name: String
    @State private var symbol: String
    @State private var colorHex: String

    init(category: MNCategory?) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _symbol = State(initialValue: category?.symbol ?? "tag.fill")
        _colorHex = State(initialValue: category?.colorHex ?? AppTheme.palette[1].1)
    }

    private let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("名称").font(.caption).foregroundStyle(.secondary)
                        TextField("例如：飞行、订阅、宠物", text: $name)
                            .font(.system(size: 15))
                            .submitLabel(.done)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(AppTheme.card2))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("图标").font(.caption).foregroundStyle(.secondary)
                        LazyVGrid(columns: iconColumns, spacing: 8) {
                            ForEach(AppTheme.iconPool, id: \.self) { s in
                                Button { Haptics.selection(); symbol = s } label: {
                                    Image(systemName: s)
                                        .font(.system(size: 16))
                                        .foregroundStyle(symbol == s ? Color.white : Color.primary)
                                        .frame(maxWidth: .infinity).frame(height: 36)
                                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .fill(symbol == s ? AppTheme.accent : AppTheme.card2))
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
                                Button { Haptics.selection(); colorHex = item.1 } label: {
                                    Circle().fill(Color(hex: item.1))
                                        .frame(width: 28, height: 28)
                                        .overlay(Circle().stroke(Color.primary.opacity(colorHex == item.1 ? 0.9 : 0), lineWidth: 2))
                                }
                                .pressScale(0.85)
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(AppTheme.pageBG.ignoresSafeArea())
            .navigationTitle(category == nil ? "新建分类" : "编辑分类")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { Haptics.soft() }
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
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let c = category {
            c.name = trimmed
            c.symbol = symbol
            c.colorHex = colorHex
            PersistenceController.shared.save()
        } else {
            CategoryStore.create(ctx: ctx, name: trimmed, symbol: symbol, colorHex: colorHex)
        }
        Haptics.success()
        dismiss()
    }
}
