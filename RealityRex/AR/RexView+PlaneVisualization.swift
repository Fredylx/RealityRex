//
//  RexView+PlaneVisualization.swift
//  RealityRex
//

import ARKit
import RealityKit
import UIKit

extension RexView {
    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard !didAutoPlace else { return }
        for anchor in anchors {
            guard let plane = anchor as? ARPlaneAnchor else { continue }
            planeDetectionTimeoutWorkItem?.cancel()
            addOrUpdatePlaneVisual(for: plane)
            if pendingAutoPlacementTransform == nil {
                pendingAutoPlacementTransform = plane.transform
                tryAutoPlaceIfPossible()
            }
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let plane = anchor as? ARPlaneAnchor else { continue }
            addOrUpdatePlaneVisual(for: plane)
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let plane = anchor as? ARPlaneAnchor else { continue }
            if let visual = planeVisuals.removeValue(forKey: plane.identifier) {
                visual.removeFromParent()
            }
            if let anchorEntity = planeAnchors.removeValue(forKey: plane.identifier) {
                anchorEntity.removeFromParent()
            }
        }
    }

    func schedulePlaneDetectionTimeout() {
        planeDetectionTimeoutWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.pendingAutoPlacementTransform == nil {
                DebugLog.log("Warning: no horizontal plane detected after 8s", category: "AR")
            }
        }
        planeDetectionTimeoutWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0, execute: item)
    }

    func addOrUpdatePlaneVisual(for plane: ARPlaneAnchor) {
        guard let arView = arView else { return }
        let size = plane.extent
        let mesh = MeshResource.generatePlane(width: size.x, depth: size.z)
        let material = SimpleMaterial(color: UIColor.green.withAlphaComponent(0.25), isMetallic: false)

        let planeEntity: ModelEntity
        if let existing = planeVisuals[plane.identifier] {
            planeEntity = existing
            planeEntity.model = ModelComponent(mesh: mesh, materials: [material])
        } else {
            planeEntity = ModelEntity(mesh: mesh, materials: [material])
            planeEntity.generateCollisionShapes(recursive: false)
            planeVisuals[plane.identifier] = planeEntity
            let anchorEntity = AnchorEntity(anchor: plane)
            planeAnchors[plane.identifier] = anchorEntity
            arView.scene.addAnchor(anchorEntity)
            anchorEntity.addChild(planeEntity)
        }

        planeEntity.position = SIMD3<Float>(plane.center.x, 0, plane.center.z)
    }
}
