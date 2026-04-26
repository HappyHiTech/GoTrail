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
    private var pictureTasks: [UUID: Task<Void, Never>] = [:]

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
        errorMessage = nil
        // Wait for any in-flight classification tasks to finish so the
        // pictures (with their species, if any) are fully persisted to local
        // SQLite *before* we run sync. Otherwise, slow ML inference racing
        // against `stopHike` could leave pictures in a half-saved state and
        // they would never reach Supabase.
        await waitForPendingPictureTasks()
        do {
            _ = try HikeSessionManager.shared.stopHike()
            await SyncManager.shared.syncPendingData()
            return true
        } catch {
            if let hikeError = error as? HikeError, hikeError == .noActiveHike {
                return true
            }
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func waitForPendingPictureTasks() async {
        let tasks = pictureTasks.values
        guard tasks.isEmpty == false else { return }
        for task in tasks {
            _ = await task.value
        }
        pictureTasks.removeAll()
    }

    func recenterMap() {
        recenterTick += 1
    }

    func clearError() {
        errorMessage = nil
    }

#if canImport(UIKit)
    /// Kicks off picture persistence + classification as a tracked Task.
    /// `stopHikeAndExit` awaits these tasks before triggering sync so the
    /// picture is durable in SQLite by the time we upload to Supabase.
    func startCapturingPicture(_ image: UIImage) {
        let taskId = UUID()
        let task = Task { [weak self] in
            _ = await self?.recordCapturedPicture(image)
            await self?.removePictureTask(taskId)
        }
        pictureTasks[taskId] = task
    }

    private func removePictureTask(_ id: UUID) {
        pictureTasks.removeValue(forKey: id)
    }

    /// Captures a picture during the active hike. We persist the picture to
    /// the local DB *before* running classification. Classification is slow
    /// (on-device ML), and if the user ends the hike while it's still in
    /// flight the picture would otherwise be lost — `recordPicture` would
    /// fail with `noActiveHike` and never reach SQLite. By saving up front
    /// we guarantee the picture is queued for sync regardless of timing.
    /// The species fields are filled in later via `updatePictureSpecies`.
    func recordCapturedPicture(_ image: UIImage) async -> Bool {
        errorMessage = nil

        // 1. Snapshot the active hike id NOW. Even if `stopHike` runs while we
        //    classify, we already know which hike this picture belongs to.
        guard let hikeLocalId = HikeSessionManager.shared.currentHikeLocalId else {
            errorMessage = "No active hike."
            return false
        }

        do {
            guard let imageData = image.jpegData(compressionQuality: 0.82) else {
                errorMessage = "Failed to process captured image."
                return false
            }

            let fileName = "\(UUID().uuidString).jpg"
            let fileURL = documentsDirectory().appendingPathComponent(fileName)
            try imageData.write(to: fileURL, options: .atomic)

            let location = LocationTracker.shared.lastLocation

            // 2. Save to local DB immediately with no species yet. This is the
            //    critical fix — the picture is durable from this point on.
            let pictureLocalId = try HikeSessionManager.shared.recordPicture(
                forHikeLocalId: hikeLocalId,
                imagePath: fileURL.path,
                species: nil,
                speciesInfo: nil,
                latitude: location?.coordinate.latitude,
                longitude: location?.coordinate.longitude
            )
            refreshFromSession()

            // 3. Classify (slow). Failures here just mean the picture stays
            //    unidentified — it still uploads with no species.
            classificationResult = nil
            isClassifying = true
            let result = await PlantClassifier.shared.classify(image: image)
            classificationResult = result
            isClassifying = false

            // 4. Backfill species onto the already-persisted row.
            if let result {
                do {
                    try LocalDatabase.shared.updatePictureSpecies(
                        localId: pictureLocalId,
                        species: result.speciesName,
                        speciesInfo: result.speciesInfoJSON
                    )
                    refreshFromSession()
                } catch {
                    print("[ActiveHikeVM] Could not backfill species for \(pictureLocalId): \(error)")
                }
            }

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
            do {
                pictures = try LocalDatabase.shared.getPictures(forHikeLocalId: hikeLocalId)
            } catch {
                // Keep the previous in-memory pictures list if SQLite has a transient lock.
                print("[ActiveHikeVM] Warning: failed to refresh pictures for hike \(hikeLocalId): \(error)")
            }
        } else {
            pictures = []
        }
    }

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
