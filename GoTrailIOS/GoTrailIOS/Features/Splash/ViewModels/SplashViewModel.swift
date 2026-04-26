import Foundation
import Combine

final class SplashViewModel: ObservableObject {
    @Published private(set) var didTapContinue = false

    func handleTapContinue(onCompleted: @escaping () -> Void) {
        guard didTapContinue == false else { return }
        didTapContinue = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onCompleted()
        }
    }
}
