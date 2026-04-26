import SwiftUI
import MapKit
#if canImport(UIKit)
import UIKit
#endif

struct ActiveHikeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ActiveHikeViewModel
    @State private var showStopConfirmation = false
    @State private var isStopping = false
    @State private var showAllPicturesSheet = false
#if canImport(UIKit)
    @State private var showCameraPicker = false
    @State private var capturedUIImage: UIImage?
    @State private var analysisUIImage: UIImage?
    @State private var showPhotoAnalysis = false
    @State private var showCameraUnavailableAlert = false
#endif

    private let green = Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255)

    init(hikeTitle: String) {
        _viewModel = StateObject(wrappedValue: ActiveHikeViewModel(hikeTitle: hikeTitle))
    }

    var body: some View {
        GeometryReader { geometry in
            let topInset = geometry.safeAreaInsets.top
            let bottomInset = geometry.safeAreaInsets.bottom
            let width = geometry.size.width
            let horizontalPadding = max(16, geometry.size.width * 0.05)
            let mapHeight = min(max(390, geometry.size.height * 0.72), 540)
            let thumbSize = min(max(width * 0.138, 50), 62)
            let panelSpacing = min(max(width * 0.022, 8), 12)
            let pictureTitleSize = min(max(width * 0.034, 12), 14)
            let actionTitleSize = min(max(width * 0.05, 17), 21)
            let takeButtonHeight = min(max(width * 0.14, 50), 58)
            let stopButtonHeight = min(max(width * 0.118, 44), 50)

            ZStack(alignment: .top) {
                Color(red: 245 / 255, green: 248 / 255, blue: 245 / 255).ignoresSafeArea()

                VStack(spacing: 0) {
                    mapSection(topInset: topInset, mapHeight: mapHeight, horizontalPadding: horizontalPadding)

                    liveStatsCard
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, -10)

                    bottomActionPanel(
                        horizontalPadding: horizontalPadding,
                        thumbSize: thumbSize,
                        panelSpacing: panelSpacing,
                        pictureTitleSize: pictureTitleSize,
                        actionTitleSize: actionTitleSize,
                        takeButtonHeight: takeButtonHeight,
                        stopButtonHeight: stopButtonHeight
                    )
                        .padding(.top, 10)
                        .padding(.bottom, max(14, bottomInset))
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            viewModel.startObserving()
        }
        .sheet(isPresented: $showAllPicturesSheet) {
            allPicturesSheet
        }
#if canImport(UIKit)
        .sheet(isPresented: $showCameraPicker) {
            ActiveHikeCameraPicker(image: $capturedUIImage)
                .ignoresSafeArea()
        }
        .onChange(of: capturedUIImage) { _, image in
            guard let image else { return }
            analysisUIImage = image
            showPhotoAnalysis = true
            capturedUIImage = nil
            Task {
                _ = await viewModel.recordCapturedPicture(image)
            }
        }
        .fullScreenCover(isPresented: $showPhotoAnalysis) {
            if let analysisUIImage {
                PhotoAnalysisView(
                    capturedImage: analysisUIImage,
                    classificationResult: viewModel.classificationResult,
                    isClassifying: viewModel.isClassifying,
                    onBack: {
                        showPhotoAnalysis = false
                    },
                    onConfirm: {
                        showPhotoAnalysis = false
                    }
                )
                .ignoresSafeArea()
            }
        }
        .alert("Camera Unavailable", isPresented: $showCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device does not have an available camera.")
        }
#endif
        .confirmationDialog("End this hike?", isPresented: $showStopConfirmation, titleVisibility: .visible) {
            Button("Stop Hike", role: .destructive) {
                Task {
                    isStopping = true
                    let stopped = await viewModel.stopHikeAndExit()
                    isStopping = false
                    if stopped {
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func bottomActionPanel(
        horizontalPadding: CGFloat,
        thumbSize: CGFloat,
        panelSpacing: CGFloat,
        pictureTitleSize: CGFloat,
        actionTitleSize: CGFloat,
        takeButtonHeight: CGFloat,
        stopButtonHeight: CGFloat
    ) -> some View {
        VStack(spacing: panelSpacing) {
            pictureStripSection(thumbSize: thumbSize, titleSize: pictureTitleSize)
            takePictureButton(titleSize: actionTitleSize, buttonHeight: takeButtonHeight)
            stopHikeButton(titleSize: actionTitleSize, buttonHeight: stopButtonHeight)
        }
        .padding(.horizontal, horizontalPadding)
    }

    private func pictureStripSection(thumbSize: CGFloat, titleSize: CGFloat) -> some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.arrow.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
                    Text(viewModel.pictureCountText)
                        .font(.custom("Montserrat-Bold", size: titleSize))
                        .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
                }

                Spacer()

                Button {
                    showAllPicturesSheet = true
                } label: {
                    Text("See all →")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(green)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(viewModel.pictures.prefix(5).enumerated()), id: \.element.localId) { _, picture in
                        pictureThumbnail(path: picture.localImagePath, size: thumbSize)
                    }

                    if viewModel.pictures.count > 5 {
                        let remaining = viewModel.pictures.count - 5
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(red: 245 / 255, green: 248 / 255, blue: 245 / 255))
                            Text("+\(remaining)")
                                .font(.custom("Montserrat-Bold", size: 11))
                                .foregroundStyle(green)
                        }
                        .frame(width: thumbSize, height: thumbSize)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(green.opacity(0.14), lineWidth: 1.5)
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func pictureThumbnail(path: String, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 238 / 255, green: 244 / 255, blue: 238 / 255))

            if let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 150 / 255, green: 150 / 255, blue: 150 / 255))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(green.opacity(0.12), lineWidth: 1.5)
        )
    }

    private func takePictureButton(titleSize: CGFloat, buttonHeight: CGFloat) -> some View {
        Button {
#if canImport(UIKit)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                showCameraPicker = true
            } else {
                showCameraUnavailableAlert = true
            }
#endif
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "camera")
                    .font(.system(size: 18, weight: .semibold))
                Text("Take a Picture")
                    .font(.custom("Montserrat-Bold", size: titleSize))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background(green)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: green.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isStopping)
    }

    private func stopHikeButton(titleSize: CGFloat, buttonHeight: CGFloat) -> some View {
        Button {
            showStopConfirmation = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "stop.square")
                    .font(.system(size: 15, weight: .semibold))
                Text("Stop Hike")
                    .font(.custom("Montserrat-Bold", size: titleSize))
            }
            .foregroundStyle(Color(red: 211 / 255, green: 47 / 255, blue: 47 / 255))
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background(Color(red: 211 / 255, green: 47 / 255, blue: 47 / 255).opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(red: 211 / 255, green: 47 / 255, blue: 47 / 255).opacity(0.3), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isStopping)
    }

    private var allPicturesSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                    ForEach(viewModel.pictures, id: \.localId) { picture in
                        pictureThumbnail(path: picture.localImagePath, size: 96)
                            .frame(width: 96, height: 96)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Hike Pictures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showAllPicturesSheet = false
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(green)
                }
            }
        }
    }

    private func mapSection(topInset: CGFloat, mapHeight: CGFloat, horizontalPadding: CGFloat) -> some View {
        ZStack(alignment: .top) {
            ActiveHikeMapView(
                routepoints: viewModel.routepoints,
                recenterTick: viewModel.recenterTick
            )
            .frame(height: mapHeight)
            .overlay(alignment: .bottomLeading) {
                if viewModel.routepoints.isEmpty == false {
                    StartMarkerPill()
                        .padding(.leading, horizontalPadding)
                        .padding(.bottom, 28)
                }
            }

            HStack(spacing: 10) {
                Button {
                    showStopConfirmation = true
                } label: {
                    floatingIcon(icon: "chevron.left", isPrimary: false)
                }
                .buttonStyle(.plain)
            .disabled(isStopping)

                HStack(spacing: 6) {
                    Image(systemName: "location.viewfinder")
                        .font(.system(size: 11, weight: .semibold))
                    Text(viewModel.hikeTitle)
                        .font(.custom("Montserrat-Bold", size: 14))
                        .lineLimit(1)
                }
                .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(.white.opacity(0.92))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)

                Button {
                    viewModel.recenterMap()
                } label: {
                    floatingIcon(icon: "location.fill", isPrimary: true)
                }
                .buttonStyle(.plain)
            .disabled(isStopping)
            }
            .padding(.top, max(0, topInset - 4))
            .padding(.horizontal, horizontalPadding)
        }
    }

    private var liveStatsCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(red: 211 / 255, green: 47 / 255, blue: 47 / 255))
                        .frame(width: 6, height: 6)
                    Text("LIVE · ACTIVE HIKE")
                        .font(.custom("Montserrat-Bold", size: 11))
                        .tracking(1.1)
                        .foregroundStyle(Color(red: 211 / 255, green: 47 / 255, blue: 47 / 255))
                }

                Rectangle()
                    .fill(Color(red: 220 / 255, green: 220 / 255, blue: 220 / 255))
                    .frame(width: 1, height: 12)

                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.system(size: 10, weight: .semibold))
                    Text(viewModel.distanceText)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
            }

            Text(viewModel.elapsedText)
                .font(.custom("Montserrat-Bold", size: 48))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private func floatingIcon(icon: String, isPrimary: Bool) -> some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(isPrimary ? .white : Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
            .frame(width: 36, height: 36)
            .background(isPrimary ? green : .white.opacity(0.92))
            .clipShape(Circle())
            .shadow(color: (isPrimary ? green : .black).opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

#if canImport(UIKit)
private struct PhotoAnalysisView: View {
    let capturedImage: UIImage
    let classificationResult: ClassificationResult?
    let isClassifying: Bool
    let onBack: () -> Void
    let onConfirm: () -> Void

    @State private var didConfirm = false

    private let green = Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255)
    private let charcoal = Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255)
    private let gray = Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255)
    private let red = Color(red: 211 / 255, green: 47 / 255, blue: 47 / 255)
    private let surface = Color(red: 245 / 255, green: 248 / 255, blue: 245 / 255)

    private var speciesName: String {
        classificationResult?.speciesName ?? "Analyzing..."
    }

    private var confidenceText: String {
        classificationResult?.confidencePercent ?? ""
    }

    private var confidenceLabel: String {
        classificationResult?.confidenceLabel ?? ""
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

                        if isClassifying {
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
        .padding(.top, max(12, topInset + 4))
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
                if let result = classificationResult {
                    confidenceBadge(result: result)
                        .padding(12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, horizontalPadding)
    }

    private func confidenceBadge(result: ClassificationResult) -> some View {
        let badgeColor: Color = result.confidence >= 0.7 ? green :
            result.confidence >= 0.4 ? Color.orange : gray

        return HStack(spacing: 4) {
            Image(systemName: "sparkle")
                .font(.system(size: 10, weight: .semibold))
            Text(result.confidencePercent)
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
                    Text(speciesName)
                        .font(.custom("Montserrat-Bold", size: 22))
                        .foregroundStyle(charcoal)

                    if let result = classificationResult {
                        Text(result.confidenceLabel)
                            .font(.system(size: 13))
                            .foregroundStyle(gray)

                        if let speciesId = result.speciesId {
                            Text("Species ID: \(speciesId)")
                                .font(.system(size: 11))
                                .foregroundStyle(gray.opacity(0.85))
                        }
                    }
                }
            }

            Rectangle()
                .fill(Color(red: 232 / 255, green: 237 / 255, blue: 232 / 255))
                .frame(height: 1)

            if let result = classificationResult {
                quickStatsStrip(result: result)

                if result.topPredictions.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OTHER POSSIBILITIES")
                            .font(.custom("Montserrat-Bold", size: 10))
                            .tracking(0.8)
                            .foregroundStyle(gray)

                        FlexibleTagWrap(
                            tags: result.topPredictions.dropFirst().map {
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
        let confidenceColor: Color = result.confidence >= 0.7 ? green :
            result.confidence >= 0.4 ? Color.orange : red

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
            .disabled(didConfirm || isClassifying)
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

private struct ActiveHikeCameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: ActiveHikeCameraPicker

        init(_ parent: ActiveHikeCameraPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let selectedImage = info[.originalImage] as? UIImage {
                parent.image = selectedImage
            }
            parent.dismiss()
        }
    }
}
#endif

private struct ActiveHikeMapView: UIViewRepresentable {
    let routepoints: [PendingRoutepoint]
    let recenterTick: Int

    private let green = UIColor(red: 30 / 255, green: 86 / 255, blue: 49 / 255, alpha: 1)

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsTraffic = false
        mapView.showsBuildings = false
        mapView.mapType = .mutedStandard
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.green = green

        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })

        let routeCoordinates = routepoints.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }

        if routeCoordinates.count > 1 {
            let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
            mapView.addOverlay(polyline)
        }

        if let first = routeCoordinates.first {
            let start = MKPointAnnotation()
            start.coordinate = first
            start.title = "S"
            mapView.addAnnotation(start)
        }

        if recenterTick != context.coordinator.lastRecenterTick {
            context.coordinator.lastRecenterTick = recenterTick
            fitVisibleRect(mapView: mapView, routeCoordinates: routeCoordinates, animated: true)
        } else if context.coordinator.lastRouteCount != routeCoordinates.count {
            context.coordinator.lastRouteCount = routeCoordinates.count
            fitVisibleRect(mapView: mapView, routeCoordinates: routeCoordinates, animated: false)
        }
    }

    private func fitVisibleRect(mapView: MKMapView, routeCoordinates: [CLLocationCoordinate2D], animated: Bool) {
        guard routeCoordinates.isEmpty == false else {
            let fallback = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 34.0113, longitude: -116.1669),
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            )
            mapView.setRegion(fallback, animated: animated)
            return
        }

        var rect = MKMapRect.null
        for coordinate in routeCoordinates {
            let point = MKMapPoint(coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
            rect = rect.isNull ? pointRect : rect.union(pointRect)
        }

        mapView.setVisibleMapRect(
            rect,
            edgePadding: UIEdgeInsets(top: 56, left: 28, bottom: 90, right: 28),
            animated: animated
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var green: UIColor = .systemGreen
        var lastRouteCount = -1
        var lastRecenterTick = 0

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = green
            renderer.lineWidth = 4
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "StartAnnotation"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.canShowCallout = false
            view.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
            view.layer.cornerRadius = 12
            view.layer.borderWidth = 1.5
            view.layer.borderColor = green.cgColor
            view.backgroundColor = .white

            let labelTag = 999
            let label: UILabel
            if let existing = view.viewWithTag(labelTag) as? UILabel {
                label = existing
            } else {
                label = UILabel(frame: view.bounds)
                label.tag = labelTag
                label.textAlignment = .center
                label.font = .systemFont(ofSize: 10, weight: .bold)
                label.textColor = green
                label.text = "S"
                view.addSubview(label)
            }
            label.frame = view.bounds
            return view
        }
    }
}

private struct StartMarkerPill: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flag.fill")
                .font(.system(size: 9, weight: .semibold))
            Text("Start")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(Color.black.opacity(0.55))
        .clipShape(Capsule())
    }
}

#Preview {
    ActiveHikeView(hikeTitle: "Cascade Ridge Loop")
}
