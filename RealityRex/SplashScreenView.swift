//
//  SplashScreenView.swift
//  RealityRex
//
//  Created by Fredy lopez on 7/24/25.
//

import SwiftUI

/// Intro splash screen that fades in the app title, then launches the main AR experience.
struct SplashScreenView: View {
    @State private var showMainAR = false
    @State private var logoOpacity = 0.0

    var body: some View {
        Group {
            if showMainAR {
                MainARView()
            } else {
                splashContent
            }
        }
        .onAppear(perform: runSplashSequence)
    }

    private var splashContent: some View {
        ZStack {
            Color.green.ignoresSafeArea()

            Text("RealityRex")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .opacity(logoOpacity)
        }
    }

    private func runSplashSequence() {
        withAnimation(.easeIn(duration: 0.8)) {
            logoOpacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showMainAR = true
            }
        }
    }
}
