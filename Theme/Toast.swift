import SwiftUI

/// 轻量 Toast：操作已完成但不打断（移入回收站、恢复、清空、过期清理等）。
/// 用玻璃胶囊承载，和底栏/切换控件同一套视觉语言。
struct ToastBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .white.opacity(0.5), location: 0.0),
                                .init(color: .white.opacity(0.05), location: 0.5),
                                .init(color: .black.opacity(0.14), location: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing),
                        lineWidth: 1.0)
            )
            .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
            .padding(.horizontal, 28)
            .allowsHitTesting(false)
    }
}
