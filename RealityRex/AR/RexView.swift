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

/// View responsible for managing all AR content, gestures, and interactions in the scene.
class RexView: UIView, ARSessionDelegate {

    // MARK: - AR Scene State
    var dinosaurs: [RexObject] = []

    var updateCancellable: Cancellable?
    var didWarmup = false
    private var warmupObserver: NSObjectProtocol?
    var prewarmedRex: RexObject?
    var didAutoPlace = false
    var isAutoPlacing = false
    var pendingAutoPlacementTransform: simd_float4x4?
    var autoPlacedRex: RexObject?
    var externalPlacementEnabled = false
    var planeVisuals: [UUID: ModelEntity] = [:]
    var planeAnchors: [UUID: AnchorEntity] = [:]
    var planeDetectionTimeoutWorkItem: DispatchWorkItem?
    var autoPlacementTimeoutWorkItem: DispatchWorkItem?
    var loadingTapWorkItem: DispatchWorkItem?
    var limitToastWorkItem: DispatchWorkItem?
    var autoPlacementReadyWorkItem: DispatchWorkItem?
    var freeFirstPlacementUsed = false

    weak var arView: ARView?
    let rexData: RexData
    let appState: AppState
    let maxDinos = 14
    var placementGestureStart: CFAbsoluteTime?

    // MARK: - Init
    required init(arView: ARView, appState: AppState) {
        self.arView = arView
        self.rexData = RexData.shared
        self.appState = appState
        super.init(frame: .zero)

        DebugLog.log("RexView init", category: "RexView")
        arView.session.delegate = self
        setupGestureRecognizers()
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
}

