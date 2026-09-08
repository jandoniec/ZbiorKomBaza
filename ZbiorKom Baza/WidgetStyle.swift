//
//  WidgetVisualStyle.swift
//  ZbiorKom Baza
//
//  Created by Jan Doniec on 08/09/2026.
//




import Foundation

enum WidgetVisualStyle: String, CaseIterable {
    case standard
    case krakowBoard

    var title: String {
        switch self {
        case .standard:
            return "Standardowy"
        case .krakowBoard:
            return "Krakowska tablica"
        }
    }
}

enum WidgetStyleStore {
    static let styleKey = "widgetStyle"
    static let confirmationKey = "widgetFullColorConfirmed"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: WidgetConstants.appGroup)
    }

    static func loadStyle() -> WidgetVisualStyle {
        let raw = defaults?.string(forKey: styleKey) ?? "standard"
        return WidgetVisualStyle(rawValue: raw) ?? .standard
    }

    static func saveStyle(_ style: WidgetVisualStyle) {
        defaults?.set(style.rawValue, forKey: styleKey)
    }

    static func isFullColorConfirmed() -> Bool {
        defaults?.bool(forKey: confirmationKey) ?? false
    }

    static func setFullColorConfirmed(_ confirmed: Bool) {
        defaults?.set(confirmed, forKey: confirmationKey)
    }
}
