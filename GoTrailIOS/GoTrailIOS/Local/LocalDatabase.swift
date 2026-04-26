// Local/LocalDatabase.swift
import SQLite
import Foundation

class LocalDatabase {
    static let shared = LocalDatabase()

    private var db: Connection!
    private let dbQueue = DispatchQueue(label: "com.gotrail.localdatabase.queue")

    // Table definitions
    private let pendingHikes = Table("pending_hikes")
    private let pendingPictures = Table("pending_pictures")
    private let pendingRoutepoints = Table("pending_routepoints")

    // Shared columns
    private let colLocalId = Expression<String>("local_id")
    private let colSynced = Expression<Bool>("synced")
    private let colHikeLocalId = Expression<String>("hike_local_id")

    // Hike columns
    private let colUserId = Expression<String>("user_id")
    private let colTitle = Expression<String>("title")
    private let colLocation = Expression<String?>("location")
    private let colDate = Expression<String>("date")
    private let colDistanceMeters = Expression<Double>("distance_meters")
    private let colTimeSeconds = Expression<Int>("time_seconds")
    private let colCoverImageLocalPath = Expression<String?>("cover_image_local_path")
    private let colRemoteHikeId = Expression<String?>("remote_hike_id")

    // Picture columns
    private let colLocalImagePath = Expression<String>("local_image_path")
    private let colSpecies = Expression<String?>("species")
    private let colSpeciesInfo = Expression<String?>("species_info")
    private let colLatitude = Expression<Double?>("latitude")
    private let colLongitude = Expression<Double?>("longitude")
    private let colTakenAt = Expression<String>("taken_at")

    // Routepoint columns
    private let colRpLatitude = Expression<Double>("rp_latitude")
    private let colRpLongitude = Expression<Double>("rp_longitude")
    private let colRpTimestamp = Expression<String>("rp_timestamp")
    private let colAltitude = Expression<Double?>("altitude")

    private init() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(
                .documentDirectory, .userDomainMask, true
            ).first!
            db = try Connection("\(path)/trailguard.sqlite3")
            db.busyTimeout = 5
            try db.execute("PRAGMA journal_mode=WAL;")
            try db.execute("PRAGMA synchronous=NORMAL;")
            try createTables()
            print("[LocalDatabase] Initialized at \(path)/trailguard.sqlite3")
        } catch {
            fatalError("LocalDatabase init failed: \(error)")
        }
    }

    private func createTables() throws {
        try db.run(pendingHikes.create(ifNotExists: true) { t in
            t.column(colLocalId, primaryKey: true)
            t.column(colUserId)
            t.column(colTitle)
            t.column(colLocation)
            t.column(colDate)
            t.column(colDistanceMeters, defaultValue: 0)
            t.column(colTimeSeconds, defaultValue: 0)
            t.column(colSynced, defaultValue: false)
        })

        try db.run(pendingPictures.create(ifNotExists: true) { t in
            t.column(colLocalId, primaryKey: true)
            t.column(colHikeLocalId)
            t.column(colLocalImagePath)
            t.column(colSpecies)
            t.column(colSpeciesInfo)
            t.column(colLatitude)
            t.column(colLongitude)
            t.column(colTakenAt)
            t.column(colSynced, defaultValue: false)
        })

        try db.run(pendingRoutepoints.create(ifNotExists: true) { t in
            t.column(colLocalId, primaryKey: true)
            t.column(colHikeLocalId)
            t.column(colRpLatitude)
            t.column(colRpLongitude)
            t.column(colRpTimestamp)
            t.column(colAltitude)
            t.column(colSynced, defaultValue: false)
        })

        // Migrations: add columns added after the initial schema.
        let hikeColumns = try db.prepare("PRAGMA table_info(pending_hikes)").map { row in
            row[1] as? String ?? ""
        }
        if !hikeColumns.contains("cover_image_local_path") {
            try db.execute("ALTER TABLE pending_hikes ADD COLUMN cover_image_local_path TEXT")
        }
        if !hikeColumns.contains("remote_hike_id") {
            try db.execute("ALTER TABLE pending_hikes ADD COLUMN remote_hike_id TEXT")
        }

        print("[LocalDatabase] Tables created successfully")
    }

    // MARK: - Hikes

    func saveHike(_ hike: PendingHike) throws {
        try dbQueue.sync {
            try db.run(pendingHikes.insert(
                colLocalId <- hike.localId,
                colUserId <- hike.userId,
                colTitle <- hike.title,
                colLocation <- hike.location,
                colDate <- hike.date,
                colDistanceMeters <- hike.distanceMeters,
                colTimeSeconds <- hike.timeSeconds,
                colCoverImageLocalPath <- hike.coverImageLocalPath,
                colSynced <- false
            ))
            print("[LocalDatabase] Saved hike: \(hike.localId)")
        }
    }

    func updateHikeStats(localId: String, distanceMeters: Double, timeSeconds: Int) throws {
        try dbQueue.sync {
            let hike = pendingHikes.filter(colLocalId == localId)
            try db.run(hike.update(
                colDistanceMeters <- distanceMeters,
                colTimeSeconds <- timeSeconds
            ))
            print("[LocalDatabase] Updated hike stats: \(localId) — \(distanceMeters)m, \(timeSeconds)s")
        }
    }

    func getUnsyncedHikes(forUserId userId: String) throws -> [PendingHike] {
        try dbQueue.sync {
            // Legacy rows can have user_id casing mismatches; filter in Swift using case-insensitive compare.
            let query = pendingHikes.filter(colSynced == false)
            let rows = try db.prepare(query).map { row in
                PendingHike(
                    localId: row[colLocalId],
                    userId: row[colUserId],
                    title: row[colTitle],
                    location: row[colLocation],
                    date: row[colDate],
                    distanceMeters: row[colDistanceMeters],
                    timeSeconds: row[colTimeSeconds],
                    coverImageLocalPath: row[colCoverImageLocalPath],
                    remoteHikeId: row[colRemoteHikeId]
                )
            }
            return rows.filter { $0.userId.caseInsensitiveCompare(userId) == .orderedSame }
        }
    }

    func getAllHikes() throws -> [PendingHike] {
        try dbQueue.sync {
            return try db.prepare(pendingHikes).map { row in
                PendingHike(
                    localId: row[colLocalId],
                    userId: row[colUserId],
                    title: row[colTitle],
                    location: row[colLocation],
                    date: row[colDate],
                    distanceMeters: row[colDistanceMeters],
                    timeSeconds: row[colTimeSeconds],
                    coverImageLocalPath: row[colCoverImageLocalPath],
                    remoteHikeId: row[colRemoteHikeId]
                )
            }
        }
    }

    func markHikeSynced(_ localId: String) throws {
        try dbQueue.sync {
            let hike = pendingHikes.filter(colLocalId == localId)
            try db.run(hike.update(colSynced <- true))
        }
    }

    /// Persists the Supabase-side hike id after a successful insert so that
    /// later sync attempts can resume picture/routepoint uploads without
    /// creating a duplicate hike row.
    func setRemoteHikeId(localId: String, remoteHikeId: String) throws {
        try dbQueue.sync {
            let hike = pendingHikes.filter(colLocalId == localId)
            try db.run(hike.update(colRemoteHikeId <- remoteHikeId))
        }
    }

    // MARK: - Pictures

    func savePicture(_ pic: PendingPicture) throws {
        try dbQueue.sync {
            try db.run(pendingPictures.insert(
                colLocalId <- pic.localId,
                colHikeLocalId <- pic.hikeLocalId,
                colLocalImagePath <- pic.localImagePath,
                colSpecies <- pic.species,
                colSpeciesInfo <- pic.speciesInfo,
                colLatitude <- pic.latitude,
                colLongitude <- pic.longitude,
                colTakenAt <- pic.takenAt,
                colSynced <- false
            ))
            print("[LocalDatabase] Saved picture: \(pic.localId)")
        }
    }

    func getUnsyncedPictures(forHikeLocalId id: String) throws -> [PendingPicture] {
        try dbQueue.sync {
            let query = pendingPictures.filter(colHikeLocalId == id && colSynced == false)
            return try db.prepare(query).map { row in
                PendingPicture(
                    localId: row[colLocalId],
                    hikeLocalId: row[colHikeLocalId],
                    localImagePath: row[colLocalImagePath],
                    species: row[colSpecies],
                    speciesInfo: row[colSpeciesInfo],
                    latitude: row[colLatitude],
                    longitude: row[colLongitude],
                    takenAt: row[colTakenAt]
                )
            }
        }
    }

    func getPictures(forHikeLocalId id: String) throws -> [PendingPicture] {
        try dbQueue.sync {
            let query = pendingPictures
                .filter(colHikeLocalId == id)
                .order(colTakenAt.asc)
            return try db.prepare(query).map { row in
                PendingPicture(
                    localId: row[colLocalId],
                    hikeLocalId: row[colHikeLocalId],
                    localImagePath: row[colLocalImagePath],
                    species: row[colSpecies],
                    speciesInfo: row[colSpeciesInfo],
                    latitude: row[colLatitude],
                    longitude: row[colLongitude],
                    takenAt: row[colTakenAt]
                )
            }
        }
    }

    func markPictureSynced(_ localId: String) throws {
        try dbQueue.sync {
            let pic = pendingPictures.filter(colLocalId == localId)
            try db.run(pic.update(colSynced <- true))
        }
    }

    func countUnsyncedPictures(forHikeLocalId id: String) throws -> Int {
        try dbQueue.sync {
            let query = pendingPictures.filter(colHikeLocalId == id && colSynced == false)
            return try db.scalar(query.count)
        }
    }

    // MARK: - Routepoints

    func saveRoutepoint(_ point: PendingRoutepoint) throws {
        try dbQueue.sync {
            try db.run(pendingRoutepoints.insert(
                colLocalId <- point.localId,
                colHikeLocalId <- point.hikeLocalId,
                colRpLatitude <- point.latitude,
                colRpLongitude <- point.longitude,
                colRpTimestamp <- point.timestamp,
                colAltitude <- point.altitude,
                colSynced <- false
            ))
        }
    }

    func getRoutepoints(forHikeLocalId id: String) throws -> [PendingRoutepoint] {
        try dbQueue.sync {
            let query = pendingRoutepoints
                .filter(colHikeLocalId == id)
                .order(colRpTimestamp.asc)
            return try db.prepare(query).map { row in
                PendingRoutepoint(
                    localId: row[colLocalId],
                    hikeLocalId: row[colHikeLocalId],
                    latitude: row[colRpLatitude],
                    longitude: row[colRpLongitude],
                    timestamp: row[colRpTimestamp],
                    altitude: row[colAltitude]
                )
            }
        }
    }

    func getUnsyncedRoutepoints(forHikeLocalId id: String) throws -> [PendingRoutepoint] {
        try dbQueue.sync {
            let query = pendingRoutepoints.filter(colHikeLocalId == id && colSynced == false)
            return try db.prepare(query).map { row in
                PendingRoutepoint(
                    localId: row[colLocalId],
                    hikeLocalId: row[colHikeLocalId],
                    latitude: row[colRpLatitude],
                    longitude: row[colRpLongitude],
                    timestamp: row[colRpTimestamp],
                    altitude: row[colAltitude]
                )
            }
        }
    }

    func markRoutepointsSynced(forHikeLocalId id: String) throws {
        try dbQueue.sync {
            let points = pendingRoutepoints.filter(colHikeLocalId == id)
            try db.run(points.update(colSynced <- true))
        }
    }
}

