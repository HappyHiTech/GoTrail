import SwiftUI

struct SplashView: View {
    @StateObject private var viewModel = SplashViewModel()
    let onContinue: () -> Void

    init(onContinue: @escaping () -> Void = {}) {
        self.onContinue = onContinue
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let logoSize = min(width * 0.22, 88)
            let iconSize = logoSize * 0.46
            let titleSize = min(width * 0.1, 38)

            ZStack {
                Color.white.ignoresSafeArea()

                Circle()
                    .fill(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255).opacity(0.06))
                    .frame(width: width * 0.65, height: width * 0.65)
                    .offset(x: width * 0.34, y: -height * 0.42)

                Circle()
                    .fill(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255).opacity(0.05))
                    .frame(width: width * 0.82, height: width * 0.82)
                    .offset(x: -width * 0.38, y: height * 0.43)

                Circle()
                    .fill(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255).opacity(0.04))
                    .frame(width: width * 0.36, height: width * 0.36)
                    .offset(x: -width * 0.53, y: 0)

                VStack(spacing: min(height * 0.03, 26)) {
                    ZStack {
                        RoundedRectangle(cornerRadius: logoSize * 0.32, style: .continuous)
                            .fill(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255))
                            .frame(width: logoSize, height: logoSize)
                            .shadow(
                                color: Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255).opacity(0.28),
                                radius: 14,
                                x: 0,
                                y: 8
                            )

                        Image("leaf icon")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.white)
                            .frame(width: iconSize, height: iconSize)
                    }

                    VStack(spacing: 10) {
                        Text("GoTrail")
                            .font(.custom("Montserrat-Bold", size: titleSize))
                            .tracking(1.2)
                            .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))

                        Text("EVERY STEP, RECORDED.")
                            .font(.system(size: min(width * 0.031, 13), weight: .regular))
                            .tracking(2.5)
                            .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text("Tap to continue")
                    .font(.system(size: min(width * 0.033, 13), weight: .regular))
                    .foregroundStyle(Color(red: 190 / 255, green: 190 / 255, blue: 190 / 255))
                    .padding(.bottom, max(30, height * 0.055))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.handleTapContinue(onCompleted: onContinue)
            }
            .overlay {
                if viewModel.didTapContinue {
                    Color.black.opacity(0.05).ignoresSafeArea()
                }
            }
        }
    }
}

#Preview {
    SplashView()
}
