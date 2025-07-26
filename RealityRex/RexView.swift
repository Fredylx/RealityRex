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

class RexView: UIView, UIGestureRecognizerDelegate {
    private var selectedRex: RexObject?
    private var isDragging = false
    private var dragOffset: SIMD3<Float>?
    private var rotatingRex: RexObject?
    private var initialRotation: simd_quatf?
    private var scalingRex: RexObject?
    private var initialScale: SIMD3<Float>?

    var dinosaurs = [RexObject]()
    var updateCancellable: Cancellable?

    let arView: ARView
    let rexData: RexData

    required init(arView: ARView) {
        self.arView = arView
        self.rexData = RexData()
        super.init(frame: .zero)

        NotificationCenter.default.addObserver(self, selector: #selector(clearAllDinos), name: .clearAllDinos, object: nil)

        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        self.addGestureRecognizer(rotationGesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        self.addGestureRecognizer(panGesture)

        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchGesture.delegate = self
        self.addGestureRecognizer(pinchGesture)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 1.0 // Adjust duration as needed
        self.addGestureRecognizer(longPress)

        longPress.delegate = self
        panGesture.delegate = self
        rotationGesture.delegate = self

        updateCancellable = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] delta in
            self?.dinosaurs.forEach { $0.update(deltaTime: delta.deltaTime) }
        }
    }

    deinit {
        updateCancellable?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard dinosaurs.count < 14 else { return }

        guard let point = touches.first?.location(in: arView) else { return }

        let raycastResults = arView.raycast(from: point,
                                            allowing: .existingPlaneGeometry,
                                            alignment: .horizontal)

        guard let result = raycastResults.first else { return }

        // 🧠 Convert result to world space point
        let worldPosition = result.worldTransform.columns.3
        let tapLocation = SIMD3<Float>(worldPosition.x, worldPosition.y, worldPosition.z)

        // ✅ Check for overlap
        guard !isOverlap(to: tapLocation) else { return }

        // 🦖 Place new dino
        let anchor = AnchorEntity(world: result.worldTransform)
        let rex = RexObject(rexData: rexData, anchor: anchor)

        rex.bodyFrames.forEach { anchor.addChild($0) }
        arView.scene.addAnchor(anchor)
        dinosaurs.append(rex)
    }


    private func isOverlap(to point: SIMD3<Float>, threshold: Float = 0.5) -> Bool {
        for rex in dinosaurs {
            if let existingPos = rex.anchor?.position(relativeTo: nil) {
                let distance = simd_distance(existingPos, point)
                if distance < threshold {
                    return true
                }
            }
        }
        return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let location = gesture.location(in: self.arView)

        switch gesture.state {
        case .began:
            if let entity = arView.entity(at: location) {
                for rex in dinosaurs {
                    if rex.bodyFrames.contains(where: { $0 === entity }) {
                        scalingRex = rex
                        initialScale = rex.anchor?.scale(relativeTo: nil)
                        break
                    }
                }
            }

        case .changed:
            guard let rex = scalingRex, let originalScale = initialScale else { return }
            let scaleFactor = Float(gesture.scale)
            let newScale = originalScale * scaleFactor
            rex.anchor?.setScale(newScale, relativeTo: nil)

        case .ended, .cancelled:
            scalingRex = nil
            initialScale = nil

        default:
            break
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        let location = gesture.location(in: self.arView)

        if let result = arView.entity(at: location) {
            for (i, rex) in dinosaurs.enumerated() {
                if rex.bodyFrames.contains(where: { $0 === result }) {
                    // Remove anchor from scene
//                    result.anchor?.removeFromParent()
                    // Remove from array
//                    dinosaurs.remove(at: i)
                    showDeleteConfirmation(for: rex, at: i)
                    break
                }
            }
        }
    }

    private func showDeleteConfirmation(for rex: RexObject, at index: Int) {
        guard let viewController = self.window?.rootViewController else { return }

        let alert = UIAlertController(title: "Remove Dino?", message: "Are you sure you want to delete this T-Rex?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            rex.anchor?.removeFromParent()
            self.dinosaurs.remove(at: index)
        }))

        viewController.present(alert, animated: true, completion: nil)
    }

    @objc private func clearAllDinos() {
        for rex in dinosaurs {
            rex.anchor?.removeFromParent()
        }
        dinosaurs.removeAll()
    }

    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        let location = gesture.location(in: self.arView)

        switch gesture.state {
        case .began:
            if let entity = arView.entity(at: location) {
                for rex in dinosaurs {
                    if rex.bodyFrames.contains(where: { $0 === entity }) {
                        rotatingRex = rex
                        initialRotation = rex.anchor?.orientation(relativeTo: nil)
                        break
                    }
                }
            }

        case .changed:
            guard let rex = rotatingRex, let original = initialRotation else { return }

            let rotationAngle = Float(-gesture.rotation) // counter-clockwise in UIKit
            let deltaRotation = simd_quatf(angle: rotationAngle, axis: [0, 1, 0])
            let newOrientation = simd_normalize(deltaRotation * original)

            rex.anchor?.setOrientation(newOrientation, relativeTo: nil)

        case .ended, .cancelled:
            rotatingRex = nil
            initialRotation = nil

        default:
            break
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self.arView)

        switch gesture.state {
        case .began:
            if let entity = arView.entity(at: location) {
                for rex in dinosaurs {
                    if rex.bodyFrames.contains(where: { $0 === entity }) {
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
            }

        case .changed:
            guard isDragging,
                  let rex = selectedRex,
                  let offset = dragOffset,
                  let ray = arView.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .horizontal).first
            else { return }

            let hitPoint = SIMD3<Float>(ray.worldTransform.columns.3.x,
                                        ray.worldTransform.columns.3.y,
                                        ray.worldTransform.columns.3.z)

            let newPosition = hitPoint + offset
            rex.anchor?.setPosition(newPosition, relativeTo: nil)

        case .ended, .cancelled:
            selectedRex = nil
            dragOffset = nil
            isDragging = false

        default:
            break
        }
    }
}
