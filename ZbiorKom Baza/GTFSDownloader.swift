//
//  GTFSDownloader.swift
//  ZbiorKom Baza
//
//  Created by Jan Doniec on 08/09/2026.
//



import Foundation
import Combine
import WidgetKit

@MainActor
final class GTFSDownloader: ObservableObject {
    @Published var isDownloading = false
    @Published var status = "Ładowanie danych..."
    @Published var groups: [GTFSGroup] = []
    @Published var selectedGroupID: String?
    @Published var selectedPlatformID: String?
    @Published var departures: [GTFSDeparture] = []
    @Published var now = Date()
    @Published var loadedKinds: [GTFSKind] = []

    @Published private(set) var favoriteGroupIDs: Set<String> = []
    @Published private(set) var widgetSelection: WidgetStopSelection?

    private let service = GTFSService()
    private var refreshTask: Task<Void, Never>?
    private var widgetTask: Task<Void, Never>?

    private let favoritesKey = "favoriteGroupIDs"

    init() {
        favoriteGroupIDs = Set(
            UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        )

        widgetSelection = WidgetStopStore.loadSelection()
    }

    // MARK: - Selected stops

    var selectedGroup: GTFSGroup? {
        groups.first { $0.id == selectedGroupID }
    }

    var widgetGroup: GTFSGroup? {
        guard let id = widgetSelection?.groupID else {
            return nil
        }

        return groups.first { $0.id == id }
    }

    var widgetFavoriteGroups: [GTFSGroup] {
        groups
            .filter { favoriteGroupIDs.contains($0.id) }
            .sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    var widgetPlatforms: [String] {
        guard let group = widgetGroup else {
            return []
        }

        return Array(
            Set(
                group.stops
                    .map { WidgetPlatform.number(from: $0.code) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()
    }

    // MARK: - Favorites

    func isFavorite(_ id: String) -> Bool {
        favoriteGroupIDs.contains(id)
    }

    func toggleFavorite(_ id: String) {
        if favoriteGroupIDs.contains(id) {
            favoriteGroupIDs.remove(id)
        } else {
            favoriteGroupIDs.insert(id)
        }

        UserDefaults.standard.set(
            favoriteGroupIDs.sorted(),
            forKey: favoritesKey
        )

        synchronizeWidgetSelection()
    }

    // MARK: - Widget selection

    func selectWidgetGroup(_ id: String?) {
        guard let id,
              favoriteGroupIDs.contains(id),
              groups.contains(where: { $0.id == id }) else {
            widgetSelection = nil
            WidgetStopStore.saveSelection(nil)
            clearWidgetSnapshot()
            return
        }

        widgetSelection = WidgetStopSelection(
            groupID: id,
            platformCode: nil
        )

        WidgetStopStore.saveSelection(widgetSelection)
        refreshWidget()
    }

    func selectWidgetPlatform(_ code: String?) {
        guard let selection = widgetSelection else {
            return
        }

        let validCode: String?

        if let code, widgetPlatforms.contains(code) {
            validCode = code
        } else {
            validCode = nil
        }

        widgetSelection = WidgetStopSelection(
            groupID: selection.groupID,
            platformCode: validCode
        )

        WidgetStopStore.saveSelection(widgetSelection)
        refreshWidget()
    }

    private func synchronizeWidgetSelection() {
        let favorites = widgetFavoriteGroups

        WidgetStopStore.saveFavorites(
            favorites.map { group in
                WidgetFavoriteStop(
                    id: group.id,
                    name: group.name,
                    platforms: Array(
                        Set(
                            group.stops
                                .map {
                                    WidgetPlatform.number(from: $0.code)
                                }
                                .filter { !$0.isEmpty }
                        )
                    ).sorted()
                )
            }
        )

        guard !favorites.isEmpty else {
            widgetSelection = nil
            WidgetStopStore.saveSelection(nil)
            clearWidgetSnapshot()
            return
        }

        if let selection = widgetSelection,
           let group = favorites.first(where: { $0.id == selection.groupID }) {

            let available = Set(
                group.stops.map {
                    WidgetPlatform.number(from: $0.code)
                }
            )

            if let code = selection.platformCode,
               !available.contains(code) {
                widgetSelection = WidgetStopSelection(
                    groupID: selection.groupID,
                    platformCode: nil
                )
            }

        } else {
            // Pierwszy ulubiony staje się domyślnym dla widżetu.
            widgetSelection = WidgetStopSelection(
                groupID: favorites[0].id,
                platformCode: nil
            )
        }

        WidgetStopStore.saveSelection(widgetSelection)
        refreshWidget()
    }

    // MARK: - Loading

    func start() async {
        guard !isDownloading else { return }

        isDownloading = true
        status = "Wczytywanie zapisanych rozkładów..."

        let errors = await service.loadCached()
        await publishData()

        if !errors.isEmpty {
            status = errors.joined(separator: "\n")
        } else if !loadedKinds.isEmpty {
            status = "Wczytano zapisane rozkłady."
        }

        isDownloading = false

        if loadedKinds.count < GTFSKind.allCases.count {
            await downloadMissing()
        }
    }

    func downloadAll() async {
        guard !isDownloading else { return }

        isDownloading = true
        var errors: [String] = []

        for kind in GTFSKind.allCases {
            status = "Pobieranie: \(kind.title)..."

            do {
                try await service.download(kind)
                await publishData()
            } catch {
                errors.append("\(kind.title): \(error.localizedDescription)")
            }
        }

        isDownloading = false

        if errors.isEmpty {
            status = "Rozkłady autobusów i tramwajów są aktualne."
        } else {
            status = "Nie udało się pobrać części danych:\n"
                + errors.joined(separator: "\n")
        }
    }

    private func downloadMissing() async {
        guard !isDownloading else { return }

        isDownloading = true
        var errors: [String] = []

        for kind in GTFSKind.allCases where !loadedKinds.contains(kind) {
            status = "Pobieranie: \(kind.title)..."

            do {
                try await service.download(kind)
                await publishData()
            } catch {
                errors.append("\(kind.title): \(error.localizedDescription)")
            }
        }

        isDownloading = false

        status = errors.isEmpty
            ? "Dane gotowe."
            : errors.joined(separator: "\n")
    }

    private func publishData() async {
        groups = await service.groups()
        loadedKinds = await service.availableKinds()

        let saved = UserDefaults.standard.string(forKey: "favoriteGroup")

        if selectedGroupID == nil {
            selectedGroupID = saved
        }

        if !groups.contains(where: { $0.id == selectedGroupID }) {
            selectedGroupID = groups.first?.id
            selectedPlatformID = nil
        }

        synchronizeWidgetSelection()
        refreshDepartures()
    }

    // MARK: - Main window

    func selectGroup(_ id: String) {
        guard selectedGroupID != id else { return }

        selectedGroupID = id
        selectedPlatformID = nil

        UserDefaults.standard.set(id, forKey: "favoriteGroup")
        refreshDepartures()
    }

    func selectPlatform(_ id: String?) {
        selectedPlatformID = id
        refreshDepartures()
    }

    func refreshDepartures() {
        refreshTask?.cancel()
        now = Date()

        guard let group = selectedGroup else {
            departures = []
            return
        }

        let groupID = group.id
        let platformID = selectedPlatformID

        // Jeden numer słupka = autobusy + tramwaje.
        let selectedStops = group.stops.filter { stop in
            guard let platformID else { return true }

            return WidgetPlatform.number(from: stop.code) == platformID
        }

        let requestedAt = now

        refreshTask = Task { [weak self] in
            guard let self else { return }

            let result = await service.departures(
                for: selectedStops,
                now: requestedAt
            )

            guard !Task.isCancelled,
                  self.selectedGroupID == groupID,
                  self.selectedPlatformID == platformID else {
                return
            }

            self.departures = result
        }

        // Widżet ma własny wybór, więc odświeżamy go osobno.
        refreshWidget()
    }

    // MARK: - Widget snapshot

    func refreshWidget() {
        widgetTask?.cancel()

        guard let selection = widgetSelection,
              let group = groups.first(where: { $0.id == selection.groupID })
        else {
            return
        }

        let selectedStops = group.stops.filter { stop in
            guard let code = selection.platformCode else {
                return true
            }

            return WidgetPlatform.number(from: stop.code) == code
        }

        let requestedAt = Date()

        widgetTask = Task { [weak self] in
            guard let self else { return }

            // Większy zakres niż lista w głównym oknie.
            let result = await service.departures(
                for: selectedStops,
                now: requestedAt,
                limit: 500
            )

            guard !Task.isCancelled,
                  self.widgetSelection == selection else {
                return
            }

            let snapshot = WidgetSnapshot(
                stopName: group.name,
                updatedAt: requestedAt,
                departures: result.map { departure in
                    WidgetDeparture(
                        id: departure.id,
                        line: departure.line,
                        destination: departure.destination,
                        date: departure.date,
                        type: departure.kind == .tram ? "Tramwaj" : "Autobus",
                        platform: WidgetPlatform.number(
                            from: departure.stopCode
                        )
                    )
                }
            )

            do {
                try WidgetSnapshotStore.save(snapshot)

                WidgetCenter.shared.reloadTimelines(
                    ofKind: WidgetConstants.widgetKind
                )
            } catch {
                print("WIDGET: zapis nieudany:", error)
            }
        }
    }

    private func clearWidgetSnapshot() {
        widgetTask?.cancel()

        if let url = WidgetSnapshotStore.fileURL() {
            try? FileManager.default.removeItem(at: url)
        }

        WidgetCenter.shared.reloadTimelines(
            ofKind: WidgetConstants.widgetKind
        )
    }
}
