import Foundation
import Combine

final class AuthViewModel: ObservableObject {
    @Published private(set) var isBusy = false

    func handleCreateAccount() {
        // TODO: Wire to sign-up flow.
    }

    func handleLogin() {
        // TODO: Wire to log-in flow.
    }
}
