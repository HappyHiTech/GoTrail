import Foundation
import Combine

/// Where the bytes for a single picture live right now.
/// Local-first: if we have the original JPEG on this device we render it
/// directly (instant, no network), otherwise we resolve a signed Supabase URL.
enum PictureImageSource: Equatable {
    case localFile(path: String)
    case remote(URL)
}

@MainActor
final class HikeDetailViewModel: ObservableObject {
    @Published private(set) var hike: Hike?
    @Published private(set) var pictures: [Picture] = []
    @Published private(set) var routepoints: [Routepoint] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var selectedPictureID: UUID?
    @Published private(set) var imageSources: [UUID: PictureImageSource] = [:]

    private let hikeId: UUID
    private let queryService: QueryService

    init(hikeId: UUID, queryService: QueryService = .shared) {
        self.hikeId = hikeId
        self.queryService = queryService
    }

    // MARK: - Display helpers

    var titleText: String {
        hike?.title ?? "Hike"
    }

    var locationText: String {
        let trimmed = hike?.location?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed! : "Unknown location"
    }

    var distanceText: String {
        let meters = hike?.distanceMeters ?? 0
        return String(format: "%.1f km", meters / 1000.0)
    }

    var durationText: String {
        let seconds = hike?.timeSeconds ?? 0
        if seconds <= 0 { return "0m" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var plantsText: String {
        "\(pictures.count)"
    }

    var dateText: String {
        guard let raw = hike?.date else { return "-" }
        if let parsed = Self.serverDateFormatter.date(from: raw) ?? Self.serverDateWithoutFractionFormatter.date(from: raw) {
            return Self.displayDateFormatter.string(from: parsed)
        }
        return raw
    }

    var sortedPictures: [Picture] {
        pictures.sorted { $0.takenAt < $1.takenAt }
    }

    var selectedPicture: Picture? {
        guard let selectedPictureID else { return sortedPictures.first }
        return sortedPictures.first { $0.id == selectedPictureID } ?? sortedPictures.first
    }

    func selectPicture(_ pictureID: UUID) {
        selectedPictureID = pictureID
    }

    func imageSource(for picture: Picture) -> PictureImageSource? {
        imageSources[picture.id]
    }

    /// Backwards compatibility for callers still expecting a URL. Returns a
    /// `file://` URL for local pictures, or the resolved signed URL for
    /// remote ones.
    func resolvedURL(for picture: Picture) -> URL? {
        switch imageSources[picture.id] {
        case .localFile(let path):
            return URL(fileURLWithPath: path)
        case .remote(let url):
            return url
        case .none:
            return nil
        }
    }

    // MARK: - Loading

    /// Two-phase load:
    /// 1. Local first — pull pictures + routepoints out of SQLite immediately
    ///    so the user never sees an empty detail page for a hike they just
    ///    finished. Pictures render straight from the on-disk JPEG.
    /// 2. Remote merge — fetch the hike from Supabase to pick up the
    ///    canonical title/distance/duration plus any pictures that came from
    ///    a different device. Local sources are preserved; only missing
    ///    pictures get a signed URL resolved.
    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        loadLocalIfAvailable()
        await mergeRemote()

        if selectedPictureID == nil {
            selectedPictureID = sortedPictures.first?.id
        }

        let identified = pictures.filter { ($0.species?.isEmpty == false) }.count
        print("[HikeDetailVM] Loaded hike \(hike?.title ?? "(unknown)") — \(pictures.count) pictures (\(identified) with species), \(routepoints.count) routepoints")
    }

    /// Reads from local SQLite. Best effort — if anything fails we silently
    /// fall back to whatever Supabase returns next.
    private func loadLocalIfAvailable() {
        let allLocalHikes = (try? LocalDatabase.shared.getAllHikes()) ?? []
        let target = hikeId.uuidString.lowercased()
        guard let localHike = allLocalHikes.first(where: {
            ($0.remoteHikeId?.lowercased() ?? "") == target
        }) else {
            return
        }

        let localPics = (try? LocalDatabase.shared.getPictures(forHikeLocalId: localHike.localId)) ?? []
        let localRoutepoints = (try? LocalDatabase.shared.getRoutepoints(forHikeLocalId: localHike.localId)) ?? []

        // Synthesize a stub Hike from the local row so the summary card still
        // has data to display before Supabase responds.
        hike = Hike(
            id: hikeId,
            userId: UUID(uuidString: localHike.userId) ?? UUID(),
            title: localHike.title,
            location: localHike.location,
            date: localHike.date,
            distanceMeters: localHike.distanceMeters,
            timeSeconds: localHike.timeSeconds,
            coverImageUrl: nil,
            pictures: nil,
            routepoints: nil
        )

        var sources: [UUID: PictureImageSource] = [:]
        var converted: [Picture] = []
        converted.reserveCapacity(localPics.count)

        for pic in localPics {
            guard let pictureID = UUID(uuidString: pic.localId) else { continue }
            let picture = Picture(
                id: pictureID,
                hikeId: hikeId,
                species: pic.species,
                speciesInfo: pic.speciesInfo,
                imageUrl: pic.localImagePath,
                takenAt: pic.takenAt,
                latitude: pic.latitude,
                longitude: pic.longitude
            )
            converted.append(picture)
            if FileManager.default.fileExists(atPath: pic.localImagePath) {
                sources[pictureID] = .localFile(path: pic.localImagePath)
            }
        }

        let convertedRoutepoints: [Routepoint] = localRoutepoints.compactMap { rp in
            guard let routepointID = UUID(uuidString: rp.localId) else { return nil }
            return Routepoint(
                id: routepointID,
                hikeId: hikeId,
                latitude: rp.latitude,
                longitude: rp.longitude,
                timestamp: rp.timestamp,
                altitude: rp.altitude
            )
        }
        .sorted { $0.timestamp < $1.timestamp }

        pictures = converted
        routepoints = convertedRoutepoints
        imageSources = sources
    }

    /// Pulls the canonical record from Supabase and merges it into whatever
    /// we already loaded locally.
    private func mergeRemote() async {
        do {
            let fetched = try await queryService.getHikeDetail(hikeId: hikeId)
            hike = fetched

            // Pictures: local entries already in `pictures` keep their local
            // file source; remote-only entries get a signed URL resolved.
            let existingIDs = Set(pictures.map { $0.id })
            let remotePictures = fetched.pictures ?? []
            for remotePic in remotePictures where existingIDs.contains(remotePic.id) == false {
                pictures.append(remotePic)
            }

            await resolveMissingImageSources()

            // Routepoints: prefer remote when we have them, since the server
            // copy is canonical and ordered. Otherwise keep the local set we
            // already loaded.
            if let remoteRoutepoints = fetched.routepoints, remoteRoutepoints.isEmpty == false {
                routepoints = remoteRoutepoints.sorted { $0.timestamp < $1.timestamp }
            }
        } catch {
            print("[HikeDetailVM] Supabase fetch failed: \(error)")
            // Only surface an error if we don't have anything local to show.
            if pictures.isEmpty && routepoints.isEmpty {
                errorMessage = "Unable to load hike details right now."
            }
        }
    }

    /// For any picture that doesn't yet have a `PictureImageSource`, generate
    /// a signed URL from the storage path stored in `imageUrl`.
    private func resolveMissingImageSources() async {
        for picture in pictures {
            if imageSources[picture.id] != nil { continue }

            // Local-only picture that lost its file — nothing we can do.
            if FileManager.default.fileExists(atPath: picture.imageUrl) {
                imageSources[picture.id] = .localFile(path: picture.imageUrl)
                continue
            }

            if let direct = URL(string: picture.imageUrl), direct.scheme != nil {
                imageSources[picture.id] = .remote(direct)
                continue
            }

            do {
                let signed = try await queryService.getSignedUrl(storagePath: picture.imageUrl)
                imageSources[picture.id] = .remote(signed)
            } catch {
                print("[HikeDetailVM] Could not resolve signed URL for picture \(picture.id): \(error)")
            }
        }
    }

    // MARK: - Date helpers

    private static let serverDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let serverDateWithoutFractionFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
