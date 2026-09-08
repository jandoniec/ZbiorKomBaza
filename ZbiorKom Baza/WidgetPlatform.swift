//
//  WidgetPlatform.swift
//  ZbiorKom Baza
//
//  Created by Jan Doniec on 08/09/2026.
//



import Foundation

// MARK: - Platform numbers

enum WidgetPlatform {
    static func number(from code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.suffix(2))
    }
}

// MARK: - Widget selection

struct WidgetStopSelection: Codable, Equatable {
    let groupID: String
    let platformCode: String?

    // nil = wszystkie słupki danego przystanku
}

struct WidgetFavoriteStop: Codable, Identifiable {
    let id: String
    let name: String
    let platforms: [String]
}

// MARK: - Shared storage

enum WidgetStopStore {
    private static let selectionKey = "widgetStopSelection"
    private static let favoritesKey = "widgetFavoriteStops"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: WidgetConstants.appGroup)
    }

    static func loadSelection() -> WidgetStopSelection? {
        guard let data = defaults?.data(forKey: selectionKey) else {
            return nil
        }

        return try? JSONDecoder().decode(
            WidgetStopSelection.self,
            from: data
        )
    }

    static func saveSelection(_ selection: WidgetStopSelection?) {
        guard let selection else {
            defaults?.removeObject(forKey: selectionKey)
            return
        }

        guard let data = try? JSONEncoder().encode(selection) else {
            return
        }

        defaults?.set(data, forKey: selectionKey)
    }

    static func loadFavorites() -> [WidgetFavoriteStop] {
        guard let data = defaults?.data(forKey: favoritesKey) else {
            return []
        }

        return (try? JSONDecoder().decode(
            [WidgetFavoriteStop].self,
            from: data
        )) ?? []
    }

    static func saveFavorites(_ favorites: [WidgetFavoriteStop]) {
        guard let data = try? JSONEncoder().encode(favorites) else {
            return
        }

        defaults?.set(data, forKey: favoritesKey)
    }
}