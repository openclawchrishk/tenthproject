import SwiftUI
import UIKit

/// Applies a dark tab bar with **colored** icons for both selected and unselected states (not system gray).
enum TabBarAppearanceConfigurator {
    static func apply() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColor.tabBarBackground)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor(AppColor.tabBarUnselected)
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppColor.tabBarUnselected),
        ]
        itemAppearance.selected.iconColor = UIColor(AppColor.tabBarSelected)
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppColor.tabBarSelected),
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isTranslucent = false
    }
}
