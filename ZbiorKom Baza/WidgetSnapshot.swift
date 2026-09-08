//
//  WidgetConstants.swift
//  ZbiorKom Baza
//
//  Created by Jan Doniec on 08/09/2026.
//



import Foundation

enum WidgetConstants {
    static let appGroup = "group.pl.jandoniec.zbiorkom"
    static let widgetKind = "ZbiorKomDepartures"
    static let fileName = "departures.json"
}

struct WidgetDeparture: Codable, Identifiable {
    let id: String
    let line: String
    let destination: String
    let date: Date
    let type: String
    let platform: String
}

struct WidgetSnapshot: Codable {
    let stopName: String
    let updatedAt: Date
    let departures: [WidgetDeparture]
}

enum WidgetSnapshotStore {
    static func fileURL() -> URL? {
        FileManager.default
            .containerURL(
                forSecurityApplicationGroupIdentifier: WidgetConstants.appGroup
            )?
            .appendingPathComponent(WidgetConstants.fileName)
    }

    static func save(_ snapshot: WidgetSnapshot) throws {
        guard let url = fileURL() else {
            print("WIDGET: App Group container unavailable")
            throw CocoaError(.fileNoSuchFile)
        }

        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)

        print("WIDGET: zapisano \(data.count) bajtów")
        print("WIDGET: \(url.path)")
    }

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL() else {
            print("WIDGET: brak App Group container")
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            print("WIDGET: brak pliku \(url.path)")
            return nil
        }

        do {
            let snapshot = try JSONDecoder().decode(
                WidgetSnapshot.self,
                from: data
            )

            print("WIDGET: odczytano \(snapshot.departures.count) odjazdów")
            return snapshot
        } catch {
            print("WIDGET: JSON decode error:", error)
            return nil
        }
    }
}

