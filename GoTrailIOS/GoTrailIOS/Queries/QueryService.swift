// Queries/QueryService.swift
import Foundation
import Supabase

class QueryService {
    static let shared = QueryService()
    private let client = SupabaseManager.client

    private init() {}

    private func currentUserId() async throws -> UUID {
        do {
            return try await client.auth.session.user.id
        } catch {
            throw QueryError.notLoggedIn
        }
    }

    // MARK: - Hikes

    // All hikes for history view
    func getHikes() async throws -> [Hike] {
        let userId = try await currentUserId()

        let hikes: [Hike] = try await client
            .from("hikes")
            .select("""
                id, user_id, title, location, date,
                distance_meters, time_seconds, cover_image_url,
                pictures (
                    id, hike_id, species, species_info,
                    image_url, taken_at, latitude, longitude
                )
            """)
            .eq("user_id", value: userId)
            .order("date", ascending: false)
            .execute()
            .value

        print("[QueryService] Fetched \(hikes.count) hikes")
        return hikes
    }

    // Single hike with all pictures and routepoints
    func getHikeDetail(hikeId: UUID) async throws -> Hike {
        let userId = try await currentUserId()

        var hike: Hike = try await client
            .from("hikes")
            .select("""
                id, user_id, title, location, date,
                distance_meters, time_seconds, cover_image_url,
                pictures (
                    id, hike_id, species, species_info,
                    image_url, taken_at, latitude, longitude
                ),
                routepoints (
                    id, hike_id, latitude, longitude,
                    timestamp, altitude
                )
            """)
            .eq("id", value: hikeId)
            .eq("user_id", value: userId)
            .single()
            .execute()
            .value

        // Sort routepoints chronologically for map rendering
        hike.routepoints?.sort { $0.timestamp < $1.timestamp }

        print("[QueryService] Fetched hike detail — \(hike.title), \(hike.pictures?.count ?? 0) pictures, \(hike.routepoints?.count ?? 0) routepoints")
        return hike
    }

    // MARK: - Profile

    func getProfile() async throws -> Profile {
        let userId = try await currentUserId()

        let profile: Profile = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value

        print("[QueryService] Fetched profile — \(profile.username)")
        return profile
    }

    // MARK: - Species

    // All unique species found by this user across all hikes
    func getAllSpecies() async throws -> [Picture] {
        let userId = try await currentUserId()

        let pictures: [Picture] = try await client
            .from("pictures")
            .select("""
                id, hike_id, species, species_info,
                image_url, taken_at, latitude, longitude,
                hikes!inner (user_id)
            """)
            .eq("hikes.user_id", value: userId)
            .not("species", operator: .is, value: AnyJSON.null)
            .execute()
            .value

        // Deduplicate by species name
        var seen = Set<String>()
        let unique = pictures.filter { pic in
            guard let s = pic.species else { return false }
            return seen.insert(s).inserted
        }

        print("[QueryService] Fetched \(unique.count) unique species")
        return unique
    }

    // MARK: - Images

    // Generate a signed URL for a private image (1 hour expiry)
    func getSignedUrl(storagePath: String) async throws -> URL {
        let url = try await client.storage
            .from("hike-images")
            .createSignedURL(path: storagePath, expiresIn: 3600)

        print("[QueryService] Generated signed URL for: \(storagePath)")
        return url
    }
}

// MARK: - Errors

enum QueryError: Error, LocalizedError {
    case notLoggedIn
    case noData

    var errorDescription: String? {
        switch self {
        case .notLoggedIn: return "No logged in user"
        case .noData: return "No data returned"
        }
    }
}



