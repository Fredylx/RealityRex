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
}

/// View responsible for managing all AR content, gestures, and interactions in the scene.
class RexView: UIView, UIGestureRecognizerDelegate {

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
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 1.0

        [pan, rotate, pinch, longPress].forEach {
            $0.delegate = self
            self.addGestureRecognizer($0)
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    // MARK: - Touch to Place Dino
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard dinosaurs.count < 14 else { return }
        guard let point = touches.first?.location(in: arView) else { return }

        let results = arView.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .horizontal)
        guard let result = results.first else { return }

        let worldPos = SIMD3<Float>(result.worldTransform.columns.3.x,
                                    result.worldTransform.columns.3.y,
                                    result.worldTransform.columns.3.z)

        guard !isOverlap(to: worldPos) else { return }

        let anchor = AnchorEntity(world: result.worldTransform)
        let rex = RexObject(rexData: rexData, anchor: anchor)
        rex.bodyFrames.forEach { anchor.addChild($0) }

        arView.scene.addAnchor(anchor)
        dinosaurs.append(rex)
    }

    private func isOverlap(to point: SIMD3<Float>, threshold: Float = 0.5) -> Bool {
        dinosaurs.contains {
            guard let pos = $0.anchor?.position(relativeTo: nil) else { return false }
            return simd_distance(pos, point) < threshold
        }
    }

    // MARK: - Gesture Handlers

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let location = gesture.location(in: arView)

        if let hitEntity = arView.entity(at: location) {
            for (i, rex) in dinosaurs.enumerated() where rex.bodyFrames.contains(where: { $0 === hitEntity }) {
                showDeleteConfirmation(for: rex, at: i)
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
    }

    // MARK: - Scene Update

    private func subscribeToSceneUpdates() {
        updateCancellable = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] delta in
            self?.dinosaurs.forEach { $0.update(deltaTime: delta.deltaTime) }
        }
    }
}
