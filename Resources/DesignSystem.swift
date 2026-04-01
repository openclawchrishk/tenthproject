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

    /// Full-screen welcome / auth — indigo → purple.
    static let welcomeGradient = LinearGradient(
        colors: [
            Color(hex: "3730A3"),
            Color(hex: "4C1D95"),
            Color(hex: "7C3AED"),
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
    /// Primary buttons — horizontal / vertical padding (spec).
    static let buttonPaddingHorizontal: CGFloat = 16
    static let buttonPaddingVertical: CGFloat = 12
    /// List rows — vertical rhythm between items.
    static let listItemSpacing: CGFloat = 12

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

    /// Floating controls (FAB, overlay back affordances).
    static let shadowRadiusFloating: CGFloat = 14
    static let shadowYFloating: CGFloat = 8
    static let shadowColorFloating = Color.black.opacity(0.12)
}

// MARK: - Animation timing (micro-interactions)

enum DeskerAnimation {
    /// Press-in for buttons / chips.
    static let pressIn = Animation.easeInOut(duration: 0.1)
    /// Release — spring back (~200ms feel).
    static let releaseSpring = Animation.spring(response: 0.2, dampingFraction: 0.78)
    /// Card press / release (mirrors buttons with slightly softer release).
    static let cardReleaseSpring = Animation.spring(response: 0.2, dampingFraction: 0.8)
    /// Tab content cross-fade.
    static let tabCrossFade = Animation.easeInOut(duration: 0.2)
    /// Validation shake window.
    static let shakeTotal: TimeInterval = 0.3
    /// Error border pulse cycle.
    static let errorPulse: TimeInterval = 0.2
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

    /// Stronger shadow for floating chrome (e.g. overlay back button).
    func deskerFloatingShadow() -> some View {
        shadow(color: CardChrome.shadowColorFloating, radius: CardChrome.shadowRadiusFloating, x: 0, y: CardChrome.shadowYFloating)
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

    /// Dismisses keyboard when the user scrolls (iOS).
    func deskerScrollDismissesKeyboard() -> some View {
        #if os(iOS)
        self.scrollDismissesKeyboard(.interactively)
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
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(configuration.isPressed ? DeskerAnimation.pressIn : DeskerAnimation.releaseSpring, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { HapticFeedback.light() }
            }
    }
}

/// Primary buttons — press 0.97 @ 100ms, spring release ~200ms; use `.opacity` when `disabled`.
struct DeskerButtonPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(configuration.isPressed ? DeskerAnimation.pressIn : DeskerAnimation.releaseSpring, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { HapticFeedback.medium() }
            }
    }
}

/// Card-style controls: press 0.98 @ 100ms, spring release ~200ms.
struct DeskerCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(configuration.isPressed ? DeskerAnimation.pressIn : DeskerAnimation.cardReleaseSpring, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { HapticFeedback.light() }
            }
    }
}

extension View {
    /// Springy slide-up feel for sheet content (call on root inside `sheet`).
    func deskerSheetSpringContent() -> some View {
        modifier(DeskerSheetSpringModifier())
    }

    /// Loading / skeleton pulse (legacy subtle opacity breathe).
    func deskerPulse(active: Bool) -> some View {
        modifier(DeskerPulseModifier(active: active))
    }

    /// Skeleton placeholder shimmer (preferred over pulse for bars).
    func deskerSkeletonShimmer(active: Bool = true) -> some View {
        modifier(DeskerSkeletonShimmerModifier(active: active))
    }

    /// Horizontal shake for validation errors — 3 oscillations in 300ms.
    func deskerShake(trigger: Int) -> some View {
        modifier(DeskerShakeModifier(trigger: trigger))
    }

    /// One-cycle red border emphasis when `active` becomes true (e.g. inline validation).
    func deskerErrorBorderPulse(trigger: Int, cornerRadius: CGFloat = CardChrome.cornerRadiusMedium) -> some View {
        modifier(DeskerErrorBorderPulseModifier(trigger: trigger, cornerRadius: cornerRadius))
    }
}

private struct DeskerPulseModifier: ViewModifier {
    let active: Bool
    @State private var phase = false

    func body(content: Content) -> some View {
        content
            .opacity(phase && active ? 0.55 : 1)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    phase = true
                }
            }
            .onChange(of: active) { _, new in
                if !new { phase = false }
            }
    }
}

private struct DeskerShakeModifier: ViewModifier {
    var trigger: Int
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { _, _ in
                // 3 oscillations (6 half-cycles + rest) within ~300ms
                let steps: [CGFloat] = [10, -10, 8, -8, 5, -5, 0]
                let stepCount = max(steps.count - 1, 1)
                let dt = DeskerAnimation.shakeTotal / Double(stepCount)
                offset = 0
                for (i, x) in steps.enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * dt) {
                        withAnimation(.easeInOut(duration: dt * 0.95)) {
                            offset = x
                        }
                    }
                }
            }
    }
}

private struct DeskerErrorBorderPulseModifier: ViewModifier {
    var trigger: Int
    var cornerRadius: CGFloat
    @State private var pulse: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColor.error.opacity(0.25 + pulse * 0.7), lineWidth: 1 + pulse * 1.25)
            )
            .onChange(of: trigger) { _, _ in
                var t = Transaction(animation: nil)
                t.disablesAnimations = true
                withTransaction(t) { pulse = 1 }
                withAnimation(.easeInOut(duration: DeskerAnimation.errorPulse)) {
                    pulse = 0
                }
            }
    }
}

private struct DeskerSkeletonShimmerModifier: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = -0.7

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    GeometryReader { geo in
                        let w = geo.size.width
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(0.55),
                                Color.white.opacity(0),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: w * 0.42)
                        .offset(x: phase * (w + w * 0.42))
                        .blendMode(.overlay)
                    }
                    .allowsHitTesting(false)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .onAppear {
                guard active else { return }
                phase = -0.7
                withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}

private struct DeskerSheetSpringModifier: ViewModifier {
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .offset(y: appeared ? 0 : 36)
            .opacity(appeared ? 1 : 0)
            #if os(iOS)
            .presentationDragIndicator(.visible)
            #endif
            .onAppear {
                withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
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

// MARK: - UX preferences (first visit tips, onboarding handoff)

enum DeskerUXPreferences {
    private static let pendingExploreAfterOnboardingKey = "deskerUX.pendingExploreAfterOnboarding"
    private static let showExploreSwipeTipKey = "deskerUX.showExploreSwipeTip"
    private static let tipExploreDismissedKey = "deskerUX.tipExploreDismissed"
    private static let tipDeskDismissedKey = "deskerUX.tipDeskDismissed"
    private static let tipMessagesDismissedKey = "deskerUX.tipMessagesDismissed"
    private static let tipProfileDismissedKey = "deskerUX.tipProfileDismissed"
    private static let favoriteFounderIdsKey = "deskerUX.favoriteFounderIds"
    private static let deskDraftKey = "deskerUX.deskCreationDraft"
    private static let showAppTutorialAfterOnboardingKey = "deskerUX.showAppTutorialAfterOnboarding"
    private static let appTutorialDismissedKey = "deskerUX.appTutorialDismissed"

    /// Set from onboarding completion; Main tab consumes once to present the feature tour.
    static var showAppTutorialAfterOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: showAppTutorialAfterOnboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: showAppTutorialAfterOnboardingKey) }
    }

    static var appTutorialDismissed: Bool {
        get { UserDefaults.standard.bool(forKey: appTutorialDismissedKey) }
        set { UserDefaults.standard.set(newValue, forKey: appTutorialDismissedKey) }
    }

    static var pendingExploreAfterOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: pendingExploreAfterOnboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: pendingExploreAfterOnboardingKey) }
    }

    static var showExploreSwipeTip: Bool {
        get { UserDefaults.standard.bool(forKey: showExploreSwipeTipKey) }
        set { UserDefaults.standard.set(newValue, forKey: showExploreSwipeTipKey) }
    }

    static var tipExploreDismissed: Bool {
        get { UserDefaults.standard.bool(forKey: tipExploreDismissedKey) }
        set { UserDefaults.standard.set(newValue, forKey: tipExploreDismissedKey) }
    }

    static var tipDeskDismissed: Bool {
        get { UserDefaults.standard.bool(forKey: tipDeskDismissedKey) }
        set { UserDefaults.standard.set(newValue, forKey: tipDeskDismissedKey) }
    }

    static var tipMessagesDismissed: Bool {
        get { UserDefaults.standard.bool(forKey: tipMessagesDismissedKey) }
        set { UserDefaults.standard.set(newValue, forKey: tipMessagesDismissedKey) }
    }

    static var tipProfileDismissed: Bool {
        get { UserDefaults.standard.bool(forKey: tipProfileDismissedKey) }
        set { UserDefaults.standard.set(newValue, forKey: tipProfileDismissedKey) }
    }

    static func isFavoriteFounder(_ id: UUID) -> Bool {
        favoriteFounderIds.contains(id.uuidString)
    }

    static func toggleFavoriteFounder(_ id: UUID) {
        var s = favoriteFounderIds
        let key = id.uuidString
        if s.contains(key) { s.remove(key) } else { s.insert(key) }
        UserDefaults.standard.set(Array(s), forKey: favoriteFounderIdsKey)
    }

    private static var favoriteFounderIds: Set<String> {
        get {
            let a = UserDefaults.standard.stringArray(forKey: favoriteFounderIdsKey) ?? []
            return Set(a)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: favoriteFounderIdsKey)
        }
    }

    static func saveDeskDraft(_ json: String?) {
        if let json, !json.isEmpty {
            UserDefaults.standard.set(json, forKey: deskDraftKey)
        } else {
            UserDefaults.standard.removeObject(forKey: deskDraftKey)
        }
    }

    static func loadDeskDraft() -> String? {
        UserDefaults.standard.string(forKey: deskDraftKey)
    }
}

// MARK: - Skeleton placeholders

struct DeskerSkeletonBar: View {
    var height: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(AppColor.secondaryGroupedSurface)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .deskerSkeletonShimmer(active: true)
            .opacity(0.92)
    }
}

struct ExploreCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                    .fill(AppColor.secondaryGroupedSurface)
                    .frame(width: 60, height: 60)
                    .deskerSkeletonShimmer(active: true)
                VStack(alignment: .leading, spacing: 8) {
                    DeskerSkeletonBar(height: 18)
                    DeskerSkeletonBar(height: 12)
                    DeskerSkeletonBar(height: 12)
                }
            }
            DeskerSkeletonBar(height: 44)
        }
        .padding(CardChrome.padding)
        .deskerElevatedCard()
    }
}
