import Foundation

struct HikeCardModel: Identifiable, Hashable {
    let id: UUID
    let title: String
    let location: String
    let distanceKm: Double
    let plantsFound: Int
    let imageAssetName: String?
    let imageURLString: String?

    init(
        id: UUID = UUID(),
        title: String,
        location: String,
        distanceKm: Double,
        plantsFound: Int,
        imageAssetName: String? = nil,
        imageURLString: String? = nil
    ) {
        self.id = id
        self.title = title
        self.location = location
        self.distanceKm = distanceKm
        self.plantsFound = plantsFound
        self.imageAssetName = imageAssetName
        self.imageURLString = imageURLString
    }
}
