import SwiftUI

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    let onCreateAccount: () -> Void
    let onLogin: () -> Void

    init(
        onCreateAccount: @escaping () -> Void = {},
        onLogin: @escaping () -> Void = {}
    ) {
        self.onCreateAccount = onCreateAccount
        self.onLogin = onLogin
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let horizontalPadding = max(20, width * 0.072)
            let logoBoxSize = min(max(width * 0.1, 38), 44)
            let titleSize = min(max(width * 0.082, 28), 34)
            let topPadding = max(20, geometry.safeAreaInsets.top + 20)
            let bottomPadding = max(18, geometry.safeAreaInsets.bottom + 10)

            ZStack {
                Color.white.ignoresSafeArea()

                Circle()
                    .fill(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255).opacity(0.05))
                    .frame(width: width * 0.66, height: width * 0.66)
                    .offset(x: width * 0.38, y: -height * 0.48)

                VStack(alignment: .leading, spacing: 0) {
                    header(logoBoxSize: logoBoxSize)
                        .padding(.bottom, 22)

                    Rectangle()
                        .fill(Color(red: 232 / 255, green: 237 / 255, blue: 232 / 255))
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Start your\nadventure.")
                            .font(.custom("Montserrat-Bold", size: titleSize))
                            .lineSpacing(3)
                            .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
                            .padding(.top, 24)

                        Text("Track hikes, identify species, and build your trail collection — all in one place.")
                            .font(.system(size: min(max(width * 0.039, 14), 16), weight: .regular))
                            .lineSpacing(6)
                            .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: max(40, height * 0.16))

                    bottomActions(width: width)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
            }
        }
    }

    @ViewBuilder
    private func header(logoBoxSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: logoBoxSize * 0.32, style: .continuous)
                    .fill(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255))
                    .frame(width: logoBoxSize, height: logoBoxSize)
                    .shadow(
                        color: Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255).opacity(0.25),
                        radius: 8,
                        x: 0,
                        y: 5
                    )
                    .overlay {
                        Image("leaf icon")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.white)
                            .frame(width: logoBoxSize * 0.5, height: logoBoxSize * 0.5)
                    }

                Text("GoTrail")
                    .font(.custom("Montserrat-Bold", size: 22))
                    .tracking(1.2)
                    .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
            }

            Text("EVERY STEP, RECORDED.")
                .font(.system(size: 11, weight: .regular))
                .tracking(2.2)
                .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
        }
    }

    @ViewBuilder
    private func bottomActions(width: CGFloat) -> some View {
        VStack(spacing: 14) {
            Button {
                viewModel.handleCreateAccount()
                onCreateAccount()
            } label: {
                HStack(spacing: 9) {
                    Image("leaf icon")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)

                    Text("Create an Account")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(
                    color: Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255).opacity(0.28),
                    radius: 12,
                    x: 0,
                    y: 8
                )
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                Text("Already a user?")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))

                Button {
                    viewModel.handleLogin()
                    onLogin()
                } label: {
                    HStack(spacing: 3) {
                        Text("Log into App")
                            .font(.system(size: 15, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255))
                }
                .buttonStyle(.plain)
            }

            (
                Text("By continuing, you agree to GoTrail's ")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(red: 192 / 255, green: 192 / 255, blue: 192 / 255))
                + Text("Terms of Service")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255))
                + Text(" and ")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(red: 192 / 255, green: 192 / 255, blue: 192 / 255))
                + Text("Privacy Policy")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255))
            )
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .frame(maxWidth: min(width * 0.92, 360))
        }
    }
}

#Preview {
    AuthView()
}
