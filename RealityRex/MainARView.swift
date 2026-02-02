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
    @State private var placementEnabled = false
    @State private var showInstructions = true
    @State private var dinoCount = 0
    @State private var showLimitToast = false
    @State private var toastWorkItem: DispatchWorkItem?
    @State private var showLoading = true
    @State private var showLoadingTapHint = false
    @State private var loadingTapWorkItem: DispatchWorkItem?
    @State private var showAutoPlacementLoading = false
    @State private var showAutoPlacementReady = false
    @State private var autoPlacementMessage = "Preparing your first dino..."
    @State private var autoPlacementReadyWorkItem: DispatchWorkItem?
    
    var body: some View {
        ZStack {
            RealityKitView(arViewRef: $arViewRef, placementEnabled: $placementEnabled)
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
                    }
                    
                    .padding(.trailing, 16)
                    .padding(.top, 16)
                }
                
                Spacer()

                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("T-Rex count: \(dinoCount)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Tap to place • Pinch to scale • Rotate to turn")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.bottom, 16)
            }

            if showLimitToast {
                VStack {
                    Spacer()
                    Text("Dino limit reached (14). Remove one to add more.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                        .padding(.bottom, 80)
                }
                .transition(.opacity)
            }

            if showLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    Text("Loading dino...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                .transition(.opacity)
            }

            if showAutoPlacementLoading || showAutoPlacementReady {
                VStack(spacing: 8) {
                    if showAutoPlacementLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.1)
                    }
                    Text(autoPlacementMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                .transition(.opacity)
            }

            if showLoadingTapHint {
                VStack {
                    Spacer()
                    Text("Loading… please wait")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                        .padding(.bottom, 140)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            DebugLog.log("MainARView appeared", category: "UI")
            showLoading = !RexData.shared.isReady
            DebugHangMonitor.shared.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dinoCountChanged)) { notification in
            if let count = notification.object as? Int {
                dinoCount = count
                DebugLog.log("Dino count changed: \(count)", category: "UI")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .rexDataReady)) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                showLoading = false
            }
            DebugLog.log("RexData ready received", category: "UI")
        }
        .onReceive(NotificationCenter.default.publisher(for: .dinoLoadingTap)) { _ in
            loadingTapWorkItem?.cancel()
            showLoadingTapHint = true
            let item = DispatchWorkItem {
                withAnimation(.easeOut(duration: 0.2)) {
                    showLoadingTapHint = false
                }
            }
            loadingTapWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
            DebugLog.log("Loading tap hint shown", category: "UI")
        }
        .onReceive(NotificationCenter.default.publisher(for: .autoPlacementStarted)) { _ in
            withAnimation(.easeIn(duration: 0.2)) {
                showAutoPlacementLoading = true
                showAutoPlacementReady = false
            }
            DebugLog.log("Auto placement loading shown", category: "UI")
        }
        .onReceive(NotificationCenter.default.publisher(for: .autoPlacementFinished)) { _ in
            autoPlacementReadyWorkItem?.cancel()
            showAutoPlacementReady = true
            let item = DispatchWorkItem {
                withAnimation(.easeOut(duration: 0.2)) {
                    showAutoPlacementReady = false
                }
            }
            autoPlacementReadyWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: item)
            withAnimation(.easeOut(duration: 0.2)) {
                showAutoPlacementLoading = false
            }
            DebugLog.log("Auto placement loading hidden", category: "UI")
        }
        .onReceive(NotificationCenter.default.publisher(for: .autoPlacementStatus)) { notification in
            if let info = notification.userInfo,
               let text = info["text"] as? String {
                autoPlacementMessage = text
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dinoLimitReached)) { _ in
            showLimitToast = true
            toastWorkItem?.cancel()
            let item = DispatchWorkItem {
                withAnimation(.easeOut(duration: 0.2)) {
                    showLimitToast = false
                }
            }
            toastWorkItem = item
            withAnimation(.easeIn(duration: 0.2)) {
                showLimitToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: item)
            DebugLog.log("Dino limit toast shown", category: "UI")
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                if let arView = arViewRef {
                    arView.session.run(RealityKitView.defaultConfiguration())
                    DebugLog.log("Scene phase active: session run", category: "AR")
                }
            case .inactive, .background:
                arViewRef?.session.pause()
                DebugLog.log("Scene phase inactive/background: session paused", category: "AR")
            @unknown default:
                break
            }
        }
    }
}
