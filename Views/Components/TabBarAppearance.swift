import SwiftUI

#if os(iOS)
import UIKit
#endif

/// Dark indigo tab bar with white selected icons and muted gray unselected.
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
        appearance.shadowColor = UIColor(AppColor.gold.opacity(0.28))

        let itemAppearance = UITabBarItemAppearance()
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
    #endif
}
