import SwiftUI

struct CreateAccountView: View {
    @StateObject private var viewModel = CreateAccountViewModel()
    let onClose: () -> Void
    let onGoToLogin: () -> Void
    let onSignUpSuccess: () -> Void

    init(
        onClose: @escaping () -> Void = {},
        onGoToLogin: @escaping () -> Void = {},
        onSignUpSuccess: @escaping () -> Void = {}
    ) {
        self.onClose = onClose
        self.onGoToLogin = onGoToLogin
        self.onSignUpSuccess = onSignUpSuccess
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let horizontalPadding = max(20, width * 0.062)
            let topPadding = max(16, geometry.safeAreaInsets.top + 8)
            let bottomPadding = max(18, geometry.safeAreaInsets.bottom + 10)

            ZStack {
                Color.white.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    header
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            formField(
                                label: "Full Name",
                                prompt: "Alex Johnson",
                                text: $viewModel.fullName
                            )
                            formField(
                                label: "Email Address",
                                prompt: "hello@example.com",
                                text: $viewModel.email,
                                isEmail: true
                            )
                            passwordField
                            helperText

                            signUpButton

                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            termsText
                                .padding(.top, 2)
                        }
                        .padding(.top, 14)
                    }

                    Spacer(minLength: 8)

                    footer
                        .padding(.top, 8)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255))
                        .frame(width: 24, height: 24)
                        .overlay {
                            Image("leaf icon")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.white)
                                .frame(width: 12, height: 12)
                        }

                    Text("GOTRAIL")
                        .font(.custom("Montserrat-Bold", size: 11))
                        .tracking(1.5)
                        .foregroundStyle(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255))
                }

                Spacer()

                Button(action: onClose) {
                    Circle()
                        .fill(Color(red: 245 / 255, green: 248 / 255, blue: 245 / 255))
                        .overlay(Circle().stroke(Color(red: 232 / 255, green: 237 / 255, blue: 232 / 255), lineWidth: 1))
                        .frame(width: 34, height: 34)
                        .overlay {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 66 / 255, green: 66 / 255, blue: 66 / 255))
                        }
                }
                .buttonStyle(.plain)
            }

            Text("Create an Account")
                .font(.custom("Montserrat-Bold", size: 41))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))

            Text("Start your adventure today.")
                .font(.system(size: 17))
                .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))

            HStack(spacing: 8) {
                Group {
                    if viewModel.showPassword {
                        TextField("Create a strong password", text: $viewModel.password)
                    } else {
                        SecureField("Create a strong password", text: $viewModel.password)
                    }
                }

                Button(action: viewModel.togglePasswordVisibility) {
                    Image(systemName: viewModel.showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(red: 124 / 255, green: 124 / 255, blue: 124 / 255))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color(red: 245 / 255, green: 248 / 255, blue: 245 / 255))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(red: 232 / 255, green: 237 / 255, blue: 232 / 255), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var helperText: some View {
        Text("Use 8+ characters with a mix of letters, numbers & symbols.")
            .font(.system(size: 11))
            .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
    }

    private var signUpButton: some View {
        Button {
            Task {
                if await viewModel.handleSignUp() {
                    onSignUpSuccess()
                }
            }
        } label: {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Sign Up")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(
                    color: Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255).opacity(0.28),
                    radius: 10,
                    x: 0,
                    y: 6
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
        .padding(.top, 4)
    }

    private var termsText: some View {
        (
            Text("By signing up, you agree to our ")
                .font(.system(size: 11))
                .foregroundStyle(Color(red: 190 / 255, green: 190 / 255, blue: 190 / 255))
            + Text("Terms")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255))
            + Text(" and ")
                .font(.system(size: 11))
                .foregroundStyle(Color(red: 190 / 255, green: 190 / 255, blue: 190 / 255))
            + Text("Privacy Policy")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255))
            + Text(".")
                .font(.system(size: 11))
                .foregroundStyle(Color(red: 190 / 255, green: 190 / 255, blue: 190 / 255))
        )
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Spacer()
            Text("Already have an account?")
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
            Button("Log In", action: onGoToLogin)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255))
                .buttonStyle(.plain)
            Spacer()
        }
        .frame(height: 24)
    }

    private func formField(
        label: String,
        prompt: String,
        text: Binding<String>,
        isEmail: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))

            if isEmail {
                TextField(prompt, text: text)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color(red: 245 / 255, green: 248 / 255, blue: 245 / 255))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(red: 232 / 255, green: 237 / 255, blue: 232 / 255), lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                TextField(prompt, text: text)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color(red: 245 / 255, green: 248 / 255, blue: 245 / 255))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(red: 232 / 255, green: 237 / 255, blue: 232 / 255), lineWidth: 1.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

#Preview {
    CreateAccountView()
}
