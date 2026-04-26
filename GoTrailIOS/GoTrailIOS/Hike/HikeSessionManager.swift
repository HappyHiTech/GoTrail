// Hike/HikeSessionManager.swift
import Foundation
import CoreLocation

class HikeSessionManager {
    static let shared = HikeSessionManager()

    // Current state
    private(set) var isActive = false
    private(set) var currentHikeLocalId: String?
    private(set) var elapsedSeconds: Int = 0
    private(set) var distanceMeters: Double = 0
    private(set) var pictureCount: Int = 0
    private(set) var routepoints: [PendingRoutepoint] = []

    private var timer: Timer?
    private var userId: String?
    private var startedAt: Date?
    private var lastAcceptedLocation: CLLocation?

    private init() {}

    // MARK: - Start Hike

    func startHike(title: String, location: String?, userId: String, coverImageLocalPath: String? = nil) throws -> String {
        guard !isActive else {
            throw HikeError.alreadyActive
        }

        // Defensive cleanup in case a stale timer exists.
        timer?.invalidate()
        timer = nil

        let localId = UUID().uuidString
        self.currentHikeLocalId = localId
        self.userId = userId
        self.isActive = true
        self.elapsedSeconds = 0
        self.startedAt = Date()
        self.distanceMeters = 0
        self.pictureCount = 0
        self.routepoints = []
        self.lastAcceptedLocation = nil

        // Save initial hike record to SQLite
        let hike = PendingHike(
            localId: localId,
            userId: userId,
            title: title,
            location: location,
            date: ISO8601DateFormatter().string(from: Date()),
            distanceMeters: 0,
            timeSeconds: 0,
            coverImageLocalPath: coverImageLocalPath
        )
        try LocalDatabase.shared.saveHike(hike)

        // Start timer using wall-clock elapsed time instead of +1 increments.
        let capturedLocalId = localId
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.syncElapsedFromClock()

            // Write to SQLite every 30 seconds
            if self.elapsedSeconds > 0 && self.elapsedSeconds % 30 == 0 {
                try? LocalDatabase.shared.updateHikeStats(
                    localId: capturedLocalId,
                    distanceMeters: self.distanceMeters,
                    timeSeconds: self.elapsedSeconds
                )
                print("[HikeSession] Auto-saved stats — \(self.elapsedSeconds)s, \(DistanceCalculator.formatDistance(self.distanceMeters))")
            }
        }

        // Start GPS
        LocationTracker.shared.startTracking { [weak self] location in
            self?.handleLocationUpdate(location)
        }

        print("[HikeSession] Started — ID: \(localId), title: \(title)")
        return localId
    }

    // MARK: - Handle GPS Update

    private func handleLocationUpdate(_ location: CLLocation) {
        guard let hikeId = currentHikeLocalId else { return }
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 65 else { return }

        if let lastAcceptedLocation {
            let dt = location.timestamp.timeIntervalSince(lastAcceptedLocation.timestamp)
            guard dt > 0 else { return }

            let segmentMeters = location.distance(from: lastAcceptedLocation)
            let impliedSpeed = segmentMeters / dt

            // Filter GPS drift and impossible hiking jumps.
            if segmentMeters < 2 { return }
            if impliedSpeed > 8 { return }
        }

        let point = PendingRoutepoint(
            localId: UUID().uuidString,
            hikeLocalId: hikeId,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: ISO8601DateFormatter().string(from: location.timestamp),
            altitude: location.altitude
        )

        // Incremental distance (after filtering noisy points).
        if let lastPoint = routepoints.last {
            let increment = DistanceCalculator.incrementalDistance(from: lastPoint, to: point)
            distanceMeters += increment
        }

        routepoints.append(point)
        lastAcceptedLocation = location

        // Write to SQLite
        do {
            try LocalDatabase.shared.saveRoutepoint(point)
            print("[HikeSession] Routepoint saved — lat: \(String(format: "%.4f", point.latitude)), lon: \(String(format: "%.4f", point.longitude)), total: \(DistanceCalculator.formatDistance(distanceMeters))")
        } catch {
            print("[HikeSession] Failed to save routepoint: \(error)")
        }
    }

    // MARK: - Record Picture

    func recordPicture(
        imagePath: String,
        species: String?,
        speciesInfo: String?,
        latitude: Double?,
        longitude: Double?
    ) throws {
        guard let hikeId = currentHikeLocalId else {
            throw HikeError.noActiveHike
        }

        let pic = PendingPicture(
            localId: UUID().uuidString,
            hikeLocalId: hikeId,
            localImagePath: imagePath,
            species: species,
            speciesInfo: speciesInfo,
            latitude: latitude,
            longitude: longitude,
            takenAt: ISO8601DateFormatter().string(from: Date())
        )

        try LocalDatabase.shared.savePicture(pic)
        pictureCount += 1

        print("[HikeSession] Picture recorded — species: \(species ?? "unidentified"), total: \(pictureCount)")
    }

    // MARK: - Stop Hike

    @discardableResult
    func stopHike() throws -> PendingHike {
        guard let hikeId = currentHikeLocalId else {
            throw HikeError.noActiveHike
        }

        // Stop timer and GPS
        timer?.invalidate()
        timer = nil
        syncElapsedFromClock()
        LocationTracker.shared.stopTracking()

        // Final stats write (best effort). A transient DB write failure should not trap users in an active hike.
        do {
            try LocalDatabase.shared.updateHikeStats(
                localId: hikeId,
                distanceMeters: distanceMeters,
                timeSeconds: elapsedSeconds
            )
        } catch {
            print("[HikeSession] Warning: failed final stats write for \(hikeId): \(error)")
        }

        let summary = PendingHike(
            localId: hikeId,
            userId: userId ?? "",
            title: "",
            location: nil,
            date: "",
            distanceMeters: distanceMeters,
            timeSeconds: elapsedSeconds
        )

        print("""
        [HikeSession] Stopped —
          Duration: \(DistanceCalculator.formatDuration(elapsedSeconds))
          Distance: \(DistanceCalculator.formatDistance(distanceMeters))
          Pictures: \(pictureCount)
          Routepoints: \(routepoints.count)
        """)

        // Reset state
        isActive = false
        currentHikeLocalId = nil
        userId = nil
        startedAt = nil
        lastAcceptedLocation = nil
        elapsedSeconds = 0
        distanceMeters = 0
        pictureCount = 0
        routepoints = []

        return summary
    }

    // MARK: - Status

    func printStatus() {
        if isActive {
            print("""
            [HikeSession] Status:
              Active: true
              Hike ID: \(currentHikeLocalId ?? "none")
              Elapsed: \(DistanceCalculator.formatDuration(elapsedSeconds))
              Distance: \(DistanceCalculator.formatDistance(distanceMeters))
              Pictures: \(pictureCount)
              Routepoints: \(routepoints.count)
            """)
        } else {
            print("[HikeSession] No active hike")
        }
    }

    private func syncElapsedFromClock() {
        guard let startedAt else { return }
        let elapsed = Int(Date().timeIntervalSince(startedAt).rounded(.down))
        elapsedSeconds = max(0, elapsed)
    }
}

// MARK: - Errors

enum HikeError: Error, LocalizedError, Equatable {
    case alreadyActive
    case noActiveHike

    var errorDescription: String? {
        switch self {
        case .alreadyActive: return "A hike is already in progress"
        case .noActiveHike: return "No active hike"
        }
    }
}


