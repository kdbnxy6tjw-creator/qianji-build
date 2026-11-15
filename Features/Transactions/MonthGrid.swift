import SwiftUI

/// 交易页「周期」下方的整月 7 列网格。按自然月排，不受自定义月度起始日影响。
struct MonthGrid: View {
    let anchor: Date
    let netByDay: [String: Int64]
    let selectedDay: String?
    let onSelect: (String) -> Void
    let onPrev: () -> Void
    let onNext: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    Haptics.selection()
                    onPrev()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .pressScale(0.85)
                Spacer()
                Text(MonthMath.title(anchor))
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button {
                    Haptics.selection()
                    onNext()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .pressScale(0.85)
            }
            .foregroundStyle(AppTheme.accent)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdays.indices, id: \.self) { i in
                    Text(weekdays[i])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(MonthMath.cells(anchor).indices, id: \.self) { i in
                    let date = MonthMath.cells(anchor)[i]
                    if let date = date {
                        cell(date)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ date: Date) -> some View {
        let key = DayKey.key(date)
        let net = netByDay[key] ?? 0
        let has = netByDay[key] != nil
        let isSelected = selectedDay == key
        let isToday = key == DayKey.today

        Button {
            Haptics.selection()
            onSelect(key)
        } label: {
            VStack(spacing: 3) {
                Text("\(DayKey.calendar.component(.day, from: date))")
                    .font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? AppTheme.accent : Color.primary)

                Text(has ? Money.display(net) : "—")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(has ? AppTheme.netColor(net) : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    )
            }
            .padding(.vertical, 4)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? AppTheme.accent.opacity(0.16) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 1)
            )
        }
        .pressScale(0.90)
    }
}
