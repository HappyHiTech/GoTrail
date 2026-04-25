
// Local/PendingModels.swift
import Foundation

struct PendingHike {
    let localId: String
    let userId: String
    var title: String
    var location: String?
    let date: String
    var distanceMeters: Double
    var timeSeconds: Int

    init(localId: String, userId: String, title: String, location: String?, date: String, distanceMeters: Double, timeSeconds: Int) {
        self.localId = localId
        self.userId = userId
        self.title = title
        self.location = location
        self.date = date
        self.distanceMeters = distanceMeters
        self.timeSeconds = timeSeconds
    }
}

struct PendingPicture {
    let localId: String
    let hikeLocalId: String
    let localImagePath: String
    var species: String?
    var speciesInfo: String?
    var latitude: Double?
    var longitude: Double?
    let takenAt: String

    init(localId: String, hikeLocalId: String, localImagePath: String, species: String?, speciesInfo: String?, latitude: Double?, longitude: Double?, takenAt: String) {
        self.localId = localId
        self.hikeLocalId = hikeLocalId
        self.localImagePath = localImagePath
        self.species = species
        self.speciesInfo = speciesInfo
        self.latitude = latitude
        self.longitude = longitude
        self.takenAt = takenAt
    }
}

struct PendingRoutepoint {
    let localId: String
    let hikeLocalId: String
    let latitude: Double
    let longitude: Double
    let timestamp: String
    let altitude: Double?

    init(localId: String, hikeLocalId: String, latitude: Double, longitude: Double, timestamp: String, altitude: Double?) {
        self.localId = localId
        self.hikeLocalId = hikeLocalId
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.altitude = altitude
    }
}

