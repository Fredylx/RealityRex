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
        
        let arSession = arView.session
        let worldTrackingConfiguration = ARWorldTrackingConfiguration()
        worldTrackingConfiguration.planeDetection = [.vertical, .horizontal]
        arSession.run(worldTrackingConfiguration)
        arView.debugOptions = [.showAnchorGeometry, .showAnchorOrigins, .showFeaturePoints]
        
        let coachingOverlayView = ARCoachingOverlayView()
        coachingOverlayView.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coachingOverlayView)
        coachingOverlayView.leftAnchor.constraint(equalTo: arView.leftAnchor).isActive = true
        coachingOverlayView.rightAnchor.constraint(equalTo: arView.rightAnchor).isActive = true
        coachingOverlayView.topAnchor.constraint(equalTo: arView.topAnchor).isActive = true
        coachingOverlayView.bottomAnchor.constraint(equalTo: arView.bottomAnchor).isActive = true
        coachingOverlayView.session = arSession
        coachingOverlayView.goal = .horizontalPlane
        
        let rexView = RexView(arView: arView)
        rexView.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(rexView)
        rexView.leftAnchor.constraint(equalTo: arView.leftAnchor).isActive = true
        rexView.rightAnchor.constraint(equalTo: arView.rightAnchor).isActive = true
        rexView.topAnchor.constraint(equalTo: arView.topAnchor).isActive = true
        rexView.bottomAnchor.constraint(equalTo: arView.bottomAnchor).isActive = true
        
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        
    }
    
}
