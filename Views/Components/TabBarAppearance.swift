import SwiftUI
import UIKit

/// Applies a dark tab bar with **colored** icons for both selected and unselected states (not system gray).
enum TabBarAppearanceConfigurator {
    static func apply() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColor.tabBarBackground)
        // Subtle top edge so the bar reads as a distinct surface (card/dark), not white.
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.35)

        let itemAppearance = UITabBarItemAppearance()
        // Tinted tab icons: both states use explicit brand hues (never template gray / white).
        itemAppearance.normal.iconColor = UIColor(AppColor.tabBarUnselected)
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppColor.tabBarUnselected),
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
        ]
        itemAppearance.selected.iconColor = UIColor(AppColor.tabBarSelected)
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppColor.tabBarSelected),
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.isTranslucent = false
        tabBar.tintColor = UIColor(AppColor.tabBarSelected)
        tabBar.unselectedItemTintColor = UIColor(AppColor.tabBarUnselected)
    }
}
