import Foundation
import Combine

@MainActor
final class HikeDetailViewModel: ObservableObject {
    @Published private(set) var hike: Hike?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var selectedPictureID: UUID?
    @Published private(set) var resolvedImageURLs: [UUID: URL] = [:]

    private let hikeId: UUID
    private let queryService: QueryService

    init(hikeId: UUID, queryService: QueryService = .shared) {
        self.hikeId = hikeId
        self.queryService = queryService
    }

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
        "\(hike?.pictures?.count ?? 0)"
    }

    var dateText: String {
        guard let raw = hike?.date else { return "-" }
        if let parsed = Self.serverDateFormatter.date(from: raw) ?? Self.serverDateWithoutFractionFormatter.date(from: raw) {
            return Self.displayDateFormatter.string(from: parsed)
        }
        return raw
    }

    var sortedPictures: [Picture] {
        (hike?.pictures ?? []).sorted { $0.takenAt < $1.takenAt }
    }

    var selectedPicture: Picture? {
        guard let selectedPictureID else { return sortedPictures.first }
        return sortedPictures.first { $0.id == selectedPictureID } ?? sortedPictures.first
    }

    var routepoints: [Routepoint] {
        hike?.routepoints ?? []
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await queryService.getHikeDetail(hikeId: hikeId)
            hike = fetched
            let picCount = fetched.pictures?.count ?? 0
            let identified = fetched.pictures?.filter { $0.species != nil }.count ?? 0
            print("[HikeDetailVM] Loaded hike \(fetched.title) — \(picCount) pictures (\(identified) with species), \(fetched.routepoints?.count ?? 0) routepoints")
            if selectedPictureID == nil {
                selectedPictureID = fetched.pictures?.first?.id
            }
            await resolvePictureURLs()
        } catch {
            print("[HikeDetailVM] Failed to load hike detail: \(error)")
            errorMessage = "Unable to load hike details right now."
        }
    }

    func selectPicture(_ pictureID: UUID) {
        selectedPictureID = pictureID
    }

    func resolvedURL(for picture: Picture) -> URL? {
        resolvedImageURLs[picture.id]
    }

    private func resolvePictureURLs() async {
        guard let pictures = hike?.pictures, pictures.isEmpty == false else { return }
        var updated = resolvedImageURLs

        for picture in pictures {
            if let existing = updated[picture.id] {
                updated[picture.id] = existing
                continue
            }

            if let direct = URL(string: picture.imageUrl), direct.scheme != nil {
                updated[picture.id] = direct
                continue
            }

            do {
                let signed = try await queryService.getSignedUrl(storagePath: picture.imageUrl)
                updated[picture.id] = signed
            } catch {
                continue
            }
        }

        resolvedImageURLs = updated
    }

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
