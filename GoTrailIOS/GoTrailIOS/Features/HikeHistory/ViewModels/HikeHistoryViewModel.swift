import Foundation
import Combine

@MainActor
final class HikeHistoryViewModel: ObservableObject {
    @Published private(set) var hikes: [HikeCardModel] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isWaitingForNetwork = false
    @Published private(set) var errorMessage: String?

    private let queryService: QueryService

    init(queryService: QueryService = .shared) {
        self.queryService = queryService
    }

    var totalTrailCount: Int {
        hikes.count
    }

    var totalDistanceText: String {
        let totalDistance = hikes.reduce(0) { $0 + $1.distanceKm }
        return String(format: "%.1f km", totalDistance)
    }

    var totalPlantsText: String {
        let totalPlants = hikes.reduce(0) { $0 + $1.plantsFound }
        return "\(totalPlants)"
    }

    /// Strict server-truth refresh:
    /// 1. If offline, wait for connectivity.
    /// 2. Sync any pending local data to Supabase (waits for any in-flight sync too).
    /// 3. Fetch all hikes from Supabase and display.
    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            isWaitingForNetwork = false
        }

        if SyncManager.shared.isConnected == false {
            isWaitingForNetwork = true
            await waitForConnectivity()
            isWaitingForNetwork = false
        }

        await runSyncFully()
        await fetchFromSupabase()
    }

    private func waitForConnectivity() async {
        // Brief grace period in case the network monitor hasn't reported yet.
        try? await Task.sleep(nanoseconds: 500_000_000)

        while SyncManager.shared.isConnected == false {
            if Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    /// Runs sync to completion. The network monitor may auto-trigger a sync,
    /// causing `syncPendingData()` to no-op. We always wait for any running
    /// sync to finish, then trigger our own, then wait again — guaranteeing
    /// the latest local writes are uploaded before we fetch from Supabase.
    private func runSyncFully() async {
        await waitForSyncIdle()
        await SyncManager.shared.syncPendingData()
        await waitForSyncIdle()
    }

    private func waitForSyncIdle() async {
        while SyncManager.shared.isSyncing {
            if Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    private func fetchFromSupabase() async {
        do {
            let fetchedHikes = try await queryService.getHikes()
            var mappedHikes: [HikeCardModel] = []
            mappedHikes.reserveCapacity(fetchedHikes.count)

            for hike in fetchedHikes {
                let location = (hike.location?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                    ? (hike.location ?? "Unknown location")
                    : "Unknown location"
                let plantsFound = hike.pictures?.count ?? 0
                let coverImageURL = hike.coverImageUrl?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                var resolvedCoverURL: String?

                if let coverImageURL, coverImageURL.isEmpty == false {
                    if coverImageURL.lowercased().hasPrefix("http") {
                        resolvedCoverURL = coverImageURL
                    } else {
                        do {
                            let signedURL = try await queryService.getSignedUrl(storagePath: coverImageURL)
                            resolvedCoverURL = signedURL.absoluteString
                        } catch {
                            // Bad/expired path — keep loading the rest of history.
                            print("[HikeHistoryVM] Skipping invalid cover path \(coverImageURL): \(error)")
                            resolvedCoverURL = nil
                        }
                    }
                }

                mappedHikes.append(HikeCardModel(
                    id: hike.id,
                    title: hike.title,
                    location: location,
                    distanceKm: hike.distanceMeters / 1000.0,
                    plantsFound: plantsFound,
                    imageAssetName: nil,
                    imageURLString: resolvedCoverURL
                ))
            }
            hikes = mappedHikes
        } catch {
            // Keep existing data on transient failures so cards don't disappear.
            errorMessage = "Unable to load hike history right now."
            print("[HikeHistoryVM] Supabase fetch failed: \(error)")
        }
    }
}
