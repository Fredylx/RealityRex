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
//    static let selectedDinoChanged = Notification.Name("selectedDinoChanged")
//    static let controllerMove = Notification.Name("controllerMove")
//    static let controllerRotate = Notification.Name("controllerRotate")
//    static let controllerScale = Notification.Name("controllerScale")
//    static let controllerDelete = Notification.Name("controllerDelete")
}

/// View responsible for managing all AR content, gestures, and interactions in the scene.
class RexView: UIView /*, UIGestureRecognizerDelegate*/, ARSessionDelegate {

    // MARK: - AR Scene State
    private var dinosaurs: [RexObject] = []
    private var selectedRex: RexObject?

    private var dragOffset: SIMD3<Float>?

    private var updateCancellable: Cancellable?
    private var warmupObserver: NSObjectProtocol?
    private var didWarmup = false
    private var prewarmedRex: RexObject?
    private var didAutoPlace = false
    private var isAutoPlacing = false
    private var pendingAutoPlacementTransform: simd_float4x4?
    private var autoPlacedRex: RexObject?
    private var userPlacementEnabled = true
    private var externalPlacementEnabled = false
    private var planeVisuals: [UUID: ModelEntity] = [:]
    private var planeAnchors: [UUID: AnchorEntity] = [:]
    private var planeDetectionTimeoutWorkItem: DispatchWorkItem?
    private var autoPlacementTimeoutWorkItem: DispatchWorkItem?
    private var freeFirstPlacementUsed = false

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
        // setupGestureRecognizers()
        subscribeToSceneUpdates()
        NotificationCenter.default.addObserver(self, selector: #selector(clearAllDinos), name: .clearAllDinos, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(handleControllerMove(_:)), name: .controllerMove, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(handleControllerRotate(_:)), name: .controllerRotate, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(handleControllerScale(_:)), name: .controllerScale, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(handleControllerDelete), name: .controllerDelete, object: nil)
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
    /*
    private func setupGestureRecognizers() {
        DebugLog.log("Setup gestures", category: "RexView")
        // Gestures disabled for now; tap-to-select and tap-to-place handled in touchesBegan.
    }
    */

    /*
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    */

    // MARK: - Touch to Place Dino
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let arView = arView else { return }
        guard externalPlacementEnabled else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            DebugLog.log("Touch ignored: placement not yet enabled", category: "RexView")
            return
        }

//        if let point = touches.first?.location(in: arView),
//           let hitEntity = arView.entity(at: point),
//           let rex = dinosaurs.first(where: { $0.bodyFrames.contains(where: { $0 === hitEntity }) }) {
//            select(rex)
//            UIImpactFeedbackGenerator(style: .light).impactOccurred()
//            return
//        }

        guard RexData.shared.isReady else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            NotificationCenter.default.post(name: .dinoLoadingTap, object: nil)
            DebugLog.log("Touch ignored: RexData not ready", category: "RexView")
            return
        }
        guard effectiveDinoCount() < maxDinos else {
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
        if !freeFirstPlacementUsed {
            freeFirstPlacementUsed = true
        }
//        select(rex)
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

//    private func select(_ rex: RexObject?) {
//        selectedRex = rex
//        NotificationCenter.default.post(name: .selectedDinoChanged, object: rex != nil)
//        DebugLog.log("Selected rex changed: \(rex != nil)", category: "RexView")
//    }

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
    /*
    // MARK: - Gesture Handlers

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        // Tap handler code here if any
    }

    @objc private func handleDoubleTapDelete(_ gesture: UITapGestureRecognizer) {
        // Double tap delete handler code here if any
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        // Pan handler code here if any
    }

    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        // Rotation handler code here if any
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        // Pinch handler code here if any
    }
    */

//    // MARK: - Controller Actions
//
//    @objc private func handleControllerMove(_ notification: Notification) {
//        guard let arView = arView,
//              let rex = selectedRex,
//              let dir = notification.userInfo?["dir"] as? String else { return }
//
//        let step: Float = 0.05
//        let cameraTransform = arView.cameraTransform.matrix
//        var forward = SIMD3<Float>(-cameraTransform.columns.2.x, 0, -cameraTransform.columns.2.z)
//        var right = SIMD3<Float>(cameraTransform.columns.0.x, 0, cameraTransform.columns.0.z)
//        if simd_length(forward) > 0 { forward = simd_normalize(forward) }
//        if simd_length(right) > 0 { right = simd_normalize(right) }
//
//        var delta = SIMD3<Float>(0, 0, 0)
//        switch dir {
//        case "up":
//            delta = forward * step
//        case "down":
//            delta = -forward * step
//        case "left":
//            delta = -right * step
//        case "right":
//            delta = right * step
//        default:
//            break
//        }
//
//        if let pos = rex.anchor?.position(relativeTo: nil) {
//            rex.anchor?.setPosition(pos + delta, relativeTo: nil)
//        }
//    }
//
//    @objc private func handleControllerRotate(_ notification: Notification) {
//        guard let rex = selectedRex,
//              let dir = notification.userInfo?["dir"] as? String else { return }
//        let angle: Float = (dir == "left") ? 10.0 : -10.0
//        let radians = angle * (.pi / 180.0)
//        let delta = simd_quatf(angle: radians, axis: [0, 1, 0])
//        if let current = rex.anchor?.orientation(relativeTo: nil) {
//            rex.anchor?.setOrientation(simd_normalize(delta * current), relativeTo: nil)
//        }
//    }
//
//    @objc private func handleControllerScale(_ notification: Notification) {
//        guard let rex = selectedRex,
//              let dir = notification.userInfo?["dir"] as? String else { return }
//        let factor: Float = (dir == "up") ? 1.08 : 0.92
//        if let current = rex.anchor?.scale(relativeTo: nil) {
//            let next = current * factor
//            let clamped = SIMD3<Float>(
//                max(0.2, min(3.0, next.x)),
//                max(0.2, min(3.0, next.y)),
//                max(0.2, min(3.0, next.z))
//            )
//            rex.anchor?.setScale(clamped, relativeTo: nil)
//        }
//    }
//
//    @objc private func handleControllerDelete() {
//        guard let rex = selectedRex,
//              let index = dinosaurs.firstIndex(where: { $0 === rex }) else { return }
//        rex.anchor?.removeFromParent()
//        dinosaurs.remove(at: index)
//        select(nil)
//        notifyCountChanged()
//        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
//        DebugLog.log("Deleted rex via controller. Count=\(dinosaurs.count)", category: "RexView")
//    }

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
//        select(nil)
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
        NotificationCenter.default.post(name: .dinoCountChanged, object: effectiveDinoCount())
    }

    private func effectiveDinoCount() -> Int {
        let raw = dinosaurs.count
        if freeFirstPlacementUsed, raw > 0 {
            return raw - 1
        }
        return raw
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
