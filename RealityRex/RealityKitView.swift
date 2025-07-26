//
//  RealityKitView.swift
//  RealityRex
//
//  Created by Fredy Humberto Lopez on 4/4/23.
//

import SwiftUI
import RealityKit
import ARKit

/// A SwiftUI wrapper for RealityKit's ARView with coaching, UI overlay, and custom content.
struct RealityKitView: UIViewRepresentable {
    @Binding var arViewRef: ARView?
    
    /// Creates and configures the ARView.
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arViewRef = arView // 💡 Assign to binding
        
        // Configure the AR session
        configureSession(for: arView)
        
        // Add custom content views
        addRexView(to: arView)
        addCoachingOverlay(to: arView)
        addClearButton(to: arView, context: context)
        
        return arView
    }

    /// Required by UIViewRepresentable, not used in this implementation.
    func updateUIView(_ uiView: ARView, context: Context) {}

    /// Provides a coordinator for bridging UIKit target actions.
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - AR Session Configuration

    /// Sets up horizontal plane detection and disables debug visuals for a clean experience.
    private func configureSession(for arView: ARView) {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config)
        arView.debugOptions = [] // Production-ready (disable anchor lines & feature points)
    }

    // MARK: - UI Overlays

    /// Adds the custom RexView for handling AR content and gesture interaction.
    private func addRexView(to arView: ARView) {
        let rexView = RexView(arView: arView)
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
        /// Triggers the notification to clear all dinos and gives haptic feedback.
        @objc func clearAllTapped() {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            NotificationCenter.default.post(name: .clearAllDinos, object: nil)
        }
    }
}
