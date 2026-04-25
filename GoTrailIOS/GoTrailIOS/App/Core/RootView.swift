import SwiftUI

struct RootView: View {
    @State private var currentScreen: AppScreen = .splash

    var body: some View {
        ZStack {
            switch currentScreen {
            case .splash:
                SplashView {
                    withAnimation(.easeOut(duration: 0.2)) {
                        currentScreen = .auth
                    }
                }
                .transition(.opacity)

            case .auth:
                AuthView(
                    onCreateAccount: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            currentScreen = .createAccount
                        }
                    },
                    onLogin: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            currentScreen = .login
                        }
                    }
                )
                .transition(.opacity)

            case .createAccount:
                CreateAccountView(
                    onClose: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            currentScreen = .auth
                        }
                    },
                    onGoToLogin: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            currentScreen = .login
                        }
                    },
                    onSignUpSuccess: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            currentScreen = .loggedIn
                        }
                    }
                )
                .transition(.opacity)

            case .login:
                LoginView(
                    onClose: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            currentScreen = .auth
                        }
                    },
                    onGoToSignUp: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            currentScreen = .createAccount
                        }
                    },
                    onLoginSuccess: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            currentScreen = .loggedIn
                        }
                    }
                )
                .transition(.opacity)

            case .loggedIn:
                HikeHistoryView()
                    .transition(.opacity)
            }
        }
    }
}

private enum AppScreen {
    case splash
    case auth
    case createAccount
    case login
    case loggedIn
}

#Preview {
    RootView()
}
