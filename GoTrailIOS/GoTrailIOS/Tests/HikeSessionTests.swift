// Tests/HikeSessionTests.swift
import Foundation
import CoreLocation

class HikeSessionTests {

    static func runAll() async {
        print("\n========== HIKE SESSION TESTS ==========\n")

        if HikeSessionManager.shared.isActive {
            try? HikeSessionManager.shared.stopHike()
        }

        await testStartHike()
        await testDoubleStart()
        await testRecordPictures()
        await testDistanceCalculation()
        await testSQLitePersistence()
        await testStopWithNoActiveHike()
        await testFullHikeFlow()
        await testLiveGPS()  // add this
        print("\n========== ALL TESTS COMPLETE ==========\n")
    }






    // MARK: - Test 1: Basic start and stop

    static func testStartHike() async {
        print("--- Test 1: Start and Stop ---")
        do {
            let hikeId = try HikeSessionManager.shared.startHike(
                title: "Morning Hike",
                location: "Griffith Park",
                userId: "test-user-123"
            )
            print("✓ Hike started with ID: \(hikeId)")
            assert(HikeSessionManager.shared.isActive == true, "Hike should be active")
            assert(HikeSessionManager.shared.currentHikeLocalId == hikeId, "Hike ID should match")
            assert(HikeSessionManager.shared.elapsedSeconds == 0, "Elapsed should start at 0")
            assert(HikeSessionManager.shared.distanceMeters == 0, "Distance should start at 0")

            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            print("✓ Timer running — elapsed: \(HikeSessionManager.shared.elapsedSeconds)s")
            assert(HikeSessionManager.shared.elapsedSeconds >= 2, "Timer should have ticked")

            try HikeSessionManager.shared.stopHike()
            assert(HikeSessionManager.shared.isActive == false, "Hike should be inactive")
            assert(HikeSessionManager.shared.currentHikeLocalId == nil, "Hike ID should be nil")
            print("✓ Test 1 passed\n")
        } catch {
            print("✗ Test 1 failed: \(error)\n")
        }
    }

    // MARK: - Test 2: Starting a hike when one is already active

    static func testDoubleStart() async {
        print("--- Test 2: Double Start ---")
        do {
            try HikeSessionManager.shared.startHike(
                title: "First Hike",
                location: nil,
                userId: "test-user-123"
            )

            do {
                try HikeSessionManager.shared.startHike(
                    title: "Second Hike",
                    location: nil,
                    userId: "test-user-123"
                )
                print("✗ Test 2 failed — should have thrown alreadyActive error")
            } catch HikeError.alreadyActive {
                print("✓ Correctly threw alreadyActive error")
            }

            try HikeSessionManager.shared.stopHike()
            print("✓ Test 2 passed\n")
        } catch {
            print("✗ Test 2 failed: \(error)\n")
        }
    }

    // MARK: - Test 3: Recording pictures

    static func testRecordPictures() async {
        print("--- Test 3: Record Pictures ---")
        do {
            let hikeId = try HikeSessionManager.shared.startHike(
                title: "Picture Hike",
                location: "Runyon Canyon",
                userId: "test-user-123"
            )

            // Record identified plant
            try HikeSessionManager.shared.recordPicture(
                imagePath: "/mock/plant1.jpg",
                species: "Quercus agrifolia",
                speciesInfo: "Coast Live Oak — native to California",
                latitude: 34.1002,
                longitude: -118.3420
            )
            assert(HikeSessionManager.shared.pictureCount == 1, "Should have 1 picture")
            print("✓ Identified plant recorded")

            // Record unidentified plant
            try HikeSessionManager.shared.recordPicture(
                imagePath: "/mock/plant2.jpg",
                species: nil,
                speciesInfo: nil,
                latitude: 34.1005,
                longitude: -118.3425
            )
            assert(HikeSessionManager.shared.pictureCount == 2, "Should have 2 pictures")
            print("✓ Unidentified plant recorded")

            // Record another identified plant
            try HikeSessionManager.shared.recordPicture(
                imagePath: "/mock/plant3.jpg",
                species: "Salvia apiana",
                speciesInfo: "White Sage — used in traditional medicine",
                latitude: 34.1008,
                longitude: -118.3430
            )
            assert(HikeSessionManager.shared.pictureCount == 3, "Should have 3 pictures")
            print("✓ Third plant recorded")

            try HikeSessionManager.shared.stopHike()

            // Verify in SQLite
            let pics = try LocalDatabase.shared.getPictures(forHikeLocalId: hikeId)
            assert(pics.count == 3, "Should have 3 pictures in SQLite")
            assert(pics[0].species == "Quercus agrifolia", "Species should match")
            assert(pics[1].species == nil, "Unidentified should be nil")
            print("✓ Pictures verified in SQLite")
            print("✓ Test 3 passed\n")
        } catch {
            print("✗ Test 3 failed: \(error)\n")
        }
    }

    // MARK: - Test 4: Distance calculation

    static func testDistanceCalculation() async {
        print("--- Test 4: Distance Calculation ---")

        // Known points — Griffith Observatory to Greek Theatre (~900m apart)
        let point1 = PendingRoutepoint(
            localId: UUID().uuidString,
            hikeLocalId: "test",
            latitude: 34.1184,
            longitude: -118.3004,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            altitude: 300
        )
        let point2 = PendingRoutepoint(
            localId: UUID().uuidString,
            hikeLocalId: "test",
            latitude: 34.1123,
            longitude: -118.2987,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            altitude: 250
        )
        let point3 = PendingRoutepoint(
            localId: UUID().uuidString,
            hikeLocalId: "test",
            latitude: 34.1089,
            longitude: -118.2956,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            altitude: 200
        )

        let total = DistanceCalculator.totalDistance(from: [point1, point2, point3])
        let incremental = DistanceCalculator.incrementalDistance(from: point2, to: point3)

        print("✓ Total distance: \(DistanceCalculator.formatDistance(total))")
        print("✓ Incremental distance: \(DistanceCalculator.formatDistance(incremental))")
        assert(total > 0, "Total distance should be greater than 0")
        assert(incremental > 0, "Incremental distance should be greater than 0")
        assert(incremental < total, "Incremental should be less than total")

        // Test formatting
        assert(DistanceCalculator.formatDistance(500) == "500 m", "Should format as meters")
        assert(DistanceCalculator.formatDistance(1500).contains("km"), "Should format as km")
        assert(DistanceCalculator.formatDuration(65) == "01:05", "Should format as MM:SS")
        assert(DistanceCalculator.formatDuration(3661).contains(":"), "Should format as HH:MM:SS")
        print("✓ Formatting verified")
        print("✓ Test 4 passed\n")
    }

    // MARK: - Test 5: SQLite persistence across sessions

    static func testSQLitePersistence() async {
        print("--- Test 5: SQLite Persistence ---")
        do {
            let hikeId = try HikeSessionManager.shared.startHike(
                title: "Persistence Test",
                location: "Malibu Creek",
                userId: "test-user-123"
            )

            try HikeSessionManager.shared.recordPicture(
                imagePath: "/mock/plant.jpg",
                species: "Artemisia californica",
                speciesInfo: "California Sagebrush",
                latitude: 34.0978,
                longitude: -118.7612
            )

            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            try HikeSessionManager.shared.stopHike()

            // Read back from SQLite
            let allHikes = try LocalDatabase.shared.getAllHikes()
            let saved = allHikes.first { $0.localId == hikeId }
            assert(saved != nil, "Hike should exist in SQLite")
            assert(saved?.title == "Persistence Test", "Title should match")
            assert(saved?.location == "Malibu Creek", "Location should match")
            assert(saved?.timeSeconds ?? 0 >= 2, "Time should be at least 2 seconds")
            print("✓ Hike persisted correctly")

            let pics = try LocalDatabase.shared.getPictures(forHikeLocalId: hikeId)
            assert(pics.count == 1, "Should have 1 picture")
            assert(pics[0].species == "Artemisia californica", "Species should match")
            print("✓ Pictures persisted correctly")

            let unsynced = try LocalDatabase.shared.getUnsyncedHikes(forUserId: "test-user-123")
            assert(unsynced.count > 0, "Should have unsynced hikes")
            print("✓ Unsynced hikes found: \(unsynced.count)")

            print("✓ Test 5 passed\n")
        } catch {
            print("✗ Test 5 failed: \(error)\n")
        }
    }

    // MARK: - Test 6: Stop with no active hike

    static func testStopWithNoActiveHike() async {
        print("--- Test 6: Stop With No Active Hike ---")
        do {
            try HikeSessionManager.shared.stopHike()
            print("✗ Test 6 failed — should have thrown noActiveHike error")
        } catch HikeError.noActiveHike {
            print("✓ Correctly threw noActiveHike error")
            print("✓ Test 6 passed\n")
        } catch {
            print("✗ Test 6 failed with unexpected error: \(error)\n")
        }
    }

    // MARK: - Test 7: Full hike flow with simulated GPS

    static func testFullHikeFlow() async {
        print("--- Test 7: Full Hike Flow with Simulated GPS ---")
        do {
            let hikeId = try HikeSessionManager.shared.startHike(
                title: "Full Flow Test",
                location: "Santa Monica Mountains",
                userId: "test-user-123"
            )
            print("✓ Hike started")
            
            // Stop real GPS immediately — this test uses injected points only
            LocationTracker.shared.stopTracking()

            // Simulate GPS points being injected directly
            let simulatedPoints: [(Double, Double)] = [
                (34.0983, -118.7698),
                (34.0991, -118.7701),
                (34.0998, -118.7705),
                (34.1005, -118.7710),
                (34.1012, -118.7714)
            ]

            for (lat, lon) in simulatedPoints {
                let point = PendingRoutepoint(
                    localId: UUID().uuidString,
                    hikeLocalId: hikeId,
                    latitude: lat,
                    longitude: lon,
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    altitude: 200
                )
                try LocalDatabase.shared.saveRoutepoint(point)
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            print("✓ Simulated 5 GPS points")

            try HikeSessionManager.shared.recordPicture(
                imagePath: "/mock/sage.jpg",
                species: "Salvia mellifera",
                speciesInfo: "Black Sage",
                latitude: 34.1005,
                longitude: -118.7710
            )
            print("✓ Picture recorded at GPS location")

            try await Task.sleep(nanoseconds: 2_000_000_000)
            HikeSessionManager.shared.printStatus()

            let summary = try HikeSessionManager.shared.stopHike()
            print("✓ Hike stopped")

            let routepoints = try LocalDatabase.shared.getRoutepoints(forHikeLocalId: hikeId)
            let pictures = try LocalDatabase.shared.getPictures(forHikeLocalId: hikeId)
            let totalDist = DistanceCalculator.totalDistance(from: routepoints)

            print("\n--- Final Summary ---")
            print("  Routepoints: \(routepoints.count)")
            print("  Pictures: \(pictures.count)")
            print("  Calculated distance: \(DistanceCalculator.formatDistance(totalDist))")
            print("  Duration: \(DistanceCalculator.formatDuration(summary.timeSeconds))")

            assert(routepoints.count == 5, "Should have exactly 5 routepoints")
            assert(pictures.count == 1, "Should have 1 picture")
            assert(totalDist > 0, "Distance should be greater than 0")

            print("✓ Test 7 passed\n")
        } catch {
            print("✗ Test 7 failed: \(error)\n")
        }
    }
    
    // MARK: - Test 8: Live GPS tracking

    static func testLiveGPS() async {
        print("--- Test 8: Live GPS (City Bicycle Ride) ---")
        print("⚠️ Enable Simulator → Features → Location → City Bicycle Ride NOW")
        print("Waiting 5 seconds...")

        // Give time to enable bicycle ride
        try? await Task.sleep(nanoseconds: 5_000_000_000)

        do {
            let hikeId = try HikeSessionManager.shared.startHike(
                title: "Live GPS Test",
                location: "San Francisco",
                userId: "test-user-123"
            )
            print("✓ Hike started — tracking for 60 seconds")
            print("Watch for routepoints coming in below:\n")

            // Track for 60 seconds
            try await Task.sleep(nanoseconds: 60_000_000_000)

            HikeSessionManager.shared.printStatus()

            try HikeSessionManager.shared.stopHike()

            // Read back results
            let routepoints = try LocalDatabase.shared.getRoutepoints(forHikeLocalId: hikeId)
            let totalDist = DistanceCalculator.totalDistance(from: routepoints)

            print("\n--- Live GPS Summary ---")
            print("  Routepoints recorded: \(routepoints.count)")
            print("  Total distance: \(DistanceCalculator.formatDistance(totalDist))")

            if routepoints.count > 0 {
                print("  First point: \(routepoints.first!.latitude), \(routepoints.first!.longitude)")
                print("  Last point: \(routepoints.last!.latitude), \(routepoints.last!.longitude)")
            }

            if routepoints.count > 1 {
                print("✓ Test 8 passed — GPS is working")
            } else {
                print("✗ Test 8 failed — no GPS points received, make sure City Bicycle Ride is enabled")
            }

        } catch {
            print("✗ Test 8 failed: \(error)")
        }
    }





}


