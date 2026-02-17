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
    @State private var showPrivacyPolicy = false
    @EnvironmentObject private var appState: AppState

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
        .onChange(of: appState.isRexDataReady) { ready in
            guard ready else { return }
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

            VStack {
                Spacer()
                    .frame(height: 260)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.0)
                Text("Loading dino...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.top, 6)
            }

            VStack {
                Spacer()
                Button("Privacy Policy") {
                    showPrivacyPolicy = true
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }

    private func runSplashSequence() {
        DebugLog.log("Splash screen appeared", category: "UI")
        Task {
            await MainActor.run { DebugLog.log("Prewarm started (on main)", category: "RexData") }
            await RexData.shared.prewarm(appState: appState)
            DebugLog.log("Prewarm finished", category: "RexData")
        }

        prewarmTimeoutWorkItem?.cancel()
        let timeoutItem = DispatchWorkItem {
            if !RexData.shared.isReady {
                DebugLog.log("Warning: RexData prewarm taking longer than 6s", category: "RexData")
            }
        }
        prewarmTimeoutWorkItem = timeoutItem
        DispatchQueue.main.asyncAfter(deadline: .now() + ARConstants.prewarmWarnTimeout, execute: timeoutItem)
        withAnimation(.easeIn(duration: 0.8)) {
            logoOpacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + ARConstants.splashToMainDelay) {
            withAnimation {
                stage = .main
            }
            DebugLog.log("Transitioning to MainARView (post splash)", category: "UI")
        }
    }
}
