import Foundation
import Combine
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ActiveHikeViewModel: ObservableObject {
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var routepoints: [PendingRoutepoint] = []
    @Published private(set) var pictures: [PendingPicture] = []
    @Published private(set) var isActive: Bool = false
    @Published private(set) var errorMessage: String?
    @Published var recenterTick: Int = 0
    @Published var classificationResult: ClassificationResult?
    @Published var isClassifying: Bool = false

    let hikeTitle: String

    private var pollTask: Task<Void, Never>?

    init(hikeTitle: String) {
        self.hikeTitle = hikeTitle
    }

    deinit {
        pollTask?.cancel()
    }

    var distanceText: String {
        String(format: "%.1f km", distanceMeters / 1000.0)
    }

    var pictureCountText: String {
        "\(pictures.count) Pictures"
    }

    var elapsedText: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    func startObserving() {
        guard pollTask == nil else { return }
        refreshFromSession()

        pollTask = Task { [weak self] in
            while let self, Task.isCancelled == false {
                await MainActor.run {
                    self.refreshFromSession()
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stopHikeAndExit() async -> Bool {
        do {
            _ = try HikeSessionManager.shared.stopHike()
            Task.detached {
                await SyncManager.shared.syncPendingData()
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func recenterMap() {
        recenterTick += 1
    }

#if canImport(UIKit)
    func recordCapturedPicture(_ image: UIImage) async -> Bool {
        do {
            guard let imageData = image.jpegData(compressionQuality: 0.82) else {
                errorMessage = "Failed to process captured image."
                return false
            }

            let fileName = "\(UUID().uuidString).jpg"
            let fileURL = documentsDirectory().appendingPathComponent(fileName)
            try imageData.write(to: fileURL, options: .atomic)

            // Classify the plant if the model is ready
            var species: String?
            var speciesInfo: String?
            classificationResult = nil
            isClassifying = true
            if let cgImage = image.cgImage {
                let result = await PlantClassifier.shared.classify(image: cgImage)
                species = result?.speciesName
                speciesInfo = result?.speciesInfoJSON
                classificationResult = result
            }
            isClassifying = false

            let location = LocationTracker.shared.lastLocation
            try HikeSessionManager.shared.recordPicture(
                imagePath: fileURL.path,
                species: species,
                speciesInfo: speciesInfo,
                latitude: location?.coordinate.latitude,
                longitude: location?.coordinate.longitude
            )
            refreshFromSession()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
#endif

    private func refreshFromSession() {
        isActive = HikeSessionManager.shared.isActive
        elapsedSeconds = HikeSessionManager.shared.elapsedSeconds
        distanceMeters = HikeSessionManager.shared.distanceMeters
        routepoints = HikeSessionManager.shared.routepoints
        if let hikeLocalId = HikeSessionManager.shared.currentHikeLocalId {
            pictures = (try? LocalDatabase.shared.getPictures(forHikeLocalId: hikeLocalId)) ?? []
        } else {
            pictures = []
        }
    }

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
