//
//  InstructionOverlayView.swift
//  RealityRex
//
//  Created by Fredy lopez on 7/25/25.
//

import SwiftUI

struct InstructionOverlayView: View {
    let onFinish: () -> Void
    @State private var visible = true

    var body: some View {
        if visible {
            VStack {
                HStack {
                    Spacer()
                    instructionsCard
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
                Spacer()
            }
            .background(Color.black.opacity(0.001)) // Non-blocking touch passthrough
            .onAppear {
                DebugLog.log("InstructionOverlayView appeared", category: "UI")
                scheduleDismiss()
            }
        }
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Steps")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            stepRow(step: "1", text: "Scan the room")
            stepRow(step: "2", text: "Tap to place")
            stepRow(step: "3", text: "Double-tap a dino to delete")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.75))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
    }

    private func stepRow(step: String, text: String) -> some View {
        HStack(spacing: 10) {
            Text(step)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Color.black)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private func scheduleDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            withAnimation {
                visible = false
            }
            DebugLog.log("InstructionOverlayView finished", category: "UI")
            onFinish()
        }
    }
}
