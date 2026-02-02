import Foundation
import UIKit

@MainActor
final class Haptics {
    static let shared = Haptics()

    private var impactGenerator: UIImpactFeedbackGenerator?

    private init() {}

    /// Prepares a medium impact feedback generator for immediate use.
    func prewarm() {
        impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator?.prepare()
        DebugLog.log("Haptics prewarm completed", category: "Perf")
    }

    /// Triggers an impact feedback with the specified style.
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        if style == .medium, let generator = impactGenerator {
            generator.impactOccurred()
        } else {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
        }
    }
}
