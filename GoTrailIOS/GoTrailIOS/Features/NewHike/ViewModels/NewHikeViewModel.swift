import Foundation
import Combine

@MainActor
final class NewHikeViewModel: ObservableObject {
    @Published var hikeName = ""
    @Published var hasCoverPhoto = false
    @Published var didSkipCoverPhoto = false
    @Published var locationName = "Olympic NP, WA"
    @Published var locationSubtitle = "Washington, United States"
    @Published var locationAccuracyMeters = 3
    @Published var isStarting = false

    var canStartHike: Bool {
        hikeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func toggleMockCoverPhoto() {
        hasCoverPhoto.toggle()
        if hasCoverPhoto {
            didSkipCoverPhoto = false
        }
    }

    func skipCoverPhoto() {
        hasCoverPhoto = false
        didSkipCoverPhoto = true
    }

    func addCoverPhotoAfterSkip() {
        hasCoverPhoto = true
        didSkipCoverPhoto = false
    }

    func applyCoverPhotoSelection(hasPhoto: Bool) {
        hasCoverPhoto = hasPhoto
        if hasPhoto {
            didSkipCoverPhoto = false
        }
    }

    func startHike() async {
        guard canStartHike else { return }
        isStarting = true
        defer { isStarting = false }
        try? await Task.sleep(nanoseconds: 400_000_000)
    }
}
