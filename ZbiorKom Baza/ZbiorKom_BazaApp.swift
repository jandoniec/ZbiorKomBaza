//
//  ZbiorKom_BazaApp.swift
//  ZbiorKom Baza
//
//  Created by Jan Doniec on 08/09/2026.
//

import SwiftUI

@main
struct ZbiorKom_BazaApp: App {
    @StateObject private var model = GTFSDownloader()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }

        Window("Tablica", id: "desktop-board") {
            DesktopBoardView(model: model)
        }
        .defaultSize(width: 800, height: 450)
    }
}
