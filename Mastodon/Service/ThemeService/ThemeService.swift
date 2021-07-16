//
//  ThemeService.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-7-5.
//

import UIKit
import Combine

// ref: https://zamzam.io/protocol-oriented-themes-for-ios-apps/
final class ThemeService {

    // MARK: - Singleton
    public static let shared = ThemeService()

    let currentTheme: CurrentValueSubject<Theme, Never>

    private init() {
        let theme = ThemeName(rawValue: UserDefaults.shared.currentThemeNameRawValue)?.theme ?? ThemeName.mastodon.theme
        currentTheme = CurrentValueSubject(theme)
    }

    func set(themeName: ThemeName) {
        UserDefaults.shared.currentThemeNameRawValue = themeName.rawValue

        let theme = themeName.theme
        apply(theme: theme)
        currentTheme.value = theme
    }

    func apply(theme: Theme) {
        // set navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = theme.navigationBarBackgroundColor
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // set tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()

        let tabBarItemAppearance = UITabBarItemAppearance()
        tabBarItemAppearance.selected.iconColor = theme.tabBarItemSelectedIconColor
        tabBarItemAppearance.focused.iconColor = theme.tabBarItemFocusedIconColor
        tabBarItemAppearance.normal.iconColor = theme.tabBarItemNormalIconColor
        tabBarItemAppearance.disabled.iconColor = theme.tabBarItemDisabledIconColor
        tabBarAppearance.stackedLayoutAppearance = tabBarItemAppearance
        tabBarAppearance.inlineLayoutAppearance = tabBarItemAppearance
        tabBarAppearance.compactInlineLayoutAppearance = tabBarItemAppearance

        tabBarAppearance.backgroundColor = theme.tabBarBackgroundColor
        tabBarAppearance.selectionIndicatorTintColor = Asset.Colors.brandBlue.color
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().barTintColor = theme.tabBarBackgroundColor

        // set table view cell appearance
        UITableViewCell.appearance().backgroundColor = theme.tableViewCellBackgroundColor
        UITableViewCell.appearance(whenContainedInInstancesOf: [SettingsViewController.self]).backgroundColor = theme.secondarySystemGroupedBackgroundColor
        UITableViewCell.appearance().selectionColor = theme.tableViewCellSelectionBackgroundColor

        // set search bar appearance
        UISearchBar.appearance().tintColor = Asset.Colors.brandBlue.color
        UISearchBar.appearance().barTintColor = theme.navigationBarBackgroundColor
        let cancelButtonAttributes: [NSAttributedString.Key : Any] = [NSAttributedString.Key.foregroundColor: Asset.Colors.brandBlue.color]
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self]).setTitleTextAttributes(cancelButtonAttributes, for: .normal)
    }

}
