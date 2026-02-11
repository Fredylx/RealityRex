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
    private var isVisible = true

    let rexData: RexData

    init(rexData: RexData, anchor: AnchorEntity) {
        self.rexData = rexData
        self.anchor = anchor

        for prototype in rexData.bodyFramePrototypes {
            if let clone = prototype.clone(recursive: true) as? ModelEntity {
                clone.isEnabled = false
                bodyFrames.append(clone)
            }
        }
        DebugLog.log("RexObject init: frames=\(bodyFrames.count)", category: "RexObject")

        resetForPlacement()
    }

    func resetForPlacement() {
        bodyFrames.forEach { $0.isEnabled = false }
        bodyFrames.first?.isEnabled = true
        lastFrameIndex = 0
        frame = 0.0
        isVisible = true
    }

    func update(deltaTime: TimeInterval) {
        guard isVisible else { return }
        let frameCount = bodyFrames.count
        guard frameCount > 0 else {
            DebugLog.log("RexObject update: no frames", category: "RexObject")
            return
        }

        frame += deltaTime * 30.0 // ← THIS is your walking speed
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

    func setVisible(_ visible: Bool) {
        isVisible = visible
        if visible {
            if let current = lastFrameIndex, current < bodyFrames.count {
                bodyFrames[current].isEnabled = true
            } else {
                bodyFrames.first?.isEnabled = true
            }
        } else {
            bodyFrames.forEach { $0.isEnabled = false }
        }
    }
}
