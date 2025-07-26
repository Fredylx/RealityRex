//
//  MainArView.swift
//  RealityRex
//
//  Created by Fredy lopez on 7/25/25.
//

import SwiftUI
import RealityKit

/// The main AR container view that layers the RealityKit scene with onboarding instructions.
struct MainARView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var arViewRef: ARView?

    var body: some View {
        ZStack {
            RealityKitView(arViewRef: $arViewRef)
                .ignoresSafeArea()

            InstructionOverlayView()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                arViewRef?.session.pause()
            }
        }
    }
}


/// Displays initial user guidance steps over the AR experience.
struct InstructionOverlayView: View {
    @State private var visible = true

    var body: some View {
        Group {
            if visible {
                instructionContainer
                    .onAppear(perform: hideAfterDelay)
                    .transition(.opacity)
                    .background(Color.black.opacity(0.001)) // ⬅️ passthrough
            }
        }
    }

    /// Combined instruction UI
    private var instructionContainer: some View {
        VStack(spacing: 16) {
            Spacer()

            instructionBlock(step: "1", text: "Scan the room")
            instructionBlock(step: "2", text: "Tap to place T-Rex")
            instructionBlock(step: "3", text: "Tap and hold to delete")

            Spacer()
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut, value: visible)
    }

    /// Instruction bubble UI
    private func instructionBlock(step: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(step)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.black)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.black.opacity(0.75))
        .cornerRadius(12)
    }

    /// Auto-dismiss the overlay after 3 seconds
    private func hideAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            withAnimation {
                visible = false
            }
        }
    }
}
