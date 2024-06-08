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

class RexView: UIView {
    
    var dinosaurs = [RexObject]()
    
    var updateCancellable: Cancellable?
    
    let arView: ARView
    let rexData: RexData
    required init(arView: ARView) {
        self.arView = arView
        self.rexData = RexData()
        super.init(frame: .zero)
        
        updateCancellable = arView.scene.subscribe(to: SceneEvents.Update.self) { delta in
            for dinosaur in self.dinosaurs {
                dinosaur.update(deltaTime: delta.deltaTime)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        guard let touch = touches.first else { return }
        let point = touch.location(in: arView)
        
        let raycastResults = arView.raycast(from: point,
                                            allowing: ARRaycastQuery.Target.existingPlaneGeometry,
                                            alignment: ARRaycastQuery.TargetAlignment.horizontal)
        
        guard let raycastResult = raycastResults.first else { return }
        
        
        let rex = RexObject(rexData: rexData)
        dinosaurs.append(rex)
        
        let anchor = AnchorEntity(world: raycastResult.worldTransform)
        
        for entity in rex.bodyFrames {
            anchor.addChild(entity)
        }
        
        arView.scene.addAnchor(anchor)
        
        
        /*
        if let bodyMesh = rexData.bodyMeshResources.first {
            
            //let bodyEntity = ModelEntity(mesh: bodyMesh, materials: [rexData.bodyMaterial])
            
            
            
            //anchor.addChild(bodyEntity)
            
            
            
            
        }
        */
        
        
        
    }

}
