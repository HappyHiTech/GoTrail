
// Hike/DistanceCalculator.swift
import CoreLocation
import Foundation

struct DistanceCalculator {

    // Full route distance — takes all routepoints and returns total meters
    static func totalDistance(from points: [PendingRoutepoint]) -> Double {
        guard points.count > 1 else { return 0 }

        var total = 0.0
        for i in 1..<points.count {
            let prev = CLLocation(
                latitude: points[i - 1].latitude,
                longitude: points[i - 1].longitude
            )
            let curr = CLLocation(
                latitude: points[i].latitude,
                longitude: points[i].longitude
            )
            total += curr.distance(from: prev)
        }
        return total
    }

    // Incremental — just the distance between the last two points
    // Called live during a hike so we don't recalculate the whole route every update
    static func incrementalDistance(from: PendingRoutepoint, to: PendingRoutepoint) -> Double {
        let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return toLoc.distance(from: fromLoc)
    }

    // Formatting helpers
    static func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            return String(format: "%.2f km", meters / 1000)
        }
    }

    static func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}


