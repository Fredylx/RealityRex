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
    @State private var showInstructions = true
    
    var body: some View {
        ZStack {
            RealityKitView(arViewRef: $arViewRef)
                .ignoresSafeArea()
            
            if showInstructions {
                InstructionOverlayView {
                    showInstructions = false
                }
            }
            
            VStack {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        // Info Button
                        Button(action: {
                            withAnimation {
                                showInstructions = true
                            }
                        }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 80, height: 36)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(10)
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        
                        // Clear All button (if you want to move it here too, otherwise leave it in RealityKitView)
                        // Button("Clear All") { ... }
                    }
                    
                    .padding(.trailing, 16)
                    .padding(.top, 16)
                }
                
                Spacer()
            }
        }
    }
}


/// Displays initial user guidance steps over the AR experience.
struct InstructionOverlayView: View {
    let onFinish: () -> Void
    @State private var visible = true

    var body: some View {
        Group {
            if visible {
                instructionContainer
                    .onAppear(perform: hideAfterDelay)
                    .transition(.opacity)
                    .background(Color.black.opacity(0.001))
            }
        }
    }

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
    }

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

    private func hideAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                visible = false
            }
            onFinish()
        }
    }
}
