import SwiftUI
#if canImport(UIKit)
import UIKit

struct PhotoAnalysisView: View {
    let capturedImage: UIImage
    let onBack: () -> Void
    let onConfirm: () -> Void

    @StateObject private var viewModel: PhotoAnalysisViewModel
    @State private var didConfirm = false

    private let green = Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255)
    private let charcoal = Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255)
    private let gray = Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255)
    private let red = Color(red: 211 / 255, green: 47 / 255, blue: 47 / 255)
    private let surface = Color(red: 245 / 255, green: 248 / 255, blue: 245 / 255)

    init(
        capturedImage: UIImage,
        classificationResult: ClassificationResult?,
        isClassifying: Bool,
        onBack: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.capturedImage = capturedImage
        self.onBack = onBack
        self.onConfirm = onConfirm
        _viewModel = StateObject(
            wrappedValue: PhotoAnalysisViewModel(
                classificationResult: classificationResult,
                isClassifying: isClassifying
            )
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let topInset = geometry.safeAreaInsets.top
            let bottomInset = geometry.safeAreaInsets.bottom
            let horizontalPadding = max(16, geometry.size.width * 0.05)
            let heroHeight = min(max(220, geometry.size.height * 0.29), 270)

            ZStack(alignment: .bottom) {
                surface.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        topBar(topInset: topInset, horizontalPadding: horizontalPadding)
                        heroPhoto(height: heroHeight, horizontalPadding: horizontalPadding)

                        if viewModel.isClassifying {
                            classifyingCard(horizontalPadding: horizontalPadding)
                        } else {
                            speciesInfoCard(horizontalPadding: horizontalPadding)
                        }
                    }
                    .padding(.bottom, 120)
                }

                bottomConfirmBar(bottomInset: bottomInset, horizontalPadding: horizontalPadding)
            }
        }
    }

    private func classifyingCard(horizontalPadding: CGFloat) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(green)
            Text("Identifying plant species...")
                .font(.custom("Montserrat-Bold", size: 15))
                .foregroundStyle(charcoal)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
        .padding(.horizontal, horizontalPadding)
    }

    private func topBar(topInset: CGFloat, horizontalPadding: CGFloat) -> some View {
        HStack {
            circleTopButton(icon: "chevron.left", action: onBack)
            Spacer()
            Text("Analysis Result")
                .font(.custom("Montserrat-Bold", size: 15))
                .foregroundStyle(charcoal)
            Spacer()
            circleTopButton(icon: "square.and.arrow.up") {}
                .opacity(0.8)
        }
        .padding(.top, max(20, topInset + 16))
        .padding(.horizontal, horizontalPadding)
    }

    private func heroPhoto(height: CGFloat, horizontalPadding: CGFloat) -> some View {
        Image(uiImage: capturedImage)
            .resizable()
            .scaledToFill()
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Just Now")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Color.black.opacity(0.5))
                .clipShape(Capsule())
                .padding(12)
            }
            .overlay(alignment: .bottomTrailing) {
                if let result = viewModel.classificationResult {
                    confidenceBadge(result: result).padding(12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, horizontalPadding)
    }

    private func confidenceBadge(result: ClassificationResult) -> some View {
        let badgeColor: Color = result.confidence >= 0.7 ? green : result.confidence >= 0.4 ? .orange : gray
        return HStack(spacing: 4) {
            Image(systemName: "sparkle")
                .font(.system(size: 10, weight: .semibold))
            Text(viewModel.confidencePercent)
                .font(.custom("Montserrat-Bold", size: 10))
                .tracking(0.5)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(badgeColor)
        .clipShape(Capsule())
    }

    private func speciesInfoCard(horizontalPadding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(green.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "leaf")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(green)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.speciesName)
                        .font(.custom("Montserrat-Bold", size: 22))
                        .foregroundStyle(charcoal)

                    Text(viewModel.confidenceLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(gray)

                    if let speciesIdText = viewModel.speciesIdText {
                        Text(speciesIdText)
                            .font(.system(size: 11))
                            .foregroundStyle(gray.opacity(0.85))
                    }
                }
            }

            Rectangle()
                .fill(Color(red: 232 / 255, green: 237 / 255, blue: 232 / 255))
                .frame(height: 1)

            if let result = viewModel.classificationResult {
                quickStatsStrip(result: result)

                if viewModel.topPredictions.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OTHER POSSIBILITIES")
                            .font(.custom("Montserrat-Bold", size: 10))
                            .tracking(0.8)
                            .foregroundStyle(gray)

                        FlexibleTagWrap(
                            tags: viewModel.topPredictions.dropFirst().map {
                                "\($0.speciesName) (\(Int($0.confidence * 100))%)"
                            },
                            tint: green
                        )
                    }
                }
            } else {
                Text("No classification result available.")
                    .font(.system(size: 14))
                    .foregroundStyle(gray)
            }
        }
        .padding(16)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 232 / 255, green: 237 / 255, blue: 232 / 255), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
        .padding(.horizontal, horizontalPadding)
    }

    private func quickStatsStrip(result: ClassificationResult) -> some View {
        let confidenceColor: Color = result.confidence >= 0.7 ? green : result.confidence >= 0.4 ? .orange : red
        return HStack(spacing: 0) {
            quickStatCell(title: "Confidence", value: result.confidencePercent, valueColor: confidenceColor)
            divider
            quickStatCell(title: "Top Match", value: "#1", valueColor: charcoal)
            divider
            quickStatCell(title: "Candidates", value: "\(result.topPredictions.count)", valueColor: charcoal)
        }
        .frame(height: 64)
        .background(surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 232 / 255, green: 237 / 255, blue: 232 / 255), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(red: 232 / 255, green: 237 / 255, blue: 232 / 255))
            .frame(width: 1)
    }

    private func quickStatCell(title: String, value: String, valueColor: Color) -> some View {
        VStack(spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10))
                .foregroundStyle(gray)
                .tracking(0.5)
            Text(value)
                .font(.custom("Montserrat-Bold", size: 13))
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity)
    }

    private func bottomConfirmBar(bottomInset: CGFloat, horizontalPadding: CGFloat) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(red: 232 / 255, green: 237 / 255, blue: 232 / 255))
                .frame(height: 1)

            Button {
                didConfirm = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                    onConfirm()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: didConfirm ? "checkmark.circle.fill" : "leaf")
                        .font(.system(size: 18, weight: .semibold))
                    Text(didConfirm ? "Saved to Trail Log!" : "Confirm & Save to Trail Log")
                        .font(.custom("Montserrat-Bold", size: 15))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(didConfirm ? Color(red: 46 / 255, green: 128 / 255, blue: 73 / 255) : green)
                .clipShape(Capsule())
                .shadow(color: green.opacity(didConfirm ? 0.5 : 0.28), radius: 14, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(didConfirm || viewModel.isClassifying)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, max(14, bottomInset))
            .background(.white)
        }
        .background(.white)
    }

    private func circleTopButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(charcoal)
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct FlexibleTagWrap: View {
    let tags: [String]
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(tint.opacity(0.08))
                    .overlay(
                        Capsule().stroke(tint.opacity(0.18), lineWidth: 1)
                    )
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
