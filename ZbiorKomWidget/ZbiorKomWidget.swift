//
//  ZbiorKomWidget.swift
//  ZbiorKomWidget
//
//  Created by Jan Doniec on 08/09/2026.
//


import SwiftUI
import WidgetKit

// MARK: - Timeline

struct DepartureEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct DepartureProvider: TimelineProvider {
    func placeholder(in context: Context) -> DepartureEntry {
        let now = Date()

        return DepartureEntry(
            date: now,
            snapshot: WidgetSnapshot(
                stopName: "Teatr Bagatela",
                updatedAt: now,
                departures: [
                    WidgetDeparture(
                        id: "example-1",
                        line: "4",
                        destination: "Bronowice Małe",
                        date: now.addingTimeInterval(180),
                        type: "Tramwaj",
                        platform: "01"
                    ),
                    WidgetDeparture(
                        id: "example-2",
                        line: "13",
                        destination: "Nowy Bieżanów",
                        date: now.addingTimeInterval(360),
                        type: "Tramwaj",
                        platform: "02"
                    ),
                    WidgetDeparture(
                        id: "example-3",
                        line: "124",
                        destination: "Os. Podwawelskie",
                        date: now.addingTimeInterval(540),
                        type: "Autobus",
                        platform: "03"
                    ),
                    WidgetDeparture(
                        id: "example-4",
                        line: "8",
                        destination: "Borek Fałęcki",
                        date: now.addingTimeInterval(720),
                        type: "Tramwaj",
                        platform: "02"
                    )
                ]
            )
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (DepartureEntry) -> Void
    ) {
        completion(
            DepartureEntry(
                date: Date(),
                snapshot: WidgetSnapshotStore.load()
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<DepartureEntry>) -> Void
    ) {
        let now = Date()

        guard let snapshot = WidgetSnapshotStore.load() else {
            completion(
                Timeline(
                    entries: [
                        DepartureEntry(date: now, snapshot: nil)
                    ],
                    policy: .after(now.addingTimeInterval(5 * 60))
                )
            )
            return
        }

        let futureDepartures = snapshot.departures
            .filter { $0.date >= now }
            .sorted { $0.date < $1.date }

        var entries: [DepartureEntry] = [
            DepartureEntry(date: now, snapshot: snapshot)
        ]

        // Wpisy na momenty kolejnych odjazdów.
        // WidgetKit może wykonać je z opóźnieniem.
        for departure in futureDepartures {
            entries.append(
                DepartureEntry(
                    date: departure.date.addingTimeInterval(1),
                    snapshot: snapshot
                )
            )
        }

        completion(
            Timeline(
                entries: entries,
                policy: .after(now.addingTimeInterval(15 * 60))
            )
        )
    }
}

// MARK: - Root

struct WidgetRootView: View {
    let entry: DepartureEntry

    var body: some View {
        switch WidgetStyleStore.loadStyle() {
        case .standard:
            ZbiorKomWidgetView(entry: entry)

        case .krakowBoard:
            KrakowBoardWidgetView(entry: entry)
        }
    }
}

// MARK: - Standard

struct ZbiorKomWidgetView: View {
    let entry: DepartureEntry

    private var visibleDepartures: [WidgetDeparture] {
        entry.snapshot?.departures
            .filter { $0.date >= entry.date }
            .sorted { $0.date < $1.date } ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let snapshot = entry.snapshot {
                HStack {
                    Text(snapshot.stopName)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "tram.fill")
                        .foregroundStyle(.secondary)
                }

                Divider()

                ForEach(visibleDepartures.prefix(4)) { departure in
                    HStack(spacing: 8) {
                        Text(departure.line)
                            .font(.headline)
                            .frame(width: 36, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(departure.destination)
                                .font(.subheadline)
                                .lineLimit(1)

                            Text("\(departure.type) • \(departure.platform)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(departure.date, style: .time)
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                }

                Spacer(minLength: 0)

                Text("Rozkład planowany")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

            } else {
                Text("ZbiorKom")
                    .font(.headline)

                Text("Otwórz aplikację i wybierz przystanek.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Krakowska tablica

struct KrakowBoardWidgetView: View {
    let entry: DepartureEntry

    @Environment(\.widgetFamily) private var family

    private let amber = Color(
        red: 1.0,
        green: 0.48,
        blue: 0.04
    )

    private let silver = Color(
        red: 0.72,
        green: 0.74,
        blue: 0.75
    )

    private var isLarge: Bool {
        family == .systemLarge
    }

    private var visibleDepartures: [WidgetDeparture] {
        entry.snapshot?.departures
            .filter { $0.date >= entry.date }
            .sorted { $0.date < $1.date } ?? []
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                silverStrip

                boardContent
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
                    .background(Color.black)

                silverStrip
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height
            )
            .background(Color.black)
        }
        .containerBackground(Color.black, for: .widget)
    }

    private var silverStrip: some View {
        Rectangle()
            .fill(silver)
            .frame(height: isLarge ? 20 : 16)
            .frame(maxWidth: .infinity)
    }

    private var boardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let snapshot = entry.snapshot {
                Text(snapshot.stopName)
                    .font(.system(
                        size: isLarge ? 28 : 21,
                        weight: .medium
                    ))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.bottom, isLarge ? 12 : 7)

                columnHeader

                Rectangle()
                    .fill(Color.white.opacity(0.45))
                    .frame(height: 1)
                    .padding(.top, 5)
                    .padding(.bottom, isLarge ? 10 : 6)

                if visibleDepartures.isEmpty {
                    Text("Brak kolejnych odjazdów")
                        .font(.system(
                            size: isLarge ? 18 : 14,
                            design: .monospaced
                        ))
                        .foregroundStyle(amber)
                        .padding(.top, 8)
                } else {
                    VStack(spacing: isLarge ? 8 : 5) {
                        ForEach(
                            visibleDepartures.prefix(isLarge ? 8 : 4)
                        ) { departure in
                            departureRow(departure)
                        }
                    }
                }

                Spacer(minLength: 0)

                // Bez zegara. Tylko informacja o rodzaju danych.
                Text("ROZKŁAD PLANOWANY")
                    .font(.system(
                        size: isLarge ? 10 : 9,
                        design: .monospaced
                    ))
                    .foregroundStyle(amber.opacity(0.8))

            } else {
                Text("ZbiorKom")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)

                Text("Brak danych")
                    .font(.system(size: 20, design: .monospaced))
                    .foregroundStyle(amber)
                    .padding(.top, 12)

                Text("Otwórz aplikację i wybierz przystanek.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 4)

                Spacer()
            }
        }
        .padding(.horizontal, isLarge ? 20 : 14)
        .padding(.vertical, isLarge ? 16 : 10)
    }

    private var columnHeader: some View {
        HStack(spacing: 8) {
            Text("Linia")
                .frame(
                    width: isLarge ? 55 : 42,
                    alignment: .leading
                )

            Text("Przystanek docelowy")
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )

            Text("Odjazd")
                .frame(
                    width: isLarge ? 80 : 65,
                    alignment: .trailing
                )
        }
        .font(.system(size: isLarge ? 12 : 10))
        .foregroundStyle(.white.opacity(0.9))
    }

    private func departureRow(
        _ departure: WidgetDeparture
    ) -> some View {
        HStack(spacing: 8) {
            Text(departure.line)
                .frame(
                    width: isLarge ? 55 : 42,
                    alignment: .leading
                )

            Text(departure.destination)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(departure.date, style: .time)
                .frame(
                    width: isLarge ? 80 : 65,
                    alignment: .trailing
                )
        }
        .font(.system(
            size: isLarge ? 20 : 15,
            weight: .medium,
            design: .monospaced
        ))
        .foregroundStyle(amber)
    }
}

// MARK: - Widget

struct ZbiorKomWidget: Widget {
    let kind = WidgetConstants.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: DepartureProvider()
        ) { entry in
            WidgetRootView(entry: entry)
        }
        .configurationDisplayName("ZbiorKom")
        .description("Najbliższe odjazdy z wybranego przystanku.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
