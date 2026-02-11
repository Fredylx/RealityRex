//
//  RealityKitView.swift
//  RealityRex
//
//  Created by Fredy Humberto Lopez on 4/4/23.
//

import SwiftUI
import Foundation
import RealityKit
import ARKit

/// A SwiftUI wrapper for RealityKit's ARView with coaching, UI overlay, and custom content.
struct RealityKitView: UIViewRepresentable {
    @Binding var arViewRef: ARView?
    @Binding var placementEnabled: Bool
    let appState: AppState
    
    /// Creates and configures the ARView.
    func makeUIView(context: Context) -> ARView {
        let startTime = CFAbsoluteTimeGetCurrent()
        DebugLog.log("ARView makeUIView", category: "AR")
        let arView = ARView(frame: .zero)
        arViewRef = arView // 💡 Assign to binding
        
        // Configure the AR session
        let config = context.coordinator.sessionManager.configureSession(for: arView, simplified: true)
        context.coordinator.configure(arView: arView, configuration: config)
        context.coordinator.schedulePlacementEnablement(binding: $placementEnabled)
        context.coordinator.scheduleConfigUpgrade()
        context.coordinator.prewarmHaptics()
        DebugLog.log("ARView makeUIView duration: \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - startTime))s", category: "AR")
        
        // Add custom content views
        addRexView(to: arView, context: context)
        addCoachingOverlay(to: arView)
        addClearButton(to: arView, context: context)
        
        return arView
    }

    /// Required by UIViewRepresentable, not used in this implementation.
    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        DebugLog.log("ARView dismantleUIView", category: "AR")
        uiView.session.pause()
        uiView.scene.anchors.removeAll()
        coordinator.teardown()
    }

    /// Provides a coordinator for bridging UIKit target actions.
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - AR Session Configuration

    /// Sets up horizontal plane detection and disables debug visuals for a clean experience.
    @discardableResult
    static func defaultConfiguration(simplified: Bool = false) -> ARWorldTrackingConfiguration {
        ARSessionManager.defaultConfiguration(simplified: simplified)
    }

    // MARK: - UI Overlays

    /// Adds the custom RexView for handling AR content and gesture interaction.
    private func addRexView(to arView: ARView, context: Context) {
        let rexView = RexView(arView: arView, appState: appState)
        context.coordinator.rexView = rexView
        rexView.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(rexView)
        constrain(rexView, to: arView)
    }

    /// Adds Apple's ARCoachingOverlayView to help users scan and anchor to horizontal surfaces.
    private func addCoachingOverlay(to arView: ARView) {
        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.goal = .horizontalPlane
        coaching.activatesAutomatically = true
        coaching.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coaching)
        constrain(coaching, to: arView)
    }

    /// Adds a floating "Clear All" button to remove all AR content.
    private func addClearButton(to arView: ARView, context: Context) {
        let button = UIButton(type: .system)
        button.setTitle("Clear All", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        button.layer.cornerRadius = 10
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(context.coordinator, action: #selector(Coordinator.clearAllTapped), for: .touchUpInside)

        arView.addSubview(button)

        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: arView.trailingAnchor, constant: -20),
            button.bottomAnchor.constraint(equalTo: arView.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            button.widthAnchor.constraint(equalToConstant: 100),
            button.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    // MARK: - Layout Helper

    /// Pins a view to all edges of its container using Auto Layout.
    private func constrain(_ view: UIView, to container: UIView) {
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    // MARK: - Coordinator

    /// Coordinator handles UIKit-style button tap inside SwiftUI context.
    class Coordinator {
        private weak var arView: ARView?
        let sessionManager = ARSessionManager()
        weak var rexView: RexView?
        private var configuration: ARWorldTrackingConfiguration?
        private var resetObserver: NSObjectProtocol?
        private var firstUpdateLogged = false
        private var enablePlacementWorkItem: DispatchWorkItem?
        private var upgradeConfigWorkItem: DispatchWorkItem?

        func configure(arView: ARView, configuration: ARWorldTrackingConfiguration) {
            self.arView = arView
            self.configuration = configuration
            DebugLog.log("Coordinator configured", category: "AR")
            subscribeToFirstFrame()
            resetObserver = NotificationCenter.default.addObserver(
                forName: .resetARSession,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.resetSession()
            }
        }

        func teardown() {
            if let resetObserver = resetObserver {
                NotificationCenter.default.removeObserver(resetObserver)
            }
            resetObserver = nil
            arView = nil
            configuration = nil
            enablePlacementWorkItem?.cancel()
            upgradeConfigWorkItem?.cancel()
            DebugLog.log("Coordinator teardown", category: "AR")
        }

        private func resetSession() {
            guard let arView = arView,
                  let configuration = configuration else { return }
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            NotificationCenter.default.post(name: .clearAllDinos, object: nil)
            DebugLog.log("AR session reset", category: "AR")
        }

        /// Triggers the notification to clear all dinos and gives haptic feedback.
        @objc func clearAllTapped() {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            NotificationCenter.default.post(name: .clearAllDinos, object: nil)
            DebugLog.log("Clear all tapped", category: "AR")
        }

        func schedulePlacementEnablement(binding: Binding<Bool>, delay: TimeInterval = ARConstants.placementEnableDelay) {
            binding.wrappedValue = false
            rexView?.setExternalPlacementEnabled(false)
            enablePlacementWorkItem?.cancel()
            let item = DispatchWorkItem {
                binding.wrappedValue = true
                self.rexView?.setExternalPlacementEnabled(true)
                DebugLog.log("Placement enabled after warm-up delay", category: "AR")
            }
            enablePlacementWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }

        func scheduleConfigUpgrade(delay: TimeInterval = ARConstants.configUpgradeDelay) {
            upgradeConfigWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, let arView = self.arView else { return }
                let upgraded = ARSessionManager.defaultConfiguration(simplified: false)
                arView.session.run(upgraded)
                self.configuration = upgraded
                DebugLog.log("AR session upgraded to full config", category: "AR")
            }
            upgradeConfigWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }

        func prewarmHaptics() {
            // Hop to the main actor because Haptics.shared and prewarm() are @MainActor-isolated
            Task { @MainActor in
                Haptics.shared.prewarm()
            }
        }

        private func subscribeToFirstFrame() {
            guard let arView = arView else { return }
            _ = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
                guard let self = self, !self.firstUpdateLogged else { return }
                self.firstUpdateLogged = true
                DebugLog.log("First Scene.Update frame", category: "AR")
            }
        }
    }
}
