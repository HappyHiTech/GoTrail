import Foundation
import Combine
import Supabase

@MainActor
final class CreateAccountViewModel: ObservableObject {
    @Published var fullName = ""
    @Published var email = ""
    @Published var password = ""
    @Published var showPassword = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    func togglePasswordVisibility() {
        showPassword.toggle()
    }

    @discardableResult
    func handleSignUp() async -> Bool {
        let cleanName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanName.isEmpty == false else {
            errorMessage = "Please enter your full name."
            return false
        }
        guard cleanEmail.isEmpty == false, cleanPassword.isEmpty == false else {
            errorMessage = "Please enter email and password."
            return false
        }
        guard cleanPassword.count >= 8 else {
            errorMessage = "Password must be at least 8 characters."
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await SupabaseManager.client.auth.signUp(
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
}
