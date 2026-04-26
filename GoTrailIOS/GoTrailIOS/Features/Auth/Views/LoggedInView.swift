import SwiftUI

struct LoggedInView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255))

                Text("Logged in")
                    .font(.custom("Montserrat-Bold", size: 32))
                    .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))

                Text("Authentication succeeded.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
            }
            .padding(24)
        }
    }
}

#Preview {
    LoggedInView()
}
