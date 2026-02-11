//
//  SplashScreenView.swift
//  RealityRex
//
//  Created by Fredy lopez on 7/24/25.
//

import SwiftUI

/// Intro splash screen that fades in the app title, then launches the main AR experience.
struct SplashScreenView: View {
    private enum Stage {
        case splash
        case main
    }

    @State private var stage: Stage = .splash
    @State private var logoOpacity = 0.0
    @State private var prewarmTimeoutWorkItem: DispatchWorkItem?

    var body: some View {
        Group {
            switch stage {
            case .main:
                MainARView()
            case .splash:
                splashContent
            }
        }
        .onAppear(perform: runSplashSequence)
        .onReceive(NotificationCenter.default.publisher(for: .rexDataReady)) { _ in
            prewarmTimeoutWorkItem?.cancel()
            if stage != .main {
                withAnimation {
                    stage = .main
                }
                DebugLog.log("Transitioning to MainARView (data ready)", category: "UI")
            }
        }
    }

    private var splashContent: some View {
        ZStack {
            Color.green.ignoresSafeArea()

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                )
                .shadow(radius: 12)
                .opacity(logoOpacity)
        }
    }

    private func runSplashSequence() {
        DebugLog.log("Splash screen appeared", category: "UI")
        Task {
            DebugLog.log("Prewarm started (mainThread=\(Thread.isMainThread))", category: "RexData")
            await RexData.shared.prewarm()
            DebugLog.log("Prewarm finished", category: "RexData")
        }

        prewarmTimeoutWorkItem?.cancel()
        let timeoutItem = DispatchWorkItem {
            if !RexData.shared.isReady {
                DebugLog.log("Warning: RexData prewarm taking longer than 6s", category: "RexData")
            }
        }
        prewarmTimeoutWorkItem = timeoutItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: timeoutItem)
        withAnimation(.easeIn(duration: 0.8)) {
            logoOpacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                stage = .main
            }
            DebugLog.log("Transitioning to MainARView (post splash)", category: "UI")
        }
    }
}
