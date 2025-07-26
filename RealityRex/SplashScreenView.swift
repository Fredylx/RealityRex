//
//  SplashScreenView.swift
//  RealityRex
//
//  Created by Fredy lopez on 7/24/25.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var logoOpacity = 0.0

    var body: some View {
        if isActive {
            MainARView() // ✅ use the view that contains the overlay + ARView
        } else {
            ZStack {
                Color.green
                    .edgesIgnoringSafeArea(.all)

                Text("RealityRex")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(logoOpacity)
            }
            .onAppear {
                withAnimation(.easeIn(duration: 0.8)) {
                    logoOpacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        isActive = true
                    }
                }
            }
        }
    }
}
