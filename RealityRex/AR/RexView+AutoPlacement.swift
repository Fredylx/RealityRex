//
//  RexView+AutoPlacement.swift
//  RealityRex
//

import RealityKit
import Foundation

extension RexView {
    // MARK: - Auto Placement
    func tryAutoPlaceIfPossible() {
        guard !didAutoPlace,
              !isAutoPlacing,
              RexData.shared.isReady,
              let arView = arView,
              let transform = pendingAutoPlacementTransform else { return }

        isAutoPlacing = true
        NotificationCenter.default.post(name: .autoPlacementStarted, object: nil)
        NotificationCenter.default.post(
            name: .autoPlacementStatus,
            object: nil,
            userInfo: ["text": "Preparing your first dino..."]
        )
        scheduleAutoPlacementTimeout()

        let anchor = AnchorEntity(world: transform)
        if let grass = makeGrassPlane() {
            grass.position = SIMD3<Float>(0, -0.01, 0)
            anchor.addChild(grass)
        }

        let rex: RexObject
        if let cached = prewarmedRex {
            rex = cached
            rex.resetForPlacement()
            rex.anchor?.setTransformMatrix(transform, relativeTo: nil)
            DebugLog.log("Auto placement using prewarmed rex", category: "RexView")
        } else {
            rex = RexObject(rexData: rexData, anchor: anchor)
            rex.bodyFrames.forEach { anchor.addChild($0) }
        }
        rex.setVisible(true)

        if rex.anchor?.scene == nil {
            arView.scene.addAnchor(anchor)
        }
        autoPlacedRex = rex
        didAutoPlace = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.autoPlacedRex?.anchor?.removeFromParent()
            self.autoPlacedRex = nil
            self.isAutoPlacing = false
            NotificationCenter.default.post(name: .autoPlacementFinished, object: nil)
            NotificationCenter.default.post(
                name: .autoPlacementStatus,
                object: nil,
                userInfo: ["text": "Ready — tap to place!"]
            )
            DebugLog.log("Auto placement finished; user placement enabled", category: "RexView")
        }
    }

    func scheduleAutoPlacementTimeout() {
        autoPlacementTimeoutWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.isAutoPlacing {
                DebugLog.log("Warning: auto placement taking longer than 2s", category: "RexView")
            }
        }
        autoPlacementTimeoutWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: item)
    }
}
