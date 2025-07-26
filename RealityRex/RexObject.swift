//
//  RexObject.swift
//  RealityRex
//
//  Created by Fredy Humberto Lopez on 4/11/23.
//

import Foundation
import RealityKit

class RexObject {

    var bodyFrames = [ModelEntity]()
    var anchor: AnchorEntity?
    private var frame: Double = 0.0
    private var lastFrameIndex: Int?

    let rexData: RexData

    init(rexData: RexData, anchor: AnchorEntity) {
        self.rexData = rexData
        self.anchor = anchor

//        for mesh in rexData.bodyMeshResources {
//            let entity = ModelEntity(mesh: mesh, materials: [rexData.bodyMaterial])
//            entity.isEnabled = false
//            bodyFrames.append(entity)
//        }
        for mesh in rexData.bodyMeshResources {
            let entity = ModelEntity(mesh: mesh, materials: [rexData.bodyMaterial])
            entity.generateCollisionShapes(recursive: false) // 👈 Add this
            entity.isEnabled = false
            bodyFrames.append(entity)
        }

        // Start with first frame visible
        bodyFrames.first?.isEnabled = true
        lastFrameIndex = 0
    }

    func update(deltaTime: TimeInterval) {
        let frameCount = bodyFrames.count
        guard frameCount > 0 else { return }

        frame += deltaTime * 25.0 // ← THIS is your walking speed
        // frames per second
        frame.formTruncatingRemainder(dividingBy: Double(frameCount))

        let frameIndex = Int(frame)
        if frameIndex != lastFrameIndex {
            if let last = lastFrameIndex, last < frameCount {
                bodyFrames[last].isEnabled = false
            }
            bodyFrames[frameIndex].isEnabled = true
            lastFrameIndex = frameIndex
        }
    }
}
