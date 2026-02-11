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
class RexView: UIView, ARSessionDelegate {

    // MARK: - AR Scene State
    var dinosaurs: [RexObject] = []
    var selectedRex: RexObject?

    var dragOffset: SIMD3<Float>?

    var updateCancellable: Cancellable?
    var warmupObserver: NSObjectProtocol?
    var didWarmup = false
    var prewarmedRex: RexObject?
    var didAutoPlace = false
    var isAutoPlacing = false
    var pendingAutoPlacementTransform: simd_float4x4?
    var autoPlacedRex: RexObject?
    var userPlacementEnabled = true
    var externalPlacementEnabled = false
    var planeVisuals: [UUID: ModelEntity] = [:]
    var planeAnchors: [UUID: AnchorEntity] = [:]
    var planeDetectionTimeoutWorkItem: DispatchWorkItem?
    var autoPlacementTimeoutWorkItem: DispatchWorkItem?
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
