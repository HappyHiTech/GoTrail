// Models/Models.swift
import Foundation

struct Profile: Codable {
    let id: UUID
    let username: String
    let email: String
    let createdAt: Date
    var totalDistanceMeters: Double
    var totalTimeSeconds: Int
    var totalPlantsFound: Int

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case createdAt = "created_at"
        case totalDistanceMeters = "total_distance_meters"
        case totalTimeSeconds = "total_time_seconds"
        case totalPlantsFound = "total_plants_found"
    }
}

struct Hike: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var title: String
    var location: String?
    let date: String
    var distanceMeters: Double
    var timeSeconds: Int
    var coverImageUrl: String?
    var pictures: [Picture]?
    var routepoints: [Routepoint]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case location
        case date
        case distanceMeters = "distance_meters"
        case timeSeconds = "time_seconds"
        case coverImageUrl = "cover_image_url"
        case pictures
        case routepoints
    }
}

struct Picture: Codable, Identifiable {
    let id: UUID
    let hikeId: UUID
    var species: String?
    var speciesInfo: String?
    var imageUrl: String
    let takenAt: String
    var latitude: Double?
    var longitude: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case hikeId = "hike_id"
        case species
        case speciesInfo = "species_info"
        case imageUrl = "image_url"
        case takenAt = "taken_at"
        case latitude
        case longitude
    }
}

struct Routepoint: Codable, Identifiable {
    let id: UUID
    let hikeId: UUID
    let latitude: Double
    let longitude: Double
    let timestamp: String
    let altitude: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case hikeId = "hike_id"
        case latitude
        case longitude
        case timestamp
        case altitude
    }
}


