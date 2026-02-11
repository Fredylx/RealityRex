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
        appState.showAutoPlacementLoading = true
        appState.showAutoPlacementReady = false
        appState.autoPlacementMessage = "Preparing your first dino..."
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
            self.appState.showAutoPlacementLoading = false
            self.appState.showAutoPlacementReady = true
            self.appState.autoPlacementMessage = "Ready — tap to place!"
            self.autoPlacementReadyWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                self?.appState.showAutoPlacementReady = false
            }
            self.autoPlacementReadyWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + ARConstants.autoPlacementReadyDisplay, execute: item)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + ARConstants.autoPlacementTimeout, execute: item)
    }
}
