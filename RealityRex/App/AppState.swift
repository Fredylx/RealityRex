import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var dinoCount: Int = 0
}
