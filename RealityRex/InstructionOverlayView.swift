//
//  InstructionOverlayView.swift
//  RealityRex
//
//  Created by Fredy lopez on 7/25/25.
//

import SwiftUI

struct InstructionOverlayView: View {
    @State private var step = 1
    @State private var visible = true

    var body: some View {
        if visible {
            VStack(spacing: 24) {
                Spacer()

                Group {
                    if step == 1 {
                        instructionBlock(step: "1", text: "Scan the room")
                    } else if step == 2 {
                        instructionBlock(step: "2", text: "Tap to place")
                    } else if step == 3 {
                        instructionBlock(step: "3", text: "Double-tap a dino to delete")
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut, value: step)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.001)) // Non-blocking touch passthrough
            .onAppear {
                advanceSteps()
            }
        }
    }

    func instructionBlock(step: String, text: String) -> some View {
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

    func advanceSteps() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                step = 2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation {
                    step = 3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        visible = false
                    }
                }
            }
        }
    }
}
