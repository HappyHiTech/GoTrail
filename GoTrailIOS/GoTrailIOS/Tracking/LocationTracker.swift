// Tracking/LocationTracker.swift
import CoreLocation
import Foundation

typealias LocationUpdateHandler = (CLLocation) -> Void

class LocationTracker: NSObject, CLLocationManagerDelegate {
    static let shared = LocationTracker()

    private let manager = CLLocationManager()
    private var onLocationUpdate: LocationUpdateHandler?
    private(set) var lastLocation: CLLocation?
    private(set) var isTracking = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
    }

    func requestPermission() {
        manager.requestAlwaysAuthorization()
    }

    func startTracking(onUpdate: @escaping LocationUpdateHandler) {
        self.onLocationUpdate = onUpdate
        self.isTracking = true
        manager.startUpdatingLocation()
        print("[LocationTracker] Started tracking")
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        isTracking = false
        onLocationUpdate = nil
        print("[LocationTracker] Stopped tracking")
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastLocation = location
        onLocationUpdate?(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LocationTracker] Error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            print("[LocationTracker] Permission granted — Always")
        case .authorizedWhenInUse:
            print("[LocationTracker] Permission granted — When In Use")
        case .denied, .restricted:
            print("[LocationTracker] Permission denied — location will not be tracked")
        case .notDetermined:
            print("[LocationTracker] Permission not yet determined")
        @unknown default:
            break
        }
    }
}


