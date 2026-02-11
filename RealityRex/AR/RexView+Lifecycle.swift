//
//  RexView+Lifecycle.swift
//  RealityRex
//

import Foundation
import RealityKit

extension RexView {
    func subscribeToSceneUpdates() {
        guard let arView = arView else { return }
        updateCancellable = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] delta in
            self?.dinosaurs.forEach { $0.update(deltaTime: delta.deltaTime) }
        }
        DebugLog.log("Subscribed to SceneEvents.Update", category: "RexView")
    }

    @objc func clearAllDinos() {
        dinosaurs.forEach { $0.anchor?.removeFromParent() }
        dinosaurs.removeAll()
        autoPlacedRex?.anchor?.removeFromParent()
        autoPlacedRex = nil
        notifyCountChanged()
        DebugLog.log("Cleared all dinos", category: "RexView")
    }

    func warmupIfPossible() {
        guard !didWarmup, RexData.shared.isReady, let arView = arView else { return }
        didWarmup = true
        DebugLog.log("Warmup started", category: "RexView")

        let anchor = AnchorEntity(world: SIMD3<Float>(0, -10, 0))
        let rex = RexObject(rexData: rexData, anchor: anchor)
        rex.bodyFrames.forEach { anchor.addChild($0) }
        rex.resetForPlacement()
        rex.bodyFrames.forEach { $0.isEnabled = false }
        prewarmedRex = rex
        arView.scene.addAnchor(anchor)
        DebugLog.log("Warmup finished (prewarmed rex ready)", category: "RexView")
    }
}

