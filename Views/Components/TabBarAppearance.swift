import SwiftUI

#if os(iOS)
import UIKit
#endif

/// Applies a dark tab bar with **colored** icons for both selected and unselected states (not system gray).
enum TabBarAppearanceConfigurator {
    static func apply() {
        #if os(iOS)
        applyIOS()
        #endif
    }

    #if os(iOS)
    private static func applyIOS() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColor.tabBarBackground)
        // Subtle top edge so the bar reads as a distinct surface (card/dark), not white.
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.35)

        let itemAppearance = UITabBarItemAppearance()
        // Selected = AppColor.primary, unselected = AppColor.textSecondary (UIKit has no SwiftUI .foregroundStyle on tab items).
        itemAppearance.normal.iconColor = UIColor(AppColor.textSecondary)
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppColor.textSecondary),
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
        ]
        itemAppearance.selected.iconColor = UIColor(AppColor.primary)
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppColor.primary),
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.isTranslucent = false
        tabBar.tintColor = UIColor(AppColor.primary)
        tabBar.unselectedItemTintColor = UIColor(AppColor.textSecondary)
    }
    #endif
}

