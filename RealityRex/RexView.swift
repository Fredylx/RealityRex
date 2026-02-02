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
    static let resetARSession = Notification.Name("resetARSession")
    static let dinoCountChanged = Notification.Name("dinoCountChanged")
    static let dinoLimitReached = Notification.Name("dinoLimitReached")
    static let rexDataReady = Notification.Name("rexDataReady")
    static let dinoLoadingTap = Notification.Name("dinoLoadingTap")
    static let rexDataProgress = Notification.Name("rexDataProgress")
    static let autoPlacementStarted = Notification.Name("autoPlacementStarted")
    static let autoPlacementFinished = Notification.Name("autoPlacementFinished")
    static let autoPlacementStatus = Notification.Name("autoPlacementStatus")
}

/// View responsible for managing all AR content, gestures, and interactions in the scene.
class RexView: UIView, UIGestureRecognizerDelegate, ARSessionDelegate {

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
    private var warmupObserver: NSObjectProtocol?
    private var didWarmup = false
    private var prewarmedRex: RexObject?
    private var didAutoPlace = false
    private var isAutoPlacing = false
    private var pendingAutoPlacementTransform: simd_float4x4?
    private var autoPlacedRex: RexObject?
    private var userPlacementEnabled = false
    private var externalPlacementEnabled = false
    private var planeVisuals: [UUID: ModelEntity] = [:]
    private var planeAnchors: [UUID: AnchorEntity] = [:]
    private var planeDetectionTimeoutWorkItem: DispatchWorkItem?
    private var autoPlacementTimeoutWorkItem: DispatchWorkItem?

    weak var arView: ARView?
    let rexData: RexData
    private let maxDinos = 14
    private var placementGestureStart: CFAbsoluteTime?

    // MARK: - Init
    required init(arView: ARView) {
        self.arView = arView
        self.rexData = RexData.shared
        super.init(frame: .zero)

        DebugLog.log("RexView init", category: "RexView")
        arView.session.delegate = self
        setupGestureRecognizers()
        subscribeToSceneUpdates()
        NotificationCenter.default.addObserver(self, selector: #selector(clearAllDinos), name: .clearAllDinos, object: nil)
        schedulePlaneDetectionTimeout()
        warmupIfPossible()
        warmupObserver = NotificationCenter.default.addObserver(
            forName: .rexDataReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.warmupIfPossible()
            self?.tryAutoPlaceIfPossible()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        updateCancellable?.cancel()
        if let warmupObserver = warmupObserver {
            NotificationCenter.default.removeObserver(warmupObserver)
        }
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Gesture Setup
    private func setupGestureRecognizers() {
        DebugLog.log("Setup gestures", category: "RexView")
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
        guard let arView = arView else { return }
        guard userPlacementEnabled, externalPlacementEnabled else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            DebugLog.log("Touch ignored: auto placement in progress", category: "RexView")
            return
        }
        guard RexData.shared.isReady else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            NotificationCenter.default.post(name: .dinoLoadingTap, object: nil)
            DebugLog.log("Touch ignored: RexData not ready", category: "RexView")
            return
        }
        guard dinosaurs.count < maxDinos else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            NotificationCenter.default.post(name: .dinoLimitReached, object: nil)
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

        // Set start time for this placement gesture
        placementGestureStart = CFAbsoluteTimeGetCurrent()

        let anchor = AnchorEntity(world: result.worldTransform)

        // Add a grass ground plane under the anchor so dinos appear on grass
        if let grass = makeGrassPlane() {
            // Position the grass plane slightly below the hit point so it sits under the rex feet
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

    // MARK: - Auto Placement

    private func tryAutoPlaceIfPossible() {
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
        rex.setVisible(false)

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
            self.userPlacementEnabled = true
            NotificationCenter.default.post(name: .autoPlacementFinished, object: nil)
            NotificationCenter.default.post(
                name: .autoPlacementStatus,
                object: nil,
                userInfo: ["text": "Ready — tap to place!"]
            )
            DebugLog.log("Auto placement finished; user placement enabled", category: "RexView")
        }
    }

    private func isOverlap(to point: SIMD3<Float>, threshold: Float = 0.25) -> Bool {
        // Allow a little overlap by using a smaller threshold
        dinosaurs.contains {
            guard let pos = $0.anchor?.position(relativeTo: nil) else { return false }
            return simd_distance(pos, point) < threshold
        }
    }

    // MARK: - Grass Plane

    /// Creates a square grass plane ModelEntity sized to cover placement area.
    /// Uses an asset image from the app's asset catalog. If you want a different
    /// grass texture, add it to Assets.xcassets and update the UIImage name below.
    private func makeGrassPlane(size: Float = 1.5) -> ModelEntity? {
    // Create a simple plane mesh and orient it horizontally
        let mesh = MeshResource.generatePlane(width: size, depth: size)

        // Try loading a grass texture from Assets. Fall back to a simple green material.
        // Always use a solid dark green for the ground
        let material = SimpleMaterial(color: UIColor(red: 0.1, green: 0.4, blue: 0.1, alpha: 1.0),
                                      isMetallic: false)

        let plane = ModelEntity(mesh: mesh, materials: [material])
        // Rotate plane so its normal faces up
        plane.transform.rotation = simd_quatf(angle: -.pi/2, axis: [1, 0, 0])
        plane.generateCollisionShapes(recursive: false)
        plane.name = "grassPlane"

        // Optional: Add a tap icon overlay using a child entity (correct MaterialColorParameter usage)
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

    // MARK: - Gesture Handlers


    // Double-tap to delete dino
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView = arView else { return }
        let location = gesture.location(in: arView)
        if let hitEntity = arView.entity(at: location) {
            for (i, rex) in dinosaurs.enumerated() where rex.bodyFrames.contains(where: { $0 === hitEntity }) {
                rex.anchor?.removeFromParent()
                dinosaurs.remove(at: i)
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                notifyCountChanged()
                DebugLog.log("Deleted rex. Count=\(dinosaurs.count)", category: "RexView")
                break
            }
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let arView = arView else { return }
        let location = gesture.location(in: arView)

        switch gesture.state {
        case .began:
            DebugLog.log("Pan began", category: "RexView")
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
            DebugLog.log("Pan ended", category: "RexView")

        default:
            break
        }
    }

    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        guard let arView = arView else { return }
        let location = gesture.location(in: arView)

        switch gesture.state {
        case .began:
            DebugLog.log("Rotation began", category: "RexView")
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
            DebugLog.log("Rotation ended", category: "RexView")

        default:
            break
        }
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let arView = arView else { return }
        let location = gesture.location(in: arView)

        switch gesture.state {
        case .began:
            DebugLog.log("Pinch began", category: "RexView")
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
            DebugLog.log("Pinch ended", category: "RexView")

        default:
            break
        }
    }

    // MARK: - Utility

    private func showDeleteConfirmation(for rex: RexObject, at index: Int) {
        guard let vc = self.window?.rootViewController else { return }

        let alert = UIAlertController(title: "Remove Dino?",
                                      message: "Are you sure you want to delete this T-Rex?",
                                      preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            rex.anchor?.removeFromParent()
            self.dinosaurs.remove(at: index)
        })

        vc.present(alert, animated: true)
    }

    @objc private func clearAllDinos() {
        dinosaurs.forEach { $0.anchor?.removeFromParent() }
        dinosaurs.removeAll()
        autoPlacedRex?.anchor?.removeFromParent()
        autoPlacedRex = nil
        notifyCountChanged()
        DebugLog.log("Cleared all dinos", category: "RexView")
    }

    // MARK: - Scene Update

    private func subscribeToSceneUpdates() {
        guard let arView = arView else { return }
        updateCancellable = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] delta in
            self?.dinosaurs.forEach { $0.update(deltaTime: delta.deltaTime) }
        }
        DebugLog.log("Subscribed to SceneEvents.Update", category: "RexView")
    }

    private func notifyCountChanged() {
        NotificationCenter.default.post(name: .dinoCountChanged, object: dinosaurs.count)
    }

    private func warmupIfPossible() {
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

    private func schedulePlaneDetectionTimeout() {
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

    private func scheduleAutoPlacementTimeout() {
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

    private func addOrUpdatePlaneVisual(for plane: ARPlaneAnchor) {
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
