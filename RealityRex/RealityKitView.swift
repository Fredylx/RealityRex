//
//  RealityKitView.swift
//  RealityRex
//
//  Created by Fredy Humberto Lopez on 4/4/23.
//

import Foundation
import SwiftUI
import RealityKit
import ARKit

struct RealityKitView: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView()
        
        // AR Configuration
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config)
        
        // Debug options
//        arView.debugOptions = [.showAnchorGeometry, .showAnchorOrigins, .showFeaturePoints]

//        arView.debugOptions = []
        #if DEBUG
        arView.debugOptions = [.showAnchorGeometry, .showAnchorOrigins, .showFeaturePoints]
        #else
        arView.debugOptions = []
        #endif


        // RexView for AR object interaction
        let rexView = RexView(arView: arView)
        rexView.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(rexView)
        NSLayoutConstraint.activate([
            rexView.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            rexView.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
            rexView.topAnchor.constraint(equalTo: arView.topAnchor),
            rexView.bottomAnchor.constraint(equalTo: arView.bottomAnchor)
        ])
        
        // Coaching Overlay
        let coachingOverlayView = ARCoachingOverlayView()
        coachingOverlayView.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coachingOverlayView)
        NSLayoutConstraint.activate([
            coachingOverlayView.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            coachingOverlayView.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
            coachingOverlayView.topAnchor.constraint(equalTo: arView.topAnchor),
            coachingOverlayView.bottomAnchor.constraint(equalTo: arView.bottomAnchor)
        ])
        coachingOverlayView.session = arView.session
        coachingOverlayView.goal = .horizontalPlane

        // Clear Button
        let clearButton = UIButton(type: .system)
        clearButton.setTitle("Clear All", for: .normal)
        clearButton.setTitleColor(.white, for: .normal)
        clearButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        clearButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        clearButton.layer.cornerRadius = 10
        clearButton.layer.shadowColor = UIColor.black.cgColor
        clearButton.layer.shadowOpacity = 0.3
        clearButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        clearButton.layer.shadowRadius = 4
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.addTarget(context.coordinator, action: #selector(Coordinator.clearAllTapped), for: .touchUpInside)
        arView.addSubview(clearButton)

        NSLayoutConstraint.activate([
            clearButton.trailingAnchor.constraint(equalTo: arView.trailingAnchor, constant: -20),
//            clearButton.bottomAnchor.constraint(equalTo: arView.bottomAnchor, constant: -40),
            clearButton.bottomAnchor.constraint(equalTo: arView.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            clearButton.widthAnchor.constraint(equalToConstant: 100),
            clearButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        @objc func clearAllTapped() {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            NotificationCenter.default.post(name: .clearAllDinos, object: nil)
        }
    }
}
