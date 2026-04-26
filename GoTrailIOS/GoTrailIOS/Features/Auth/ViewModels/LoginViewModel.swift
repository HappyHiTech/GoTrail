import Foundation
import Combine
import Supabase

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var showPassword = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    func togglePasswordVisibility() {
        showPassword.toggle()
    }

    @discardableResult
    func handleLogin() async -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanEmail.isEmpty == false, cleanPassword.isEmpty == false else {
            errorMessage = "Please enter both email and password."
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await SupabaseManager.client.auth.signIn(
                email: cleanEmail,
                password: cleanPassword
            )
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func handleForgotPassword() {
        // TODO: Connect to forgot password flow.
    }
}
