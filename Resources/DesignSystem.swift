import SwiftUI

/// Brand and surface colors. Uses hex values so the app works without an Asset Catalog.
enum AppColor {
    static let primary = Color(hex: "007AFF")
    static let secondary = Color(hex: "00C7BE")
    static let accentOrange = Color(hex: "FF9500")
    static let accentPurple = Color(hex: "AF52DE")
    static let background = Color(hex: "F2F2F7")
    static let cardBackground = Color(hex: "2C2C2E")
    static let headerBackground = Color.white
    static let tabBarBackground = Color(hex: "1C1C1E")
    static let tabBarUnselected = Color(hex: "5AC8FA")
    static let tabBarSelected = Color(hex: "0A84FF")
    static let labelPrimary = Color.primary
    static let labelSecondary = Color.secondary

    static let brandGradient = LinearGradient(
        colors: [Color(hex: "007AFF"), Color(hex: "00C7BE")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let headerGradient = LinearGradient(
        colors: [
            Color.white,
            Color(hex: "F7F9FC"),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let premiumBadge = Color.yellow
    static let investorBadge = Color.blue
    static let expertBadge = Color.green
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
