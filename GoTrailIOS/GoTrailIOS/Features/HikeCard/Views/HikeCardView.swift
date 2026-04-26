import SwiftUI

struct HikeCardView: View {
    let hike: HikeCardModel

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                if let imageAssetName = hike.imageAssetName {
                    Image(imageAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 96)
                        .clipped()
                } else if let imageURLString = hike.imageURLString,
                          let imageURL = URL(string: imageURLString) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 96)
                                .clipped()
                        default:
                            LinearGradient(
                                colors: [
                                    Color(red: 237 / 255, green: 242 / 255, blue: 237 / 255),
                                    Color(red: 226 / 255, green: 234 / 255, blue: 226 / 255)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 96)
                        }
                    }
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 240 / 255, green: 245 / 255, blue: 240 / 255),
                                Color(red: 226 / 255, green: 234 / 255, blue: 226 / 255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255).opacity(0.22),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                            )
                            .frame(width: 70, height: 40)

                        VStack(spacing: 5) {
                            Image(systemName: "photo")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255).opacity(0.65))

                            Text("No cover photo")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255).opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
                }

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 96)

                Text(hike.title)
                    .font(.custom("Montserrat-Bold", size: 12))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }

            VStack(alignment: .leading, spacing: 4) {
                cardRow(icon: "mappin.and.ellipse", text: hike.location)
                cardRow(icon: "location", text: String(format: "%.1f km", hike.distanceKm))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(.white)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    private func cardRow(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
                .frame(width: 8, height: 8)

            Text(text)
                .font(.system(size: 8))
                .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    HikeCardView(
        hike: HikeCardModel(
            title: "Cascade Ridge Loop",
            location: "Olympic NP, WA",
            distanceKm: 14.2,
            plantsFound: 12
        )
    )
}
