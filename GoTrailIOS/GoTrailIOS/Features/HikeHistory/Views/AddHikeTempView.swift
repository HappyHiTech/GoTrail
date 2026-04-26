import SwiftUI

struct AddHikeTempView: View {
    var body: some View {
        ZStack {
            Color(red: 245 / 255, green: 248 / 255, blue: 245 / 255)
            VStack(spacing: 14) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255))

                Text("Add Hike")
                    .font(.custom("Montserrat-Bold", size: 30))
                    .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))

                Text("Temporary screen. We’ll wire hike creation flow next.")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
                    .padding(.horizontal, 28)
            }
            .padding(24)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    AddHikeTempView()
}
