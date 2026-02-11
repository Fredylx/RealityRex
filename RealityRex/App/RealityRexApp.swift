//
//  RealityRexApp.swift
//  RealityRex
//
//  Created by Fredy Humberto Lopez on 4/4/23.
//

import SwiftUI

@main
struct RealityRexApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .onAppear {
                    DebugLog.log("App launched", category: "App")
                }
                .environmentObject(appState)
        }
    }
}
