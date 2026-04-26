// TrailGuardApp.swift
import SwiftUI

@main
struct TrailGuardApp: App {
    init() {
        if HikeSessionManager.shared.isActive {
            try? HikeSessionManager.shared.stopHike()
        }
        _ = LocalDatabase.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    LocationTracker.shared.requestPermission()
                    SyncManager.shared.startMonitoring()
                    Task { await PlantClassifier.shared.loadModel() }
                }
        }
    }
}


