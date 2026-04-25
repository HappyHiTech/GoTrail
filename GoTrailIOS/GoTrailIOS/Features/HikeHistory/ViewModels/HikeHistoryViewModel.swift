import Foundation
import Combine

@MainActor
final class HikeHistoryViewModel: ObservableObject {
    @Published private(set) var hikes: [HikeCardModel] = []
    @Published private(set) var isLoading = false
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

    func loadHikes() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetchedHikes = try await queryService.getHikes()
            hikes = fetchedHikes.map { hike in
                let location = (hike.location?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                    ? (hike.location ?? "Unknown location")
                    : "Unknown location"
                let plantsFound = hike.pictures?.count ?? 0
                let coverImageURL = hike.coverImageUrl?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return HikeCardModel(
                    id: hike.id,
                    title: hike.title,
                    location: location,
                    distanceKm: hike.distanceMeters / 1000.0,
                    plantsFound: plantsFound,
                    imageAssetName: nil,
                    imageURLString: (coverImageURL?.isEmpty == false) ? coverImageURL : nil
                )
            }
        } catch {
            errorMessage = "Unable to load hike history right now."
            hikes = []
        }
    }
}
