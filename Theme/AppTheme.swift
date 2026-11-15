import SwiftUI
import UIKit

enum AppTheme {
    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }

    static let accent = dynamic(
        light: UIColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 1),
        dark:  UIColor(red: 0.04, green: 0.52, blue: 1.00, alpha: 1))

    /// 绿进
    static let income = dynamic(
        light: UIColor(red: 0.08, green: 0.60, blue: 0.26, alpha: 1),
        dark:  UIColor(red: 0.20, green: 0.84, blue: 0.40, alpha: 1))

    /// 红出
    static let expense = dynamic(
        light: UIColor(red: 0.86, green: 0.14, blue: 0.12, alpha: 1),
        dark:  UIColor(red: 1.00, green: 0.30, blue: 0.27, alpha: 1))

    static let pageBG = dynamic(
        light: UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1),
        dark:  UIColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1))

    static let card = dynamic(
        light: UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1),
        dark:  UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1))

    static let card2 = dynamic(
        light: UIColor(red: 0.90, green: 0.91, blue: 0.93, alpha: 1),
        dark:  UIColor(red: 0.17, green: 0.17, blue: 0.19, alpha: 1))

    /// 纯色半透明胶囊，不用 material / 液态玻璃，iOS 16 上稳
    static let barBG = dynamic(
        light: UIColor(white: 1.00, alpha: 0.94),
        dark:  UIColor(white: 0.13, alpha: 0.97))

    static let neutral = Color.secondary

    static func moneyColor(_ kind: TransactionKind) -> Color {
        kind == .income ? income : expense
    }

    static func netColor(_ cents: Int64) -> Color {
        cents > 0 ? income : (cents < 0 ? expense : Color.secondary)
    }

    /// 预算色：hue 从 140°(绿) 连续插值到 0°(红)，中间自然经过黄/橙，绝不硬切
    static func budgetTint(_ ratio: Double) -> Color {
        let t = min(max(ratio, 0), 1)
        return Color(hue: 0.39 * (1 - t), saturation: 0.70, brightness: 0.86)
    }

    /// 进度条用的连续渐变（绿 → 黄 → 橙 → 红）
    static let budgetGradient = LinearGradient(
        stops: [
            .init(color: Color(hue: 0.39, saturation: 0.72, brightness: 0.84), location: 0.0),
            .init(color: Color(hue: 0.16, saturation: 0.85, brightness: 0.94), location: 0.50),
            .init(color: Color(hue: 0.02, saturation: 0.85, brightness: 0.94), location: 0.80),
            .init(color: Color(hue: 0.00, saturation: 0.84, brightness: 0.90), location: 1.0)
        ],
        startPoint: .leading,
        endPoint: .trailing)

    static func budgetTier(_ ratio: Double) -> String {
        if ratio > 1 { return "已超支" }
        if ratio < 0.25 { return "充足" }
        if ratio < 0.50 { return "适中" }
        if ratio < 0.75 { return "偏高" }
        return "超值"
    }

    static let palette: [(String, String)] = [
        ("蓝", "#4E8CF7"), ("绿", "#34C759"), ("橙", "#FF9F0A"),
        ("红", "#FF453A"), ("紫", "#AF52DE"), ("青", "#30B0C7"),
        ("粉", "#FF6482"), ("灰", "#8E8E93"), ("靛", "#5E5CE6"),
        ("棕", "#A2845E")
    ]

    static let iconPool: [String] = [
        "fork.knife", "cart.fill", "car.fill", "house.fill", "cross.case.fill",
        "arrow.left.arrow.right", "slider.horizontal.3", "ellipsis",
        "airplane", "gamecontroller.fill", "book.fill", "gift.fill",
        "bag.fill", "creditcard.fill", "bolt.fill", "heart.fill",
        "star.fill", "moon.fill", "sun.max.fill", "pawprint.fill",
        "figure.walk", "bicycle", "film.fill", "music.note",
        "paintbrush.fill", "wrench.fill", "leaf.fill", "flame.fill",
        "drop.fill", "snowflake", "wifi", "phone.fill", "envelope.fill",
        "folder.fill", "tag.fill", "percent", "clock.fill", "calendar"
    ]
}

extension Color {
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
