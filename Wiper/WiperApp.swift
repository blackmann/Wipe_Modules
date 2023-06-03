//
//  WiperApp.swift
//  Wiper
//
//  Created by De-Great Yartey on 03/06/2023.
//

import SwiftUI

@main
struct WiperApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }.defaultSize(width: 600, height: 400)
    }
}
