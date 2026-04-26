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
    private var isMonitoring = false

    private init() {}

    // MARK: - Start Monitoring

    func startMonitoring() {
        guard isMonitoring == false else { return }
        isMonitoring = true

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

        guard let userIdRaw = try? await SupabaseManager.client.auth.session.user.id.uuidString else {
            print("[SyncManager] No logged in user, skipping sync")
            return
        }
        let userId = userIdRaw.lowercased()

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
        print("[SyncManager] === Syncing hike \(hike.localId) (\(hike.title)) ===")

        // 1. Insert or reuse remote hike id ---------------------------------
        let remoteHikeId: String
        do {
            remoteHikeId = try await ensureRemoteHike(hike, userId: userId)
        } catch {
            print("[SyncManager] ✗ Failed to insert/resolve remote hike for \(hike.localId): \(error)")
            return
        }
        print("[SyncManager] Remote hike id: \(remoteHikeId)")

        // 2. Sync routepoints (idempotent — only unsynced rows are pushed) --
        do {
            try await syncRoutepoints(hike: hike, remoteHikeId: remoteHikeId)
        } catch {
            print("[SyncManager] ✗ Routepoints sync failed for \(hike.localId): \(error)")
            // Routepoints failing should not block pictures from syncing.
        }

        // 3. Sync cover image ----------------------------------------------
        await syncCoverImage(hike: hike, remoteHikeId: remoteHikeId, userId: userId)

        // 4. Sync pictures --------------------------------------------------
        let pendingPictures: [PendingPicture]
        do {
            pendingPictures = try LocalDatabase.shared.getUnsyncedPictures(forHikeLocalId: hike.localId)
        } catch {
            print("[SyncManager] ✗ Failed to load unsynced pictures for \(hike.localId): \(error)")
            return
        }
        print("[SyncManager] Pending pictures to sync: \(pendingPictures.count)")

        var plantsSynced = 0
        var transientFailures = 0
        for pic in pendingPictures {
            let result = await syncPicture(pic, remoteHikeId: remoteHikeId, userId: userId)
            switch result {
            case .synced:
                if pic.species != nil { plantsSynced += 1 }
            case .skippedMissingFile:
                break
            case .failed:
                transientFailures += 1
            }
        }

        // 5. Decide whether the hike is fully done. ------------------------
        // Only mark hike synced when no pictures are still in transient-failure
        // state. Permanently-skipped (missing file) and successfully-synced
        // pictures are both already marked synced=true in the local DB, so
        // `countUnsyncedPictures` here is a strict definition of "still owed".
        let remainingUnsynced: Int
        do {
            remainingUnsynced = try LocalDatabase.shared.countUnsyncedPictures(forHikeLocalId: hike.localId)
        } catch {
            remainingUnsynced = transientFailures
            print("[SyncManager] ⚠︎ Could not count unsynced pictures for \(hike.localId): \(error)")
        }

        if remainingUnsynced > 0 {
            print("[SyncManager] ⚠︎ \(remainingUnsynced) picture(s) still pending — leaving hike \(hike.localId) unsynced for retry")
            return
        }

        // 6. Update profile stats (best effort). ---------------------------
        do {
            try await SupabaseManager.client.rpc(
                "increment_profile_stats",
                params: [
                    "p_user_id": AnyJSON.string(userId),
                    "p_distance": AnyJSON.double(hike.distanceMeters),
                    "p_time": AnyJSON.integer(hike.timeSeconds),
                    "p_plants": AnyJSON.integer(plantsSynced)
                ]
            ).execute()
            print("[SyncManager] ✓ Profile stats updated (+\(plantsSynced) plants)")
        } catch {
            print("[SyncManager] ⚠︎ Profile stats update failed: \(error)")
        }

        // 7. Mark hike fully synced. ---------------------------------------
        do {
            try LocalDatabase.shared.markHikeSynced(hike.localId)
            print("[SyncManager] ✓ Hike marked as synced — \(hike.title)")
        } catch {
            print("[SyncManager] ⚠︎ Failed to mark hike synced: \(error)")
        }
    }

    // MARK: - Hike row insert (idempotent)

    /// Returns the Supabase-side id for this pending hike, inserting a row if
    /// we have not done so already. After the first call we persist the
    /// returned id locally so subsequent calls reuse it.
    private func ensureRemoteHike(_ hike: PendingHike, userId: String) async throws -> String {
        if let existing = hike.remoteHikeId, existing.isEmpty == false {
            print("[SyncManager] Reusing existing remote hike id for \(hike.localId)")
            return existing
        }

        struct HikeInsert: Encodable {
            let user_id: String
            let title: String
            let location: String?
            let date: String
            let distance_meters: Double
            let time_seconds: Int
            let cover_image_url: String?
        }

        let remoteHike: Hike = try await SupabaseManager.client
            .from("hikes")
            .insert(HikeInsert(
                user_id: userId,
                title: hike.title,
                location: hike.location,
                date: hike.date,
                distance_meters: hike.distanceMeters,
                time_seconds: hike.timeSeconds,
                cover_image_url: nil
            ))
            .select()
            .single()
            .execute()
            .value

        let remoteId = remoteHike.id.uuidString
        try LocalDatabase.shared.setRemoteHikeId(localId: hike.localId, remoteHikeId: remoteId)
        print("[SyncManager] ✓ Hike inserted — remote id \(remoteId) stored locally")
        return remoteId
    }

    // MARK: - Routepoints

    private func syncRoutepoints(hike: PendingHike, remoteHikeId: String) async throws {
        let routepoints = try LocalDatabase.shared.getUnsyncedRoutepoints(forHikeLocalId: hike.localId)
        guard routepoints.isEmpty == false else {
            print("[SyncManager] No routepoints to sync for \(hike.localId)")
            return
        }
        print("[SyncManager] Syncing \(routepoints.count) routepoints")

        struct RoutepointInsert: Encodable {
            let hike_id: String
            let latitude: Double
            let longitude: Double
            let timestamp: String
            let altitude: Double?
        }

        let inserts = routepoints.map {
            RoutepointInsert(
                hike_id: remoteHikeId,
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

    // MARK: - Cover image

    private func syncCoverImage(hike: PendingHike, remoteHikeId: String, userId: String) async {
        guard let coverPath = hike.coverImageLocalPath else { return }
        guard FileManager.default.fileExists(atPath: coverPath) else {
            print("[SyncManager] Cover photo missing on disk (\(coverPath)) — skipping")
            return
        }

        do {
            let coverData = try Data(contentsOf: URL(fileURLWithPath: coverPath))
            let coverFileName = "cover_\(remoteHikeId.lowercased()).jpg"
            let coverStoragePath = "\(userId.lowercased())/\(remoteHikeId.lowercased())/\(coverFileName)"

            // upsert: true so retries don't fail with a 409 "object exists" error.
            try await SupabaseManager.client.storage
                .from("hike-images")
                .upload(
                    coverStoragePath,
                    data: coverData,
                    options: FileOptions(contentType: "image/jpeg", upsert: true)
                )

            try await SupabaseManager.client
                .from("hikes")
                .update(["cover_image_url": coverStoragePath])
                .eq("id", value: remoteHikeId)
                .execute()

            print("[SyncManager] ✓ Cover image uploaded — \(coverStoragePath)")
        } catch {
            print("[SyncManager] ✗ Cover image upload failed: \(error)")
        }
    }

    // MARK: - Sync Single Picture

    private enum PictureSyncResult {
        case synced
        case skippedMissingFile
        case failed
    }

    private func syncPicture(_ pic: PendingPicture, remoteHikeId: String, userId: String) async -> PictureSyncResult {
        let fileName = "\(pic.localId.lowercased()).jpg"
        let storagePath = "\(userId.lowercased())/\(remoteHikeId.lowercased())/\(fileName)"

        // The recorded file path can become stale if the app container changes
        // between runs (e.g. reinstall). In that case we cannot recover the
        // image bytes — mark synced so we don't loop forever on this row.
        guard FileManager.default.fileExists(atPath: pic.localImagePath) else {
            print("[SyncManager] ⚠︎ Picture \(pic.localId) — local file missing at \(pic.localImagePath); marking synced to prevent retry loop")
            try? LocalDatabase.shared.markPictureSynced(pic.localId)
            return .skippedMissingFile
        }

        let imageData: Data
        do {
            imageData = try Data(contentsOf: URL(fileURLWithPath: pic.localImagePath))
        } catch {
            print("[SyncManager] ✗ Picture \(pic.localId) — failed to read bytes: \(error)")
            return .failed
        }

        // 1. Upload image to Supabase Storage (upsert so retries are idempotent).
        do {
            try await SupabaseManager.client.storage
                .from("hike-images")
                .upload(
                    storagePath,
                    data: imageData,
                    options: FileOptions(contentType: "image/jpeg", upsert: true)
                )
            print("[SyncManager] ✓ Picture image uploaded — \(storagePath)")
        } catch {
            print("[SyncManager] ✗ Picture \(pic.localId) — storage upload failed: \(error)")
            return .failed
        }

        // 2. Insert picture row. We use a deterministic id (= local id) plus
        //    upsert so a successful upload + failed insert can be retried
        //    safely without producing duplicates.
        do {
            try await upsertPictureRow(
                pic: pic,
                remoteHikeId: remoteHikeId,
                storagePath: storagePath
            )
        } catch {
            print("[SyncManager] ✗ Picture \(pic.localId) — DB insert failed: \(error)")
            return .failed
        }

        // 3. Persist locally that this picture is done.
        do {
            try LocalDatabase.shared.markPictureSynced(pic.localId)
        } catch {
            print("[SyncManager] ⚠︎ Picture \(pic.localId) — could not mark synced locally: \(error)")
        }

        print("[SyncManager] ✓ Picture synced — species: \(pic.species ?? "unidentified")")
        return .synced
    }

    // MARK: - Insert Picture Row

    private func upsertPictureRow(pic: PendingPicture, remoteHikeId: String, storagePath: String) async throws {
        struct PictureUpsert: Encodable {
            let id: String
            let hike_id: String
            let species: String?
            let species_info: String?
            let image_url: String
            let taken_at: String
            let latitude: Double?
            let longitude: Double?
        }

        let row = PictureUpsert(
            id: pic.localId.lowercased(),
            hike_id: remoteHikeId,
            species: pic.species,
            species_info: pic.speciesInfo,
            image_url: storagePath,
            taken_at: pic.takenAt,
            latitude: pic.latitude,
            longitude: pic.longitude
        )

        try await SupabaseManager.client
            .from("pictures")
            .upsert(row, onConflict: "id")
            .execute()
    }
}
