import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !os(iOS)
import AppKit
#endif

// MARK: - App colors (premium indigo / gold)

/// Brand and surface colors. Indigo / gold stay fixed for brand; surfaces follow system appearance (dark mode).
enum AppColor {
    /// Deep indigo — main brand.
    static let primary = Color(hex: "2D346D")
    /// Purple — CTAs, links.
    static let secondary = Color(hex: "5856D6")
    /// Warm gold — premium accents, badges, highlights.
    static let gold = Color(hex: "E8C07A")
    /// Soft teal — secondary accents.
    static let teal = Color(hex: "7ECBC0")

    #if os(iOS)
    /// App canvas — fixed cream (#F5F5F7) for brand consistency (cards stay white).
    static let background = Color(hex: "F5F5F7")
    static let cardBackground = Color.white
    static var surfaceElevated: Color { Color(uiColor: .tertiarySystemBackground) }
    static var textPrimary: Color { Color(uiColor: .label) }
    static var textSecondary: Color { Color(uiColor: .secondaryLabel) }
    static var textTertiary: Color { Color(uiColor: .tertiaryLabel) }
    /// Grouped list chips / bubbles.
    static var secondaryGroupedSurface: Color { Color(uiColor: .secondarySystemFill) }
    #elseif os(macOS)
    static let background = Color(hex: "F5F5F7")
    static let cardBackground = Color.white
    static var surfaceElevated: Color { Color(nsColor: .underPageBackgroundColor) }
    static var textPrimary: Color { Color(nsColor: .labelColor) }
    static var textSecondary: Color { Color(nsColor: .secondaryLabelColor) }
    static var textTertiary: Color { Color(nsColor: .tertiaryLabelColor) }
    static var secondaryGroupedSurface: Color { Color(nsColor: .controlBackgroundColor) }
    #else
    static let background = Color(hex: "F5F5F7")
    static let cardBackground = Color.white
    static let surfaceElevated = Color(hex: "FAFAFA")
    static let textPrimary = Color(hex: "1A1A2E")
    static let textSecondary = Color(hex: "6B7280")
    static let textTertiary = Color(hex: "9CA3AF")
    static let secondaryGroupedSurface = surfaceElevated
    #endif

    static let error = Color(hex: "DC2626")
    static let success = Color(hex: "059669")
    static let warning = Color(hex: "D97706")

    /// Dark indigo tab bar surface.
    static let tabBarBackground = Color(hex: "1C1C2E")
    /// Tab bar — selected icon/label (white on dark bar).
    static let tabBarSelected = Color.white
    /// Tab bar — unselected (#6B7280).
    static let tabBarUnselected = Color(hex: "6B7280")

    /// Primary brand label color (use instead of `Color.primary`).
    static let labelPrimary = textPrimary
    static let labelSecondary = textSecondary

    /// Legacy semantic names — map to the new palette for existing call sites.
    static let accentOrange = gold
    static let accentPurple = secondary
    static let premiumBadge = gold
    static let investorBadge = secondary
    static let expertBadge = teal

    static let brandGradient = LinearGradient(
        colors: [Color(hex: "2D346D"), Color(hex: "5856D6")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Full-screen welcome / auth backgrounds (deep indigo).
    static let welcomeGradient = LinearGradient(
        colors: [
            Color(hex: "1C1C2E"),
            Color(hex: "2D346D"),
            Color(hex: "5856D6"),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static var headerGradient: LinearGradient {
        LinearGradient(
            colors: [AppColor.background, AppColor.surfaceElevated],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Gold shimmer for premium CTAs.
    static let goldAccentGradient = LinearGradient(
        colors: [Color(hex: "E8C07A"), Color(hex: "D4A84B")],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Card chrome & shadows

enum CardChrome {
    static let cornerRadiusLarge: CGFloat = 20
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusChip: CGFloat = 8

    /// Backward-compatible default for inline surfaces (medium).
    static let cornerRadius: CGFloat = cornerRadiusMedium

    static let sectionSpacing: CGFloat = 24
    static let padding: CGFloat = 16

    /// Elevated cards — opacity 0.06, radius 16, y 6.
    static let shadowColor = Color.black.opacity(0.06)

    /// Buttons — opacity 0.08, radius 8, y 3.
    static let buttonShadowColor = Color.black.opacity(0.08)

    /// Elevated cards (main surfaces).
    static let shadowRadiusElevated: CGFloat = 16
    static let shadowYElevated: CGFloat = 6

    /// Buttons & compact controls.
    static let shadowRadiusButton: CGFloat = 8
    static let shadowYButton: CGFloat = 3

    /// Legacy single shadow — maps to elevated (for any remaining references).
    static let shadowRadius: CGFloat = shadowRadiusElevated
    static let shadowY: CGFloat = shadowYElevated
}

extension View {
    /// White card on cream background with elevated shadow and large corner radius.
    func deskerElevatedCard() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                    .fill(AppColor.cardBackground)
                    .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
            )
    }

    /// Compact elevated surface (medium radius, same shadow system).
    func deskerMediumCard() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                    .fill(AppColor.cardBackground)
                    .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
            )
    }

    func deskerButtonShadow() -> some View {
        shadow(color: CardChrome.buttonShadowColor, radius: CardChrome.shadowRadiusButton, x: 0, y: CardChrome.shadowYButton)
    }

    /// `navigationBarTitleDisplayMode` is unavailable on macOS.
    @ViewBuilder
    func deskerInlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func deskerHiddenNavigationBar() -> some View {
        #if os(iOS)
        self.navigationBarHidden(true)
        #else
        self
        #endif
    }

    @ViewBuilder
    func deskerInsetGroupedListStyle() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self.listStyle(.inset)
        #endif
    }

    @ViewBuilder
    func deskerTextFieldNoAutocaps() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never)
        #else
        self
        #endif
    }
}

// MARK: - Role badge colors (Explore / Profile)

enum RoleBadgePalette {
    static func color(for role: UserRole) -> Color {
        switch role {
        case .founder: return AppColor.primary
        case .investor: return AppColor.gold
        case .mentor: return AppColor.teal
        case .aspiringFounder: return AppColor.secondary
        }
    }
}

// MARK: - Chip / pill press feedback (onboarding & filters)

struct DeskerChipPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.18), value: configuration.isPressed)
    }
}

/// Card-style controls: subtle scale on press (0.98).
struct DeskerCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

extension View {
    /// Springy slide-up feel for sheet content (call on root inside `sheet`).
    func deskerSheetSpringContent() -> some View {
        modifier(DeskerSheetSpringModifier())
    }
}

private struct DeskerSheetSpringModifier: ViewModifier {
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .offset(y: appeared ? 0 : 28)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
                    appeared = true
                }
            }
    }
}

// MARK: - Display truncation (cards & lists)

extension String {
    /// Trims whitespace, then truncates to `maxLength` characters with an ellipsis (not counting the suffix).
    func deskerTruncated(maxLength: Int, suffix: String = "…") -> String {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > maxLength else { return t }
        return String(t.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines) + suffix
    }
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
