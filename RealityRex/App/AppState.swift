import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var dinoCount: Int = 0
    @Published var isRexDataReady: Bool = false
    @Published var showLoadingTapHint: Bool = false
    @Published var showLimitToast: Bool = false
    @Published var showAutoPlacementLoading: Bool = false
    @Published var showAutoPlacementReady: Bool = false
    @Published var autoPlacementMessage: String = "Preparing your first dino..."
}
