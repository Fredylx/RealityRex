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
            RealityKitView()
                .edgesIgnoringSafeArea(.all)
        } else {
            ZStack {
                Color.black
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
//                    Image("rex_logo")
                    Image(systemName: "tortoise.fill") // 🔁 until logo is ready
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .opacity(logoOpacity)
                        .shadow(radius: 10)

                    Text("RealityRex")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(logoOpacity)
                }
            }
            .onAppear {
                withAnimation(.easeIn(duration: 1.0)) {
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
