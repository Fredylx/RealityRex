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
    @State private var placementMessage: String?
    
    var body: some View {
        ZStack {
            RealityKitView(arViewRef: $arViewRef)
                .ignoresSafeArea()
                .onReceive(NotificationCenter.default.publisher(for: .placementFeedback)) { output in
                    if let message = output.userInfo?["message"] as? String {
                        withAnimation {
                            placementMessage = message
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                placementMessage = nil
                            }
                        }
                    }
                }

            if showInstructions {
                InstructionOverlayView { showInstructions = false }
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

            if let placementMessage {
                VStack {
                    Spacer()
                    Text(placementMessage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
        }
    }
}
