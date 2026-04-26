import Foundation
import Combine
import Supabase
import CoreLocation

@MainActor
final class NewHikeViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var hikeName = ""
    @Published var hasCoverPhoto = false
    @Published var didSkipCoverPhoto = false
    @Published var locationName = "Current Location"
    @Published var locationSubtitle = "Locating..."
    @Published var locationAccuracyMeters = 3
    @Published var isStarting = false
    @Published var errorMessage: String?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var hasStartedLocationLookup = false
    private var hasResolvedPlacemark = false
    private var coverPhotoLocalPath: String?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 25
    }

    var canStartHike: Bool {
        hikeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func toggleMockCoverPhoto() {
        hasCoverPhoto.toggle()
        if hasCoverPhoto {
            didSkipCoverPhoto = false
        }
    }

    func skipCoverPhoto() {
        hasCoverPhoto = false
        didSkipCoverPhoto = true
        coverPhotoLocalPath = nil
    }

    func addCoverPhotoAfterSkip() {
        hasCoverPhoto = true
        didSkipCoverPhoto = false
    }

    func applyCoverPhotoSelection(hasPhoto: Bool) {
        hasCoverPhoto = hasPhoto
        if hasPhoto {
            didSkipCoverPhoto = false
        } else {
            coverPhotoLocalPath = nil
        }
    }

    func applyCoverPhotoSelection(imageData: Data) {
        guard let savedPath = saveCoverPhotoDataToDocuments(imageData) else {
            print("[NewHikeVM] ✗ Cover photo save failed — no path returned")
            hasCoverPhoto = false
            coverPhotoLocalPath = nil
            return
        }
        hasCoverPhoto = true
        didSkipCoverPhoto = false
        coverPhotoLocalPath = savedPath
        print("[NewHikeVM] ✓ Cover photo saved — path: \(savedPath), exists: \(FileManager.default.fileExists(atPath: savedPath))")
    }

    func beginLocationLookup() {
        guard hasStartedLocationLookup == false else { return }
        hasStartedLocationLookup = true

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            locationName = "Location unavailable"
            locationSubtitle = "Enable location access in Settings"
        @unknown default:
            locationName = "Location unavailable"
            locationSubtitle = "Unable to determine authorization"
        }
    }

    func startHike() async -> Bool {
        guard canStartHike else { return false }
        guard isStarting == false else { return false }
        isStarting = true
        defer { isStarting = false }

        let title = hikeName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let userId = try await SupabaseManager.client.auth.session.user.id.uuidString.lowercased()
            let cleanLocation = sanitizedLocation()
            if HikeSessionManager.shared.isActive {
                _ = try HikeSessionManager.shared.stopHike()
            }
            print("[NewHikeVM] Starting hike with coverPhotoLocalPath: \(coverPhotoLocalPath ?? "nil")")
            _ = try HikeSessionManager.shared.startHike(
                title: title,
                location: cleanLocation,
                userId: userId,
                coverImageLocalPath: coverPhotoLocalPath
            )
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationManager.startUpdatingLocation()
            case .denied, .restricted:
                self.locationName = "Location unavailable"
                self.locationSubtitle = "Enable location access in Settings"
            case .notDetermined:
                break
            @unknown default:
                self.locationName = "Location unavailable"
                self.locationSubtitle = "Unable to determine authorization"
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let horizontalAccuracy = max(1, Int(location.horizontalAccuracy.rounded()))
            self.locationAccuracyMeters = horizontalAccuracy

            guard self.hasResolvedPlacemark == false else { return }
            self.hasResolvedPlacemark = true

            self.geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let placemark = placemarks?.first {
                        self.locationName = self.primaryLocationText(from: placemark)
                        self.locationSubtitle = self.secondaryLocationText(from: placemark)
                    } else {
                        let lat = String(format: "%.4f", location.coordinate.latitude)
                        let lon = String(format: "%.4f", location.coordinate.longitude)
                        self.locationName = "Near \(lat), \(lon)"
                        self.locationSubtitle = "Location detected"
                    }
                    self.locationManager.stopUpdatingLocation()
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.locationName = "Location unavailable"
            self.locationSubtitle = error.localizedDescription
        }
    }

    private func primaryLocationText(from placemark: CLPlacemark) -> String {
        if let areaOfInterest = placemark.areasOfInterest?.first, areaOfInterest.isEmpty == false {
            return areaOfInterest
        }
        if let name = placemark.name, name.isEmpty == false {
            return name
        }
        if let locality = placemark.locality, locality.isEmpty == false {
            return locality
        }
        return "Current Location"
    }

    private func secondaryLocationText(from placemark: CLPlacemark) -> String {
        let parts = [
            placemark.locality,
            placemark.administrativeArea,
            placemark.country
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        if parts.isEmpty {
            return "Location detected"
        }
        return parts.joined(separator: ", ")
    }

    private func sanitizedLocation() -> String? {
        let trimmed = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let placeholders = Set([
            "Current Location",
            "Locating...",
            "Location unavailable"
        ])
        return placeholders.contains(trimmed) ? nil : trimmed
    }

    private func saveCoverPhotoDataToDocuments(_ data: Data) -> String? {
        let fileName = "cover_\(UUID().uuidString).jpg"
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL.path
        } catch {
            print("[NewHikeVM] Failed to save cover photo data: \(error)")
            return nil
        }
    }
}
