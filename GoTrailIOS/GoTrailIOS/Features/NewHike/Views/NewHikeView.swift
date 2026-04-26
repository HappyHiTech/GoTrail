import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct NewHikeView: View {
    @StateObject private var viewModel = NewHikeViewModel()
    @State private var didAnimateIn = false
    @State private var coverPhotoItem: PhotosPickerItem?
    @State private var coverPhotoPreview: Image?
    @State private var showCoverPhotoSourceDialog = false
    @State private var showPhotoLibraryPicker = false
#if canImport(UIKit)
    @State private var showCameraPicker = false
    @State private var capturedCoverUIImage: UIImage?
    @State private var showCameraUnavailableAlert = false
#endif
    @FocusState private var isHikeNameFocused: Bool
    @State private var showStartErrorAlert = false

    let onClose: () -> Void
    let onStartHike: (String) -> Void

    private let green = Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255)
    private let pageBackground = Color(red: 245 / 255, green: 248 / 255, blue: 245 / 255)

    init(onClose: @escaping () -> Void = {}, onStartHike: @escaping (String) -> Void = { _ in }) {
        self.onClose = onClose
        self.onStartHike = onStartHike
    }

    var body: some View {
        GeometryReader { geometry in
            let topInset = geometry.safeAreaInsets.top
            let bottomInset = geometry.safeAreaInsets.bottom
            let horizontalPadding = max(16, geometry.size.width * 0.05)

            ZStack(alignment: .bottom) {
                pageBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    header(topInset: topInset, horizontalPadding: horizontalPadding)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            gpsCard
                            hikeNameSection
                            coverPhotoSection
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, 20)
                        .padding(.bottom, 140 + max(0, bottomInset - 8))
                    }
                }

                bottomStartBar(bottomInset: bottomInset, horizontalPadding: horizontalPadding)
            }
            .opacity(didAnimateIn ? 1 : 0)
            .offset(y: didAnimateIn ? 0 : 16)
            .onAppear {
                viewModel.beginLocationLookup()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    didAnimateIn = true
                }
            }
        }
        .confirmationDialog("Add Cover Photo", isPresented: $showCoverPhotoSourceDialog, titleVisibility: .visible) {
#if canImport(UIKit)
            Button("Take Photo") {
                presentCameraCapture()
            }
#endif
            Button("Photo Library") {
                showPhotoLibraryPicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotoLibraryPicker, selection: $coverPhotoItem, matching: .images, photoLibrary: .shared())
#if canImport(UIKit)
        .sheet(isPresented: $showCameraPicker) {
            CameraPhotoPicker(image: $capturedCoverUIImage)
                .ignoresSafeArea()
        }
#endif
        .onChange(of: coverPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadCoverPhoto(from: newItem) }
        }
#if canImport(UIKit)
        .onChange(of: capturedCoverUIImage) { _, newImage in
            guard let newImage else { return }
            applyCapturedCoverPhoto(newImage)
            capturedCoverUIImage = nil
        }
        .alert("Camera Unavailable", isPresented: $showCameraUnavailableAlert) {
            Button("Open Photo Library") {
                showPhotoLibraryPicker = true
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device does not have an available camera. You can still choose a photo from your library.")
        }
#endif
        .alert("Unable to start hike", isPresented: $showStartErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Please try again.")
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func header(topInset: CGFloat, horizontalPadding: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                        }
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    Text("New Hike")
                        .font(.custom("Montserrat-Bold", size: 24))
                        .foregroundStyle(.white)
                    Text("Set up your trail")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                        viewModel.locationAccuracyMeters = max(2, Int.random(in: 2...7))
                    }
                } label: {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(0.15))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.22), lineWidth: 1))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image("leaf icon")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.white)
                                .frame(width: 14, height: 14)
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, horizontalPadding)
            .frame(height: 55)
        }
        .background {
            green
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(.white.opacity(0.07))
                        .frame(width: 160, height: 160)
                        .offset(x: 40, y: -45)
                }
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(.white.opacity(0.05))
                        .frame(width: 130, height: 130)
                        .offset(x: -24, y: 40)
                }
            }
    }

    private var gpsCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(green.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "location")
                        .font(.system(size: 18))
                        .foregroundStyle(green)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.locationName)
                    .font(.custom("Montserrat-Bold", size: 15))
                    .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
                Text(viewModel.locationSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
            }
            Spacer()
            Text("± \(viewModel.locationAccuracyMeters) m")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(green)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(green.opacity(0.08))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 18)
        .frame(height: 79)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(green.opacity(0.2), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: green.opacity(0.1), radius: 6, x: 0, y: 2)
    }

    private var hikeNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HIKE NAME")
                .font(.custom("Montserrat-Bold", size: 12))
                .tracking(0.4)
                .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))

            HStack(spacing: 10) {
                Image(systemName: "paperplane")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(red: 180 / 255, green: 180 / 255, blue: 180 / 255))
                TextField("Name your hike... (e.g., Sunset Ridge)", text: $viewModel.hikeName)
                    .foregroundStyle(.black)
                    .focused($isHikeNameFocused)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(red: 232 / 255, green: 237 / 255, blue: 232 / 255), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onTapGesture {
                isHikeNameFocused = true
            }
        }
    }

    private var coverPhotoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COVER PHOTO")
                .font(.custom("Montserrat-Bold", size: 12))
                .tracking(0.4)
                .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))

            if viewModel.didSkipCoverPhoto {
                skippedCoverPhotoCard
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                defaultCoverPhotoCard
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.didSkipCoverPhoto)
    }

    private var defaultCoverPhotoCard: some View {
        VStack(spacing: 8) {
            Button {
                showCoverPhotoSourceDialog = true
            } label: {
                ZStack {
                    if let coverPhotoPreview {
                        coverPhotoPreview
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 196)
                            .clipped()
                            .overlay(alignment: .bottomTrailing) {
                                Text("Tap to retake")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .frame(height: 28)
                                    .background(.black.opacity(0.45))
                                    .clipShape(Capsule())
                                    .padding(12)
                            }
                    } else {
                        VStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(green.opacity(0.08))
                                .frame(width: 52, height: 52)
                                .overlay {
                                    Image(systemName: "camera")
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundStyle(green)
                                }

                            Text("Add a cover photo")
                                .font(.custom("Montserrat-Bold", size: 14))
                                .foregroundStyle(green)

                            Text("Snap the trailhead for your history")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 196)
                        .background(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 196)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(green.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                )
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                if coverPhotoPreview != nil {
                    Button {
                        showCoverPhotoSourceDialog = true
                    } label: {
                        Text("Retake")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(green)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(green.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    viewModel.skipCoverPhoto()
                    coverPhotoPreview = nil
                    coverPhotoItem = nil
                } label: {
                    Text("Skip — no cover photo")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var skippedCoverPhotoCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(green.opacity(0.08))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "photo.slash")
                        .font(.system(size: 21))
                        .foregroundStyle(Color(red: 150 / 255, green: 150 / 255, blue: 150 / 255))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("No cover photo")
                    .font(.custom("Montserrat-Bold", size: 13))
                    .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
                Text("You can always add one from history")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
            }

            Spacer()

            Button {
                showCoverPhotoSourceDialog = true
            } label: {
                Text("Add")
                    .font(.custom("Montserrat-Bold", size: 14))
                    .foregroundStyle(green)
                    .padding(.horizontal, 2)
                    .frame(height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 92)
        .frame(maxWidth: .infinity)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 232 / 255, green: 237 / 255, blue: 232 / 255), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func loadCoverPhoto(from item: PhotosPickerItem) async {
        do {
            guard let image = try await item.loadTransferable(type: Image.self) else {
                return
            }
            await MainActor.run {
                coverPhotoPreview = image
                viewModel.applyCoverPhotoSelection(hasPhoto: true)
                // Keep flow moving: after selecting a photo, immediately focus hike name.
                isHikeNameFocused = true
            }
        } catch {
            await MainActor.run {
                coverPhotoPreview = nil
                viewModel.applyCoverPhotoSelection(hasPhoto: false)
            }
        }
    }

#if canImport(UIKit)
    private func presentCameraCapture() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showCameraPicker = true
        } else {
            showCameraUnavailableAlert = true
        }
    }

    private func applyCapturedCoverPhoto(_ uiImage: UIImage) {
        coverPhotoPreview = Image(uiImage: uiImage)
        viewModel.applyCoverPhotoSelection(hasPhoto: true)
        isHikeNameFocused = true
    }
#endif

    private func bottomStartBar(bottomInset: CGFloat, horizontalPadding: CGFloat) -> some View {
        VStack(spacing: 12) {
            Text(viewModel.canStartHike ? "Ready to begin your hike" : "Give your hike a name to begin")
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))

            Button {
                Task {
                    let started = await viewModel.startHike()
                    if started {
                        onStartHike(viewModel.hikeName.trimmingCharacters(in: .whitespacesAndNewlines))
                    } else {
                        showStartErrorAlert = true
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if viewModel.isStarting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Start Hike")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(viewModel.canStartHike ? green : green.opacity(0.25))
                .clipShape(Capsule())
                .scaleEffect(viewModel.canStartHike ? 1 : 0.985)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: viewModel.canStartHike)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.canStartHike == false || viewModel.isStarting)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, max(12, bottomInset))
        .frame(maxWidth: .infinity)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(red: 232 / 255, green: 237 / 255, blue: 232 / 255))
                .frame(height: 1)
        }
    }
}

#if canImport(UIKit)
private struct CameraPhotoPicker: UIViewControllerRepresentable {
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
        private let parent: CameraPhotoPicker

        init(_ parent: CameraPhotoPicker) {
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

#Preview {
    NewHikeView()
}
