//
//  ContentView.swift
//  ZbiorKom Baza
//
//  Created by Jan Doniec on 08/09/2026.
//


import SwiftUI
import WidgetKit

struct ContentView: View {
    @ObservedObject var model: GTFSDownloader

    @Environment(\.openWindow) private var openWindow

    @State private var searchText = ""
    @State private var showingSettings = false

    // MARK: - Search

    private var filteredGroups: [GTFSGroup] {
        let query = GTFSService.normalized(searchText)
        let words = query.split(whereSeparator: \.isWhitespace)

        let matching = model.groups.filter { group in
            guard !words.isEmpty else { return true }

            let name = GTFSService.normalized(group.name)
            return words.allSatisfy { name.contains($0) }
        }

        return matching.sorted { a, b in
            let aFavorite = model.isFavorite(a.id)
            let bFavorite = model.isFavorite(b.id)

            if aFavorite != bFavorite {
                return aFavorite
            }

            return a.name.localizedStandardCompare(b.name)
                == .orderedAscending
        }
    }

    // MARK: - Shared platforms

    private var mainPlatforms: [String] {
        guard let group = model.selectedGroup else {
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

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                TextField(
                    "Szukaj przystanku, np. Bagatela",
                    text: $searchText
                )
                .textFieldStyle(.roundedBorder)
                .padding()

                if filteredGroups.isEmpty {
                    ContentUnavailableView(
                        "Nie znaleziono przystanku",
                        systemImage: "magnifyingglass",
                        description: Text("Spróbuj wpisać krótszą nazwę.")
                    )
                } else {
                    List(filteredGroups) { group in
                        HStack(spacing: 8) {
                            Button {
                                model.selectGroup(group.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(group.name)

                                        Text(
                                            "\(platformCount(group)) słupków"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if model.selectedGroupID == group.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                model.toggleFavorite(group.id)
                            } label: {
                                Image(
                                    systemName: model.isFavorite(group.id)
                                        ? "star.fill"
                                        : "star"
                                )
                                .foregroundStyle(
                                    model.isFavorite(group.id)
                                        ? .yellow
                                        : .secondary
                                )
                            }
                            .buttonStyle(.borderless)
                            .help(
                                model.isFavorite(group.id)
                                    ? "Usuń z ulubionych"
                                    : "Dodaj do ulubionych"
                            )
                        }
                    }
                }
            }
            .navigationTitle("Przystanki")
            .frame(minWidth: 260)

        } detail: {
            VStack(alignment: .leading, spacing: 16) {
                header

                if model.isDownloading {
                    ProgressView()
                }

                Text(model.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if model.selectedGroup != nil {
                    Picker(
                        "Słupek",
                        selection: Binding(
                            get: { model.selectedPlatformID },
                            set: { model.selectPlatform($0) }
                        )
                    ) {
                        Text("Wszystkie słupki")
                            .tag(String?.none)

                        ForEach(mainPlatforms, id: \.self) { platform in
                            Text(platform)
                                .tag(Optional(platform))
                        }
                    }
                    .frame(maxWidth: 300, alignment: .leading)
                }

                Divider()

                HStack {
                    Text("Linia")
                        .frame(width: 65, alignment: .leading)

                    Text("Kierunek")

                    Spacer()

                    Text("Odjazd")
                        .frame(width: 105, alignment: .trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if model.departures.isEmpty {
                    ContentUnavailableView(
                        "Brak odjazdów",
                        systemImage: "tram",
                        description: Text(
                            "Wybierz przystanek lub sprawdź, czy rozkład obejmuje dzisiejszy dzień."
                        )
                    )
                } else {
                    List(model.departures) { departure in
                        HStack(spacing: 12) {
                            Text(departure.line)
                                .font(.headline)
                                .frame(width: 65, alignment: .leading)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(
                                    departure.destination.isEmpty
                                        ? "Kierunek nieznany"
                                        : departure.destination
                                )
                                .lineLimit(1)

                                Text(
                                    "\(departure.kind == .tram ? "Tramwaj" : "Autobus") • \(WidgetPlatform.number(from: departure.stopCode))"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 3) {
                                Text(clock(departure.date))
                                    .font(.headline)

                                Text(countdown(to: departure.date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 105, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }

                Spacer(minLength: 0)

                HStack {
                    Text("ZbiorKom Baza")

                    Spacer()

                    Text("Odliczanie co 60 s")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(minWidth: 550, minHeight: 400)
        }
        .sheet(isPresented: $showingSettings) {
            ZbiorKomSettingsView(model: model)
        }
        .task {
            await model.start()
        }
        .task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    break
                }

                model.refreshDepartures()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    model.selectedGroup?.name
                        ?? "Wybierz przystanek"
                )
                .font(.largeTitle)
                .bold()

                Text("Autobusy i tramwaje")
                    .foregroundStyle(.secondary)
            }

            if let group = model.selectedGroup {
                Button {
                    model.toggleFavorite(group.id)
                } label: {
                    Image(
                        systemName: model.isFavorite(group.id)
                            ? "star.fill"
                            : "star"
                    )
                }
                .help(
                    model.isFavorite(group.id)
                        ? "Usuń z ulubionych"
                        : "Dodaj do ulubionych"
                )
            }

            Spacer()

            // Osobna tablica desktopowa.
            #if os(macOS)
            Button {
                openWindow(id: "desktop-board")
            } label: {
                Label("Tablica", systemImage: "display")
            }
            .help("Otwórz tablicę w osobnym oknie")
            #endif

            Button {
                model.refreshDepartures()
            } label: {
                Label("Odśwież", systemImage: "arrow.clockwise")
            }

            Button {
                Task {
                    await model.downloadAll()
                }
            } label: {
                Label(
                    "Aktualizuj rozkłady",
                    systemImage: "arrow.down.circle"
                )
            }
            .disabled(model.isDownloading)

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15))
            }
            .buttonStyle(.borderless)
            .help("Ustawienia")
            .accessibilityLabel("Ustawienia")
        }
    }

    // MARK: - Helpers

    private func platformCount(_ group: GTFSGroup) -> Int {
        Set(
            group.stops.map {
                WidgetPlatform.number(from: $0.code)
            }
        ).count
    }

    private func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.timeZone = TimeZone(identifier: "Europe/Warsaw")
        formatter.dateFormat = "HH:mm"

        return formatter.string(from: date)
    }

    private func countdown(to date: Date) -> String {
        let seconds = date.timeIntervalSince(model.now)
        let minutes = max(0, Int(ceil(seconds / 60)))

        return minutes == 0
            ? "teraz"
            : "za \(minutes) min"
    }
}

// MARK: - Settings

private struct ZbiorKomSettingsView: View {
    @ObservedObject var model: GTFSDownloader

    @Environment(\.dismiss) private var dismiss

    @State private var selectedStyle: WidgetVisualStyle =
        WidgetStyleStore.loadStyle()

    @State private var fullColorConfirmed =
        WidgetStyleStore.isFullColorConfirmed()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Ustawienia")
                    .font(.title2)
                    .bold()

                Spacer()

                Button("Gotowe") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 20)

            Form {
                // MARK: Widget stop

                Section {
                    if model.widgetFavoriteGroups.isEmpty {
                        Text(
                            "Dodaj przystanek do ulubionych, aby wybrać go dla widżetu."
                        )
                        .foregroundStyle(.secondary)

                    } else {
                        Picker(
                            "Przystanek",
                            selection: Binding(
                                get: {
                                    model.widgetSelection?.groupID
                                },
                                set: {
                                    model.selectWidgetGroup($0)
                                }
                            )
                        ) {
                            Text("Wybierz przystanek")
                                .tag(String?.none)

                            ForEach(model.widgetFavoriteGroups) { group in
                                Text(group.name)
                                    .tag(Optional(group.id))
                            }
                        }

                        Picker(
                            "Słupek",
                            selection: Binding(
                                get: {
                                    model.widgetSelection?.platformCode
                                },
                                set: {
                                    model.selectWidgetPlatform($0)
                                }
                            )
                        ) {
                            Text("Wszystkie słupki")
                                .tag(String?.none)

                            ForEach(
                                model.widgetPlatforms,
                                id: \.self
                            ) { platform in
                                Text(platform)
                                    .tag(Optional(platform))
                            }
                        }
                        .disabled(model.widgetSelection == nil)
                    }

                    Text(
                        "Widżet pokazuje odjazdy z wybranego ulubionego przystanku i słupka. Autobusy i tramwaje są połączone w jedną tablicę. Zmiana przystanku w głównym oknie nie zmienia widżetu."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                } header: {
                    Label(
                        "Przystanek widżetu",
                        systemImage: "mappin"
                    )
                }

                // MARK: Widget appearance

                Section {
                    Picker("Styl", selection: $selectedStyle) {
                        ForEach(
                            WidgetVisualStyle.allCases,
                            id: \.rawValue
                        ) { style in
                            Text(style.title)
                                .tag(style)
                                .disabled(
                                    style == .krakowBoard
                                    && !fullColorConfirmed
                                )
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle(
                        "Ustawiłem przygaszanie widżetów na „Nigdy”",
                        isOn: $fullColorConfirmed
                    )

                    Text(
                        "Krakowska tablica jest dostępna po potwierdzeniu tego ustawienia. ZbiorKom nie może odczytać ani zmienić systemowego przygaszania widżetów."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text(
                        "Ustawienia systemowe → Biurko i Dock → Widżety → Przygaszaj widżety na biurku → Nigdy"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                } header: {
                    Label(
                        "Wygląd widżetu",
                        systemImage: "square.grid.2x2"
                    )
                }

                // MARK: Data

                Section {
                    HStack {
                        Text("Źródło danych")

                        Spacer()

                        Text("ZTP Kraków")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Rodzaj odjazdów")

                        Spacer()

                        Text("Planowane")
                            .foregroundStyle(.secondary)
                    }

                } header: {
                    Label("Dane", systemImage: "tram")
                }
            }
            .formStyle(.grouped)
        }
        .padding(24)
        .frame(width: 520, height: 540)
        .onChange(of: selectedStyle) { _, newValue in
            if newValue == .krakowBoard && !fullColorConfirmed {
                selectedStyle = .standard
                return
            }

            WidgetStyleStore.saveStyle(newValue)
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onChange(of: fullColorConfirmed) { _, confirmed in
            WidgetStyleStore.setFullColorConfirmed(confirmed)

            if !confirmed && selectedStyle == .krakowBoard {
                selectedStyle = .standard
                WidgetStyleStore.saveStyle(.standard)
            }

            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
