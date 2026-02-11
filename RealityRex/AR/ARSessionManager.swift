import Foundation
import ARKit
import RealityKit

final class ARSessionManager {
    func configureSession(for arView: ARView, simplified: Bool) -> ARWorldTrackingConfiguration {
        let config = Self.defaultConfiguration(simplified: simplified)
        arView.automaticallyConfigureSession = false
        arView.session.run(config)
        arView.debugOptions = []
        DebugLog.log("AR session configured (simplified=\(simplified))", category: "AR")
        return config
    }

    static func defaultConfiguration(simplified: Bool = false) -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = simplified ? .none : .automatic
        config.isAutoFocusEnabled = true
        return config
    }
}
