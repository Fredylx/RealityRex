//
//  RexView+Placement.swift
//  RealityRex
//

import UIKit
import RealityKit

extension RexView {
    // MARK: - Gesture Setup
    func setupGestureRecognizers() {
        DebugLog.log("Setup gestures", category: "RexView")
        // Gestures disabled for now; tap-to-select and tap-to-place handled in touchesBegan.
    }

    // MARK: - Touch to Place Dino
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let arView = arView else { return }
        guard externalPlacementEnabled else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            DebugLog.log("Touch ignored: placement not yet enabled", category: "RexView")
            return
        }

        guard RexData.shared.isReady else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            loadingTapWorkItem?.cancel()
            appState.showLoadingTapHint = true
            let item = DispatchWorkItem { [weak self] in
                self?.appState.showLoadingTapHint = false
            }
            loadingTapWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + ARConstants.loadingTapHintDuration, execute: item)
            DebugLog.log("Touch ignored: RexData not ready", category: "RexView")
            return
        }
        guard effectiveDinoCount() < maxDinos else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            limitToastWorkItem?.cancel()
            appState.showLimitToast = true
            let item = DispatchWorkItem { [weak self] in
                self?.appState.showLimitToast = false
            }
            limitToastWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + ARConstants.limitToastDuration, execute: item)
            DebugLog.log("Touch ignored: limit reached", category: "RexView")
            return
        }
        guard let point = touches.first?.location(in: arView) else { return }

        let results = arView.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .horizontal)
        guard let result = results.first else {
            DebugLog.log("Raycast failed: no result", category: "RexView")
            return
        }

        let worldPos = SIMD3<Float>(result.worldTransform.columns.3.x,
                                    result.worldTransform.columns.3.y,
                                    result.worldTransform.columns.3.z)

        guard !isOverlap(to: worldPos) else {
            DebugLog.log("Placement overlap prevented", category: "RexView")
            return
        }

        placementGestureStart = CFAbsoluteTimeGetCurrent()

        let anchor = AnchorEntity(world: result.worldTransform)

        if let grass = makeGrassPlane() {
            grass.position = SIMD3<Float>(0, -0.01, 0)
            anchor.addChild(grass)
        }

        let rex: RexObject
        if let cached = prewarmedRex, dinosaurs.isEmpty {
            rex = cached
            rex.resetForPlacement()
            rex.anchor?.setTransformMatrix(result.worldTransform, relativeTo: nil)
            DebugLog.log("Using prewarmed rex for placement", category: "RexView")
        } else {
            rex = RexObject(rexData: rexData, anchor: anchor)
            rex.bodyFrames.forEach { anchor.addChild($0) }
        }

        if rex.anchor?.scene == nil {
            arView.scene.addAnchor(anchor)
        }
        dinosaurs.append(rex)
        if !freeFirstPlacementUsed {
            freeFirstPlacementUsed = true
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        notifyCountChanged()
        DebugLog.log("Placed rex. Count=\(dinosaurs.count)", category: "RexView")

        if let start = placementGestureStart {
            let duration = CFAbsoluteTimeGetCurrent() - start
            print("Placement gesture-to-dino duration: \(String(format: "%.3f", duration))s")
            DebugLog.log("Placement gesture-to-dino duration: \(String(format: "%.3f", duration))s", category: "RexView")
            placementGestureStart = nil
        }
    }

    func setExternalPlacementEnabled(_ enabled: Bool) {
        externalPlacementEnabled = enabled
        DebugLog.log("External placement enabled=\(enabled)", category: "RexView")
    }

    private func isOverlap(to point: SIMD3<Float>, threshold: Float = 0.25) -> Bool {
        dinosaurs.contains {
            guard let pos = $0.anchor?.position(relativeTo: nil) else { return false }
            return simd_distance(pos, point) < threshold
        }
    }

    // MARK: - Grass Plane
    func makeGrassPlane(size: Float = 1.5) -> ModelEntity? {
        let mesh = MeshResource.generatePlane(width: size, depth: size)
        let material = SimpleMaterial(color: UIColor(red: 0.1, green: 0.4, blue: 0.1, alpha: 1.0),
                                      isMetallic: false)

        let plane = ModelEntity(mesh: mesh, materials: [material])
        plane.transform.rotation = simd_quatf(angle: -.pi/2, axis: [1, 0, 0])
        plane.generateCollisionShapes(recursive: false)
        plane.name = "grassPlane"

        #if canImport(UIKit)
        if let tapIcon = UIImage(systemName: "hand.point.up.left.fill"),
           let cgImage = tapIcon.cgImage,
           let tapTex = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color)) {
            let iconMesh = MeshResource.generatePlane(width: size * 0.2, depth: size * 0.2)
            var iconMat = UnlitMaterial()
            iconMat.color = .init(texture: .init(tapTex))
            let iconEntity = ModelEntity(mesh: iconMesh, materials: [iconMat])
            iconEntity.position = SIMD3<Float>(0, 0.001, 0)
            plane.addChild(iconEntity)
        }
        #endif

        return plane
    }

    // MARK: - Utility
    func notifyCountChanged() {
        let count = effectiveDinoCount()
        DispatchQueue.main.async {
            self.appState.dinoCount = count
        }
    }

    func effectiveDinoCount() -> Int {
        let raw = dinosaurs.count
        if freeFirstPlacementUsed, raw > 0 {
            return raw - 1
        }
        return raw
    }
}
