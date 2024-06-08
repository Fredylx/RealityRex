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
    
    var frame: Double = 0.0
    
    let rexData: RexData
    init(rexData: RexData) {
        self.rexData = rexData
        
        for mesh in rexData.bodyMeshResources {
            let entity = ModelEntity(mesh: mesh, materials: [rexData.bodyMaterial])
            bodyFrames.append(entity)
        }
        
    }
    
    func update(deltaTime: TimeInterval) {
        
        let frameCount = bodyFrames.count
        guard frameCount > 0 else { return }
        let frameCountF = Double(frameCount)
        
        frame += (deltaTime * 30.0)
        while frame >= frameCountF {
            frame -= frameCountF
        }
        
        var frameIndex = Int(frame)
        if frameIndex >= frameCount { frameIndex = frameCount - 1 }
        if frameIndex < 0 { frameIndex = 0 }
        
        for index in 0..<bodyFrames.count {
            if index == frameIndex {
                bodyFrames[index].isEnabled = true
            } else {
                bodyFrames[index].isEnabled = false
            }
        }
        
    }
    
}
