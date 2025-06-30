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

class RexView: UIView {

    var dinosaurs = [RexObject]()
    var updateCancellable: Cancellable?

    let arView: ARView
    let rexData: RexData

    required init(arView: ARView) {
        self.arView = arView
        self.rexData = RexData()
        super.init(frame: .zero)

        NotificationCenter.default.addObserver(self, selector: #selector(clearAllDinos), name: .clearAllDinos, object: nil)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.4 // Adjust duration as needed
        self.addGestureRecognizer(longPress)

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
        guard let point = touches.first?.location(in: arView) else { return }

        let raycastResults = arView.raycast(from: point,
                                            allowing: .existingPlaneGeometry,
                                            alignment: .horizontal)

        guard let result = raycastResults.first else { return }
        let anchor = AnchorEntity(world: result.worldTransform)

        let rex = RexObject(rexData: rexData, anchor: anchor) // ✅ pass the anchor
        dinosaurs.append(rex)

//        let anchor = AnchorEntity(world: result.worldTransform)
        rex.bodyFrames.forEach { anchor.addChild($0) }
        dinosaurs.append(rex)
        arView.scene.addAnchor(anchor)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        let location = gesture.location(in: self.arView)

        if let result = arView.entity(at: location) {
            for (i, rex) in dinosaurs.enumerated() {
                if rex.bodyFrames.contains(where: { $0 === result }) {
                    // Remove anchor from scene
                    result.anchor?.removeFromParent()
                    // Remove from array
                    dinosaurs.remove(at: i)
                    break
                }
            }
        }
    }

    @objc private func clearAllDinos() {
        for rex in dinosaurs {
            rex.anchor?.removeFromParent()
        }
        dinosaurs.removeAll()
    }
}
