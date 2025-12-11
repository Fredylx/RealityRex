//
//  RexView.swift
//  RealityRex
//
//  Created by Fredy Humberto Lopez on 4/4/23.
//

import UIKit
import RealityKit
import ARKit
import Combine

extension Notification.Name {
    static let clearAllDinos = Notification.Name("clearAllDinos")
    static let placementFeedback = Notification.Name("placementFeedback")
}

/// View responsible for managing all AR content, gestures, and interactions in the scene.
class RexView: UIView, UIGestureRecognizerDelegate {

    private enum PlacementRules {
        static let maxDinosaurs: Int = 14
        static let overlapThreshold: Float = 0.25
    }

    // MARK: - AR Scene State
    private var dinosaurs: [RexObject] = []
    private var selectedRex: RexObject?
    private var rotatingRex: RexObject?
    private var scalingRex: RexObject?

    private var isDragging = false
    private var dragOffset: SIMD3<Float>?
    private var initialRotation: simd_quatf?
    private var initialScale: SIMD3<Float>?

    private var updateCancellable: Cancellable?

    let arView: ARView
    let rexData: RexData

    // MARK: - Init
    required init(arView: ARView) {
        self.arView = arView
        self.rexData = RexData()
        super.init(frame: .zero)

        setupGestureRecognizers()
        subscribeToSceneUpdates()
        NotificationCenter.default.addObserver(self, selector: #selector(clearAllDinos), name: .clearAllDinos, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        updateCancellable?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Gesture Setup
    private func setupGestureRecognizers() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2

        [pan, rotate, pinch, doubleTap].forEach {
            $0.delegate = self
            self.addGestureRecognizer($0)
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    // MARK: - Touch to Place Dino
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard dinosaurs.count < PlacementRules.maxDinosaurs else {
            sendPlacementFeedback("Maximum dinos placed")
            return
        }
        guard let point = touches.first?.location(in: arView) else { return }

        let results = arView.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .horizontal)
        guard let result = results.first else {
            sendPlacementFeedback("Aim at a detected surface")
            return
        }

        let worldPos = SIMD3<Float>(result.worldTransform.columns.3.x,
                                    result.worldTransform.columns.3.y,
                                    result.worldTransform.columns.3.z)

        guard !isOverlap(to: worldPos) else {
            sendPlacementFeedback("Too close to another dino")
            return
        }

        let anchor = AnchorEntity(world: result.worldTransform)

        // Add a grass ground plane under the anchor so dinos appear on grass
        if let grass = makeGrassPlane() {
            // Position the grass plane slightly below the hit point so it sits under the rex feet
            grass.position = SIMD3<Float>(0, -0.01, 0)
            anchor.addChild(grass)
        }

        let rex = RexObject(rexData: rexData, anchor: anchor)
        rex.bodyFrames.forEach { anchor.addChild($0) }

        arView.scene.addAnchor(anchor)
        dinosaurs.append(rex)
    }

    private func isOverlap(to point: SIMD3<Float>, threshold: Float = PlacementRules.overlapThreshold) -> Bool {
        // Allow a little overlap by using a smaller threshold
        dinosaurs.contains {
            guard let pos = $0.anchor?.position(relativeTo: nil) else { return false }
            return simd_distance(pos, point) < threshold
        }
    }

    // MARK: - Grass Plane

    /// Creates a square ground plane ModelEntity sized to cover placement area.
    /// Uses a solid dark green material by default so users can see placement space.
    private func makeGrassPlane(size: Float = 1.5) -> ModelEntity? {
    // Create a simple plane mesh and orient it horizontally
        let mesh = MeshResource.generatePlane(width: size, depth: size)

        // Solid dark green ground material to make tap targets visible
        var material: Material
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: .init(_colorLiteralRed: 0.1, green: 0.4, blue: 0.1, alpha: 1.0))
        mat.roughness = .init(1.0)
        material = mat

        let plane = ModelEntity(mesh: mesh, materials: [material])
        // Rotate plane so its normal faces up
        plane.transform.rotation = simd_quatf(angle: -.pi/2, axis: [1, 0, 0])
        plane.generateCollisionShapes(recursive: false)
        plane.name = "grassPlane"

        // Optional: Add a tap icon overlay using a child entity (correct MaterialColorParameter usage)
        #if canImport(UIKit)
        if let tapIcon = UIImage(systemName: "hand.point.up.left.fill") {
            if let tapTex = try? TextureResource.generate(from: tapIcon.cgImage!, options: .init(semantic: .color)) {
                let iconMesh = MeshResource.generatePlane(width: size * 0.2, depth: size * 0.2)
                var iconMat = UnlitMaterial()
                iconMat.baseColor = .init(_colorLiteralRed: 0.5, green: 1, blue: 0.2, alpha: 1.0)
                let iconEntity = ModelEntity(mesh: iconMesh, materials: [iconMat])
                iconEntity.position = SIMD3<Float>(0, 0.001, 0)
                plane.addChild(iconEntity)
            }
        }
        #endif

        return plane
    }

    // MARK: - Gesture Handlers


    // Double-tap to delete dino
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)
        if let hitEntity = arView.entity(at: location) {
            for (i, rex) in dinosaurs.enumerated() where rex.bodyFrames.contains(where: { $0 === hitEntity }) {
                rex.anchor?.removeFromParent()
                dinosaurs.remove(at: i)
                break
            }
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: arView)

        switch gesture.state {
        case .began:
            if let hitEntity = arView.entity(at: location) {
                for rex in dinosaurs where rex.bodyFrames.contains(where: { $0 === hitEntity }) {
                    selectedRex = rex
                    isDragging = true
                    if let anchorPos = rex.anchor?.position(relativeTo: nil),
                       let ray = arView.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .horizontal).first {
                        let hitPoint = SIMD3<Float>(ray.worldTransform.columns.3.x,
                                                    ray.worldTransform.columns.3.y,
                                                    ray.worldTransform.columns.3.z)
                        dragOffset = anchorPos - hitPoint
                    }
                    break
                }
            }
        case .changed:
            guard isDragging,
                  let rex = selectedRex,
                  let offset = dragOffset,
                  let ray = arView.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .horizontal).first else { return }

            let hitPoint = SIMD3<Float>(ray.worldTransform.columns.3.x,
                                        ray.worldTransform.columns.3.y,
                                        ray.worldTransform.columns.3.z)
            rex.anchor?.setPosition(hitPoint + offset, relativeTo: nil)

        case .ended, .cancelled:
            selectedRex = nil
            dragOffset = nil
            isDragging = false

        default:
            break
        }
    }

    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        let location = gesture.location(in: arView)

        switch gesture.state {
        case .began:
            if let hitEntity = arView.entity(at: location) {
                for rex in dinosaurs where rex.bodyFrames.contains(where: { $0 === hitEntity }) {
                    rotatingRex = rex
                    initialRotation = rex.anchor?.orientation(relativeTo: nil)
                    break
                }
            }

        case .changed:
            guard let rex = rotatingRex, let original = initialRotation else { return }
            let deltaRotation = simd_quatf(angle: Float(-gesture.rotation), axis: [0, 1, 0])
            rex.anchor?.setOrientation(simd_normalize(deltaRotation * original), relativeTo: nil)

        case .ended, .cancelled:
            rotatingRex = nil
            initialRotation = nil

        default:
            break
        }
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let location = gesture.location(in: arView)

        switch gesture.state {
        case .began:
            if let hitEntity = arView.entity(at: location) {
                for rex in dinosaurs where rex.bodyFrames.contains(where: { $0 === hitEntity }) {
                    scalingRex = rex
                    initialScale = rex.anchor?.scale(relativeTo: nil)
                    break
                }
            }

        case .changed:
            guard let rex = scalingRex, let baseScale = initialScale else { return }
            rex.anchor?.setScale(baseScale * Float(gesture.scale), relativeTo: nil)

        case .ended, .cancelled:
            scalingRex = nil
            initialScale = nil

        default:
            break
        }
    }

    // MARK: - Utility

    private func sendPlacementFeedback(_ message: String) {
        NotificationCenter.default.post(name: .placementFeedback, object: nil, userInfo: ["message": message])
    }

    @objc private func clearAllDinos() {
        dinosaurs.forEach { $0.anchor?.removeFromParent() }
        dinosaurs.removeAll()
    }

    // MARK: - Scene Update

    private func subscribeToSceneUpdates() {
        updateCancellable = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] delta in
            self?.dinosaurs.forEach { $0.update(deltaTime: delta.deltaTime) }
        }
    }
}
