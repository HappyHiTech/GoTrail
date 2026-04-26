// Sync/SyncManager.swift
import Foundation
import Network
import Supabase
import Combine

class SyncManager: ObservableObject {
    static let shared = SyncManager()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.gotrail.network")
    @Published var isConnected = false
    @Published var isSyncing = false

    private init() {}

    // MARK: - Start Monitoring

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isConnected = path.status == .satisfied
            }

            if path.status == .satisfied {
                print("[SyncManager] Internet connected — starting sync")
                Task { await self.syncPendingData() }
            } else {
                print("[SyncManager] Internet disconnected")
            }
        }
        monitor.start(queue: queue)
        print("[SyncManager] Network monitoring started")
    }

    // MARK: - Main Sync Function

    func syncPendingData() async {
        guard !isSyncing else {
            print("[SyncManager] Sync already in progress, skipping")
            return
        }

        guard let userId = try? await SupabaseManager.client.auth.session.user.id.uuidString else {
            print("[SyncManager] No logged in user, skipping sync")
            return
        }

        await MainActor.run { self.isSyncing = true }
        defer { Task { await MainActor.run { self.isSyncing = false } } }

        print("[SyncManager] Starting sync for user: \(userId)")

        do {
            let pendingHikes = try LocalDatabase.shared.getUnsyncedHikes(forUserId: userId)
            print("[SyncManager] Found \(pendingHikes.count) unsynced hikes")

            for hike in pendingHikes {
                await syncHike(hike, userId: userId)
            }

            print("[SyncManager] Sync complete")
        } catch {
            print("[SyncManager] Failed to fetch unsynced hikes: \(error)")
        }
    }

    // MARK: - Sync Single Hike

    private func syncHike(_ hike: PendingHike, userId: String) async {
        print("[SyncManager] Syncing hike: \(hike.localId)")

        do {
            // 1. Insert hike into Supabase
            struct HikeInsert: Encodable {
                let user_id: String
                let title: String
                let location: String?
                let date: String
                let distance_meters: Double
                let time_seconds: Int
            }

            let remoteHike: Hike = try await SupabaseManager.client
                .from("hikes")
                .insert(HikeInsert(
                    user_id: userId,
                    title: hike.title,
                    location: hike.location,
                    date: hike.date,
                    distance_meters: hike.distanceMeters,
                    time_seconds: hike.timeSeconds
                ))
                .select()
                .single()
                .execute()
                .value

            print("[SyncManager] Hike inserted — remote ID: \(remoteHike.id)")

            // 2. Sync routepoints
            let routepoints = try LocalDatabase.shared.getUnsyncedRoutepoints(forHikeLocalId: hike.localId)
            print("[SyncManager] Syncing \(routepoints.count) routepoints")

            if !routepoints.isEmpty {
                struct RoutepointInsert: Encodable {
                    let hike_id: String
                    let latitude: Double
                    let longitude: Double
                    let timestamp: String
                    let altitude: Double?
                }

                let inserts = routepoints.map {
                    RoutepointInsert(
                        hike_id: remoteHike.id.uuidString,
                        latitude: $0.latitude,
                        longitude: $0.longitude,
                        timestamp: $0.timestamp,
                        altitude: $0.altitude
                    )
                }

                try await SupabaseManager.client
                    .from("routepoints")
                    .insert(inserts)
                    .execute()

                try LocalDatabase.shared.markRoutepointsSynced(forHikeLocalId: hike.localId)
                print("[SyncManager] ✓ Routepoints synced")
            }

            // 3. Sync pictures
            let pictures = try LocalDatabase.shared.getUnsyncedPictures(forHikeLocalId: hike.localId)
            print("[SyncManager] Syncing \(pictures.count) pictures")

            var plantsSynced = 0
            for pic in pictures {
                let success = await syncPicture(pic, remoteHikeId: remoteHike.id.uuidString, userId: userId)
                if success && pic.species != nil { plantsSynced += 1 }
            }

            // 4. Update profile stats
            try await SupabaseManager.client.rpc(
                "increment_profile_stats",
                params: [
                    "p_user_id": AnyJSON.string(userId),
                    "p_distance": AnyJSON.double(hike.distanceMeters),
                    "p_time": AnyJSON.integer(hike.timeSeconds),
                    "p_plants": AnyJSON.integer(plantsSynced)
                ]
            ).execute()
            print("[SyncManager] ✓ Profile stats updated")

            // 5. Mark hike as synced locally
            try LocalDatabase.shared.markHikeSynced(hike.localId)
            print("[SyncManager] ✓ Hike marked as synced — \(hike.title)")

        } catch {
            print("[SyncManager] ✗ Failed to sync hike \(hike.localId): \(error)")
        }
    }

    // MARK: - Sync Single Picture

    private func syncPicture(_ pic: PendingPicture, remoteHikeId: String, userId: String) async -> Bool {
        do {
            // 1. Upload image to Supabase Storage
            let fileName = "\(pic.localId).jpg"
            let storagePath = "\(userId)/\(remoteHikeId)/\(fileName)"

            // Check if local file exists
            guard FileManager.default.fileExists(atPath: pic.localImagePath) else {
                print("[SyncManager] Image file not found: \(pic.localImagePath) — inserting row without image")
                // Still insert the picture row even if image is missing
                try await insertPictureRow(pic: pic, remoteHikeId: remoteHikeId, storagePath: nil)
                try LocalDatabase.shared.markPictureSynced(pic.localId)
                return true
            }

            let imageData = try Data(contentsOf: URL(fileURLWithPath: pic.localImagePath))

            try await SupabaseManager.client.storage
                .from("hike-images")
                .upload(
                    storagePath,
                    data: imageData,
                    options: FileOptions(contentType: "image/jpeg")
                )

            print("[SyncManager] ✓ Image uploaded — \(storagePath)")

            // 2. Insert picture row with storage path
            try await insertPictureRow(pic: pic, remoteHikeId: remoteHikeId, storagePath: storagePath)
            try LocalDatabase.shared.markPictureSynced(pic.localId)

            print("[SyncManager] ✓ Picture synced — species: \(pic.species ?? "unidentified")")
            return true

        } catch {
            print("[SyncManager] ✗ Failed to sync picture \(pic.localId): \(error)")
            return false
        }
    }

    // MARK: - Insert Picture Row

    private func insertPictureRow(pic: PendingPicture, remoteHikeId: String, storagePath: String?) async throws {
        struct PictureInsert: Encodable {
            let hike_id: String
            let species: String?
            let species_info: String?
            let image_url: String
            let taken_at: String
            let latitude: Double?
            let longitude: Double?
        }

        try await SupabaseManager.client
            .from("pictures")
            .insert(PictureInsert(
                hike_id: remoteHikeId,
                species: pic.species,
                species_info: pic.speciesInfo,
                image_url: storagePath ?? "pending",
                taken_at: pic.takenAt,
                latitude: pic.latitude,
                longitude: pic.longitude
            ))
            .execute()
    }
}


